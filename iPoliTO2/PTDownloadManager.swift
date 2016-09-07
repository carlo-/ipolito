//
//  PTDownloadManager.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 04/08/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import Foundation

fileprivate let downloadedFilesArchiveKey: String = "downloadedFiles"

enum PTFileTransferStatus {
    case Downloading
    case Cancelled
    case Failed
    case Paused
    case Completed
    case WaitingForURL
    case Ready
    case Added
    
    func localizedDescription() -> String {
        
        switch self {
        case .Downloading:
            return ~"Downloading..."
        case .Cancelled:
            return ~"Cancelled"
        case .Failed:
            return ~"Failed"
        case .Paused:
            return ~"Paused"
        case .Completed:
            return ~"Completed"
        case .WaitingForURL:
            return ~"Waiting for a valid URL"
        case .Ready, .Added:
            return ~"On queue"
        }
    }
}

class PTDownloadedFile: NSObject, NSCoding {
    
    let path: String
    let fileDescription: String
    let subjectName: String
    let downloadDate: Date
    
    init(path: String, description: String, subjectName: String, downloadDate: Date) {
        
        self.path = path
        self.fileDescription = description
        self.subjectName = subjectName
        self.downloadDate = downloadDate
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(path, forKey: "path")
        aCoder.encode(fileDescription, forKey: "fileDescription")
        aCoder.encode(subjectName, forKey: "subjectName")
        aCoder.encode(downloadDate, forKey: "downloadDate")
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        self.path = aDecoder.decodeObject(forKey: "path") as! String
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
    var status: PTFileTransferStatus = .Added
    var task: URLSessionDownloadTask?
    
    init(file: PTMFile, url: URL? = nil, subject: PTSubject) {
        self.file = file
        self.url = url
        self.subject = subject
        
        if url != nil {
            self.status = .Ready
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
        transfer.status = .Downloading
        
        delegate?.fileTransferDidChangeStatus(transfer)
    }
    
    func pause(fileTransfer transfer: PTFileTransfer) {
        
        transfer.task?.suspend()
        transfer.status = .Paused
        
        delegate?.fileTransferDidChangeStatus(transfer)
        
        checkQueue()
    }
    
    func retry(fileTransfer transfer: PTFileTransfer) {
        
        transfer.status = .Added
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
        
        transfer.status = .WaitingForURL
        self.delegate?.fileTransferDidChangeStatus(transfer)
        
        PTSession.shared.requestDownloadURL(forFile: transfer.file, completion: {
            url in
            
            OperationQueue.main.addOperation({
                
                transfer.url = url
                transfer.status = (url == nil ? .Failed : .Ready)
                
                self.delegate?.fileTransferDidChangeStatus(transfer)
                
                self.checkQueue()
            })
        })
    }
    
    private func beginDownload(_ transfer: PTFileTransfer) {
        
        guard let url = transfer.url else {
            transfer.status = .Failed
            delegate?.fileTransferDidChangeStatus(transfer)
            return
        }
        
        transfer.status = .Downloading
        delegate?.fileTransferDidChangeStatus(transfer)
        
        let sessionConfig = URLSessionConfiguration.background(withIdentifier: "com.crapisarda.iPoliTO.\(transfer.file.identifier)")
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
        
        let downloadTask = session.downloadTask(with: url)
        
        ongoingTasks[downloadTask] = transfer
        transfer.task = downloadTask
        
        downloadTask.resume()
    }
    
    private func checkQueue() {
        
        for transfer in queue {
            
            
            
            if transfer.status == .Downloading {
                break
            }
            
            if transfer.status == .Ready {
                beginDownload(transfer)
                break
            }
            
            if transfer.status == .Added {
                requestURL(forFileTransfer: transfer)
            }
        }
    }
    
    
    
    // MARK: Downloaded files managing methods
    
    func delete(downloadedFileAtPath path: String) {
        
        synchronizeDownloadedFiles()
        
        let fileManager = FileManager()
        
        if fileManager.fileExists(atPath: path) {
            
            do {
                try fileManager.removeItem(atPath: path)
            } catch _ {}
        }
        
        let filesToRemove = downloadedFiles.filter({ file in
            return file.path == path
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
        
        let path = downloadedFile.path
        delete(downloadedFileAtPath: path)
    }
    
    private func add(downloadedFile: PTDownloadedFile) {
        
        synchronizeDownloadedFiles()
        
        downloadedFiles.append(downloadedFile)
        
        let archive = NSKeyedArchiver.archivedData(withRootObject: downloadedFiles)
        UserDefaults().setValue(archive, forKey: downloadedFilesArchiveKey)
    }
    
    private func synchronizeDownloadedFiles() {
        
        UserDefaults().synchronize()
        
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
    
    class func clearDownloadsFolder() {
        
        let fileManager = FileManager.default
        let docsFolderPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        do {
            let filePaths = try fileManager.contentsOfDirectory(atPath: docsFolderPath)
            for filePath in filePaths {
                let fullPath = (docsFolderPath as NSString).appendingPathComponent(filePath)
                try fileManager.removeItem(atPath: fullPath)
            }
        } catch {
            print("Could not clear temp folder: \(error)")
        }
    }
    
    
    
    // MARK: Other methods
    
    func needsToOverwrite(byDownloadingFile file: PTMFile) -> Bool {
        
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
            else { return false }
        
        let fileName = file.name.replacingOccurrences(of: " ", with: "-")
        let filePath = documentsPath+"/"+fileName
        
        return FileManager().fileExists(atPath: filePath)
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
        
        guard let transfer = ongoingTasks[downloadTask],
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
            else { return }
        
        let tempPath = location.path
        
        transfer.status = .Completed
        
        ongoingTasks.removeValue(forKey: downloadTask)
        
        
        let fileName = transfer.file.name.replacingOccurrences(of: " ", with: "-")
        
        let filePath = documentsPath+"/"+fileName
        
        let fileManager = FileManager()
        
        delete(downloadedFileAtPath: filePath)
        
        do {
            try fileManager.moveItem(atPath: tempPath, toPath: filePath)
        } catch _ {
            
            session.finishTasksAndInvalidate()
            transfer.status = .Failed
            delegate?.fileTransferDidChangeStatus(transfer)
            return
        }
        
        let downloadedFile = PTDownloadedFile(path: filePath,
                                              description: transfer.file.description,
                                              subjectName: transfer.subject.name,
                                              downloadDate: Date())
        
        add(downloadedFile: downloadedFile)
        
        if let index = queue.index(of: transfer) {
            queue.remove(at: index)
        }
        
        session.finishTasksAndInvalidate()
        
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
        
        download.status = .Failed
        
        ongoingTasks.removeValue(forKey: downloadTask)
        
        session.finishTasksAndInvalidate()
        
        delegate?.fileTransferDidChangeStatus(download)
    }
}
