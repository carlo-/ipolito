//
//  PTDownloadManager.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 04/08/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import Foundation

fileprivate let downloadedFilesArchiveKey: String = "downloadedFiles"

fileprivate extension PTMFile {
    
    var nameOnDisk: String {
        return name.replacingOccurrences(of: " ", with: "-")
    }
}

enum PTFileTransferStatus {
    case downloading
    case cancelled
    case failed
    case paused
    case completed
    case waitingForURL
    case ready
    case added
    
    func localizedDescription() -> String {
        
        switch self {
        case .downloading:
            return ~"ls.fileTransfer.status.downloading"
        case .cancelled:
            return ~"ls.fileTransfer.status.cancelled"
        case .failed:
            return ~"ls.fileTransfer.status.failed"
        case .paused:
            return ~"ls.fileTransfer.status.paused"
        case .completed:
            return ~"ls.fileTransfer.status.completed"
        case .waitingForURL:
            return ~"ls.fileTransfer.status.waitingForURL"
        case .ready, .added:
            return ~"ls.fileTransfer.status.onQueue"
        }
    }
}

class PTDownloadedFile: NSObject, NSCoding {
    
    let fileName: String
    let fileDescription: String
    let subjectName: String
    let downloadDate: Date
    
    init(fileName: String, description: String, subjectName: String, downloadDate: Date) {
        
        self.fileName = fileName
        self.fileDescription = description
        self.subjectName = subjectName
        self.downloadDate = downloadDate
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(fileName, forKey: "fileName")
        aCoder.encode(fileDescription, forKey: "fileDescription")
        aCoder.encode(subjectName, forKey: "subjectName")
        aCoder.encode(downloadDate, forKey: "downloadDate")
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        self.fileName = aDecoder.decodeObject(forKey: "fileName") as! String
        self.fileDescription = aDecoder.decodeObject(forKey: "fileDescription") as! String
        self.subjectName = aDecoder.decodeObject(forKey: "subjectName") as! String
        self.downloadDate = aDecoder.decodeObject(forKey: "downloadDate") as! Date
    }
}

class PTFileTransfer: NSObject {
    
    let file: PTMFile
    let subject: PTSubject
    var url: URL?
    var progress: Float = 0.0
    var status: PTFileTransferStatus = .added
    var task: URLSessionDownloadTask?
    
    init(file: PTMFile, url: URL? = nil, subject: PTSubject) {
        self.file = file
        self.url = url
        self.subject = subject
        
        if url != nil {
            self.status = .ready
        }
    }
}

protocol PTDownloadManagerDelegate {
    func fileTransferDidChangeStatus(_ transfer: PTFileTransfer)
}

extension PTDownloadManagerDelegate {
    func fileTransferDidChangeStatus(_ transfer: PTFileTransfer) {}
}

class PTDownloadManager: NSObject, URLSessionDownloadDelegate {
    
    static let shared = PTDownloadManager()
    
    var downloadedFiles: [PTDownloadedFile] = []
    var ongoingTasks: [URLSessionDownloadTask: PTFileTransfer] = [:]
    var delegate: PTDownloadManagerDelegate? = nil
    var queue: [PTFileTransfer] = [] {
        didSet {
            checkQueue()
        }
    }
    
