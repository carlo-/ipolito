//
//  PTDownloadManager.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 04/08/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import Foundation

enum PTDownloadStatus {
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

class PTFileDownload: NSObject {
    
    let file: PTMFile
    let subject: PTSubject
    var url: URL?
    var progress: Float = 0.0
    var status: PTDownloadStatus = .Added
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
    func fileDownloadDidChangeStatus(_ download: PTFileDownload)
}

extension PTDownloadManagerDelegate {
    func fileDownloadDidChangeStatus(_ download: PTFileDownload) {}
}

class PTDownloadManager: NSObject, URLSessionDownloadDelegate {
    
    static let shared = PTDownloadManager()
    
    private override init() {
        super.init()
    }
    
    var queue: [PTFileDownload] = [] {
        didSet {
            checkQueue()
        }
    }
    
    var ongoingTasks: [URLSessionDownloadTask: PTFileDownload] = [:]
    
    var delegate: PTDownloadManagerDelegate? = nil
    
    
    
    
    
    
    func needsToOverwrite(byDownloadingFile file: PTMFile) -> Bool {
        
        guard let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        else { return false }
        
        let fileName = file.name.replacingOccurrences(of: " ", with: "-")
        let filePath = documentsPath+"/"+fileName
        
        return FileManager().fileExists(atPath: filePath)
    }
    
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        guard let download = ongoingTasks[downloadTask] else {
            return
        }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        download.progress = Float(progress)
        
        delegate?.fileDownloadDidChangeStatus(download)
    }
    
    
    
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    
        guard let download = ongoingTasks[downloadTask],
              let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        else { return }
        
        let tempPath = location.path
        
        download.status = .Completed
        
        ongoingTasks.removeValue(forKey: downloadTask)
        
        
        let fileName = download.file.name.replacingOccurrences(of: " ", with: "-")
        
        let filePath = documentsPath+"/"+fileName
        
        let fileManager = FileManager()
        
        removeDownloadedFile(atPath: filePath)
        
        do {
            try fileManager.moveItem(atPath: tempPath, toPath: filePath)
        } catch _ {
            // Error!
            // [...]
            
            session.finishTasksAndInvalidate()
            
            download.status = .Failed
            delegate?.fileDownloadDidChangeStatus(download)
            
            return
        }
        
        let downloadedFile = PTDownloadedFile(path: filePath,
                         description: download.file.description,
                         subjectName: download.subject.name,
                         downloadDate: Date())
        
        UserDefaults().synchronize()
        
        var downloadedFiles: [PTDownloadedFile] = {
            
            if let data = UserDefaults().value(forKey: "downloadedFiles") as? Data {
                return NSKeyedUnarchiver.unarchiveObject(with: data) as! [PTDownloadedFile]
            } else {
                return []
            }
        }()
        
        downloadedFiles.append(downloadedFile)
        
        UserDefaults().setValue(NSKeyedArchiver.archivedData(withRootObject: downloadedFiles), forKey: "downloadedFiles")
        
        
        if let index = queue.index(of: download) {
            
            queue.remove(at: index)
        }
        
        session.finishTasksAndInvalidate()
        
        delegate?.fileDownloadDidChangeStatus(download)
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
        
        delegate?.fileDownloadDidChangeStatus(download)
    }
    
    
    
    func removeDownloadedFile(atPath path: String) {
        
        let fileManager = FileManager()
        
        if fileManager.fileExists(atPath: path) {
            
            do {
                try fileManager.removeItem(atPath: path)
            } catch _ {
                print("Error! Could not remove file!")
                return
            }
        }
        
        
        UserDefaults().synchronize()
        
        var downloadedFiles: [PTDownloadedFile] = {
            
            if let data = UserDefaults().value(forKey: "downloadedFiles") as? Data {
                return NSKeyedUnarchiver.unarchiveObject(with: data) as! [PTDownloadedFile]
            } else {
                return []
            }
        }()
        
        let filesToRemove = downloadedFiles.filter({
            file in
            
            return file.path == path
        })
        
        for file in filesToRemove {
            
            guard let index = downloadedFiles.index(of: file) else {
                continue
            }
            
            downloadedFiles.remove(at: index)
        }
        
        UserDefaults().setValue(NSKeyedArchiver.archivedData(withRootObject: downloadedFiles), forKey: "downloadedFiles")
    }
    
    func enqueueFileDownload(file: PTMFile, subject: PTSubject) {
        
        for dwld in queue {
            if dwld.file.identifier == file.identifier {
                return
            }
        }
        
        let dwld = PTFileDownload(file: file, subject: subject)
        self.queue.append(dwld)
        
        delegate?.fileDownloadDidChangeStatus(dwld)
    }
    
    func resumeFileDownload(_ download: PTFileDownload) {
        
        download.task?.resume()
        download.status = .Downloading
        
        delegate?.fileDownloadDidChangeStatus(download)
    }
    
    func pauseFileDownload(_ download: PTFileDownload) {
        
        download.task?.suspend()
        download.status = .Paused
        
        delegate?.fileDownloadDidChangeStatus(download)
        
        checkQueue()
    }
    
    func retryFileDownload(_ download: PTFileDownload) {
        
        download.status = .Added
        checkQueue()
    }
    
    func cancelFileDownload(_ download: PTFileDownload) {
        
        if let task = download.task {
            task.cancel()
            ongoingTasks.removeValue(forKey: task)
        }
        
        if let index = queue.index(of: download) {
            queue.remove(at: index)
        }
    }
    
    
    
    
    
    private func requestURL(forDownload download: PTFileDownload) {
        
        download.status = .WaitingForURL
        self.delegate?.fileDownloadDidChangeStatus(download)
        
        PTSession.shared.requestDownloadURL(forFile: download.file, completion: {
            url in
            
            OperationQueue.main.addOperation({
                
                download.url = url
                download.status = (url == nil ? .Failed : .Ready)
                
                self.delegate?.fileDownloadDidChangeStatus(download)
                
                self.checkQueue()
            })
        })
    }
    
    private func beginDownload(_ download: PTFileDownload) {
        
        guard let url = download.url else {
            download.status = .Failed
            delegate?.fileDownloadDidChangeStatus(download)
            return
        }
        
        download.status = .Downloading
        delegate?.fileDownloadDidChangeStatus(download)
        
        let sessionConfig = URLSessionConfiguration.background(withIdentifier: "com.crapisarda.iPoliTO.\(download.file.identifier)")
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
        
        let downloadTask = session.downloadTask(with: url)
        
        ongoingTasks[downloadTask] = download
        download.task = downloadTask
        
        downloadTask.resume()
    }
    
    private func checkQueue() {
        
        for download in queue {
            
            
            
            if download.status == .Downloading {
                break
            }
            
            if download.status == .Ready {
                beginDownload(download)
                break
            }
            
            if download.status == .Added {
                requestURL(forDownload: download)
            }
        }
    }
}