    var documentsFolderPath: String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    }
    
    var downloadsFolderPath: String {
        return (documentsFolderPath as NSString).appendingPathComponent("Downloads")
    }
    
    private override init() {
        super.init()
        synchronizeDownloadedFiles()
    }
    
    
    
    // MARK: Transfer managing methods
 
    func enqueueForDownload(file: PTMFile, ofSubject subject: PTSubject) {
        
        for transfer in queue {
            if transfer.file.identifier == file.identifier {
                return
            }
        }
        
        let transfer = PTFileTransfer(file: file, subject: subject)
        self.queue.append(transfer)
        
        delegate?.fileTransferDidChangeStatus(transfer)
    }
    
    func resume(fileTransfer transfer: PTFileTransfer) {
        
        transfer.task?.resume()
        transfer.status = .downloading
        
        delegate?.fileTransferDidChangeStatus(transfer)
    }
    
    func pause(fileTransfer transfer: PTFileTransfer) {
        
        transfer.task?.suspend()
        transfer.status = .paused
        
        delegate?.fileTransferDidChangeStatus(transfer)
        
        checkQueue()
    }
    
    func retry(fileTransfer transfer: PTFileTransfer) {
        
        transfer.status = .added
        checkQueue()
    }
    
    func cancel(fileTransfer transfer: PTFileTransfer) {
        
        if let task = transfer.task {
            task.cancel()
            ongoingTasks.removeValue(forKey: task)
        }
        
        if let index = queue.index(of: transfer) {
            queue.remove(at: index)
        }
    }
    
    private func requestURL(forFileTransfer transfer: PTFileTransfer) {
        
        transfer.status = .waitingForURL
        self.delegate?.fileTransferDidChangeStatus(transfer)
        
        PTSession.shared.requestDownloadURL(forFile: transfer.file, completion: { [unowned self]
            result in
            
            OperationQueue.main.addOperation({
                
                switch result {
                case .success(let url):
                    transfer.url = url
                    transfer.status = .ready
                    
                case .failure(_):
                    transfer.url = nil
                    transfer.status = .failed
                }
                
                self.delegate?.fileTransferDidChangeStatus(transfer)
                
                self.checkQueue()
            })
        })
    }
    
    private func beginDownload(_ transfer: PTFileTransfer) {
        
        guard let url = transfer.url else {
            transfer.status = .failed
            delegate?.fileTransferDidChangeStatus(transfer)
            return
        }
        
        transfer.status = .downloading
        delegate?.fileTransferDidChangeStatus(transfer)
        
        let sessionConfig = URLSessionConfiguration.background(withIdentifier: "com.crapisarda.iPoliTO.\(transfer.file.identifier)")
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
        
        let downloadTask = session.downloadTask(with: url)
        
        ongoingTasks[downloadTask] = transfer
        transfer.task = downloadTask
        
        downloadTask.resume()
        
        session.finishTasksAndInvalidate()
    }
    
    private func checkQueue() {
        
        for transfer in queue {
            
            switch transfer.status {
                
            case .downloading:
                break
                
            case .ready:
                beginDownload(transfer)
                break
                
            case .added:
                requestURL(forFileTransfer: transfer)
                
            default:
                continue
            }
        }
    }
    
    
    
    // MARK: Downloaded files managing methods
    
    func delete(downloadedFileNamed fileName: String) {
        
        synchronizeDownloadedFiles()
        
        if let path = absolutePath(forDownloadedFileNamed: fileName, checkValidity: true) {
            
            do {
                try FileManager().removeItem(atPath: path)
            } catch _ {}
        }
        
        let filesToRemove = downloadedFiles.filter({ file in
            return file.fileName == fileName
        })
        
        for file in filesToRemove {
            
            guard let index = downloadedFiles.index(of: file) else {
                continue
            }
            
            downloadedFiles.remove(at: index)
        }
        
        let archive = NSKeyedArchiver.archivedData(withRootObject: downloadedFiles)
        UserDefaults().setValue(archive, forKey: downloadedFilesArchiveKey)
    }
    
    func delete(downloadedFile: PTDownloadedFile) {
        
        let fileName = downloadedFile.fileName
        delete(downloadedFileNamed: fileName)
    }
    
    private func add(downloadedFile: PTDownloadedFile) {
        
        synchronizeDownloadedFiles()
        
        downloadedFiles.insert(downloadedFile, at: 0)
        
        let archive = NSKeyedArchiver.archivedData(withRootObject: downloadedFiles)
        UserDefaults().setValue(archive, forKey: downloadedFilesArchiveKey)
    }
    
    private func synchronizeDownloadedFiles() {
        
        if let data = UserDefaults().value(forKey: downloadedFilesArchiveKey) as? Data {
            
            let downloadedFiles = NSKeyedUnarchiver.unarchiveObject(with: data) as! [PTDownloadedFile]
            
            self.downloadedFiles = downloadedFiles.sorted(by: {
                (fileA, fileB) in
                return fileA.downloadDate.compare(fileB.downloadDate) == .orderedDescending
            })
        } else {
            self.downloadedFiles = []
        }
    }
    
    private func createDownloadsFolderIfNecessary() {
        
        let fileManager = FileManager()
        let path = downloadsFolderPath
        
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue { return }
        }
        
        do {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
        } catch _ {}
    }
    
    class func clearDownloadsFolder() {
        
        let path = PTDownloadManager().downloadsFolderPath
        
        do {
            try FileManager().removeItem(atPath: path)
        } catch _ {}
        
        UserDefaults().setValue(nil, forKey: downloadedFilesArchiveKey)
    }
    
    class func clearAll() {
        
        let dlManager = PTDownloadManager.shared
        
        for (task, _) in dlManager.ongoingTasks {
            task.cancel()
        }
        
        dlManager.ongoingTasks.removeAll()
        dlManager.queue.removeAll()
        dlManager.downloadedFiles.removeAll()
        
        clearDownloadsFolder()
    }
    
    
    
    // MARK: Other methods
    
    /// Checks if file has been already downloaded; if yes, returns the corresponding PTDownloadedFile
    func checkIfAlreadyDownloaded(file: PTMFile) -> PTDownloadedFile? {
        
        let fileName = file.nameOnDisk
        return downloadedFiles.first(where: { $0.fileName == fileName })
    }
    
    /// Returns the absolute path for the specified fileName in the downloads folder.
    func absolutePath(forDownloadedFileNamed fileName: String, checkValidity: Bool) -> String? {
        
        let path = (downloadsFolderPath as NSString).appendingPathComponent(fileName)
        
        var isValid = true
        
        if checkValidity {
            isValid = FileManager().fileExists(atPath: path)
        }
        
        return isValid ? path : nil
    }
    
    
    
    // MARK: URLSession delegate methods
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        guard let download = ongoingTasks[downloadTask] else {
            return
        }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        download.progress = Float(progress)
        
        delegate?.fileTransferDidChangeStatus(download)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        // Gets the current transfer
        guard let transfer = ongoingTasks[downloadTask] else { return }
        
        // Updates its status
        transfer.status = .completed
        
        // Removes its task from the list of ongoing tasks
        ongoingTasks.removeValue(forKey: downloadTask)
        
        // Removes whitespace from the filename
        let fileName = transfer.file.nameOnDisk
        
        // Deletes any file with the same name
        delete(downloadedFileNamed: fileName)
        
        // Makes sure there's a download folder ready
        createDownloadsFolderIfNecessary()
        
        let tempPath = location.path
        let finalPath = absolutePath(forDownloadedFileNamed: fileName, checkValidity: false)!
        
        // Tries to move the new file to its final destination
        do {
            try FileManager().moveItem(atPath: tempPath, toPath: finalPath)
        } catch _ {
            
            // In case moving the file fails (should never happen)
            
            // Invalidates the task and marks the transfer as failed
            session.finishTasksAndInvalidate()
            transfer.status = .failed
            delegate?.fileTransferDidChangeStatus(transfer)
            return
        }
        
        // Creates a new PTDownloadedFile object
        let downloadedFile = PTDownloadedFile(fileName: fileName,
                                              description: transfer.file.description,
                                              subjectName: transfer.subject.name,
                                              downloadDate: Date())
        
        // Archives the PTDownloadedFile object and stores it in UD
        add(downloadedFile: downloadedFile)
        
        // Removes the transfer from the download queue
        if let index = queue.index(of: transfer) {
            queue.remove(at: index)
        }
        
        // Marks the task as completed
        session.finishTasksAndInvalidate()
        
        // Notifies the delegate: transfer is completed
        delegate?.fileTransferDidChangeStatus(transfer)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        guard let downloadTask = task as? URLSessionDownloadTask else {
            
            session.finishTasksAndInvalidate()
            
            return
        }
        
        guard let download = ongoingTasks[downloadTask] else {
            
            session.finishTasksAndInvalidate()
            
            return
        }
        
        download.status = .failed
        
        ongoingTasks.removeValue(forKey: downloadTask)
        
        session.finishTasksAndInvalidate()
        
        delegate?.fileTransferDidChangeStatus(download)
    }
}
