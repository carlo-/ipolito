//
//  DownloadsViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 04/08/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit


class DownloadsViewController: UITableViewController, PTDownloadManagerDelegate {
    
    var downloadManager: PTDownloadManager {
        return PTDownloadManager.shared
    }
    var downloadQueue: [PTFileDownload] {
        return downloadManager.queue
    }
    var downloadedFiles: [PTDownloadedFile] = []
    var documentInteractionController: UIDocumentInteractionController?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        downloadManager.delegate = self
        
        synchronizeDownloadedFiles()
        
        
    }
    
    func synchronizeDownloadedFiles() {
        
        UserDefaults().synchronize()
        
        if let data = UserDefaults().value(forKey: "downloadedFiles") as? Data {
            
            let downloadedFiles = NSKeyedUnarchiver.unarchiveObject(with: data) as! [PTDownloadedFile]
            
            self.downloadedFiles = downloadedFiles.sorted(by: {
                (fileA, fileB) in
                return fileA.downloadDate.compare(fileB.downloadDate) == .orderedDescending
            })
        } else {
            self.downloadedFiles = []
        }
    }
    
    func fileDownloadDidChangeStatus(_ download: PTFileDownload) {
        
        if download.status == .Completed {
            
            synchronizeDownloadedFiles()
            tableView.reloadData()
            return
        }
        
        if let index = downloadQueue.index(of: download) {
            
            let indexPath = IndexPath(row: index, section: 0)
            
            if let visibleIndexPaths = tableView.indexPathsForVisibleRows {
                
                if visibleIndexPaths.contains(indexPath) {
                    
                    let cell = tableView.cellForRow(at: indexPath) as? PTDownloadCell
                    cell?.setFileDownload(download, animated: true)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        case 0:
            return downloadQueue.count
        case 1:
            return downloadedFiles.count
        default:
            return 0
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        switch section {
        case 0:
            return (downloadQueue.isEmpty ? nil : ~"Transfers")
        case 1:
            return (downloadedFiles.isEmpty ? nil : ~"Completed")
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        if indexPath.section == 0 {
            
            let dwld = downloadQueue[indexPath.row]
            
            
            let retryAction = UITableViewRowAction(style: .normal, title: ~"Retry", handler: {
                (action, indexPath) in
                
                self.setEditing(false, animated: true)
                self.downloadManager.retryFileDownload(dwld)
            })
            retryAction.backgroundColor = #colorLiteral(red: 0.4028071761, green: 0.7315050364, blue: 0.2071235478, alpha: 1)
            
            let resumeAction = UITableViewRowAction(style: .normal, title: ~"Resume", handler: {
                (action, indexPath) in
                
                self.setEditing(false, animated: true)
                self.downloadManager.resumeFileDownload(dwld)
            })
            resumeAction.backgroundColor = #colorLiteral(red: 0.4028071761, green: 0.7315050364, blue: 0.2071235478, alpha: 1)
            
            let pauseAction = UITableViewRowAction(style: .normal, title: ~"Pause", handler: {
                (action, indexPath) in
                
                self.setEditing(false, animated: true)
                self.downloadManager.pauseFileDownload(dwld)
            })
            
            let cancelAction = UITableViewRowAction(style: .destructive, title: ~"Cancel", handler: {
                (action, indexPath) in
                
                tableView.beginUpdates()
                
                self.downloadManager.cancelFileDownload(dwld)
                tableView.deleteRows(at: [indexPath], with: .automatic)
                
                tableView.endUpdates()
            })
            
            switch dwld.status {
            case .Downloading, .Ready, .WaitingForURL:
                return [cancelAction, pauseAction]
            case .Paused:
                return [cancelAction, resumeAction]
            case .Failed:
                return [cancelAction, retryAction]
            default:
                return nil
            }
            
        } else {
            
            let file = downloadedFiles[indexPath.row]
            
            let deleteAction = UITableViewRowAction(style: .destructive, title: ~"Delete", handler: {
                (action, indexPath) in
                
                tableView.beginUpdates()
                
                self.downloadManager.removeDownloadedFile(atPath: file.path)
                self.synchronizeDownloadedFiles()
                tableView.deleteRows(at: [indexPath], with: .automatic)
                
                tableView.endUpdates()
            })
            
            return [deleteAction]
        }
    }
    /*
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
        if (editingStyle == .delete) {
            // handle delete (by removing the data from your array and updating the tableview)
            
            print("commit editingStyle")
        }
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return UITableViewCellEditingStyle.delete
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
     */
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return PTDownloadCell.height
        } else {
            return PTArchivedFileCell.height
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if let cell = cell as? PTDownloadCell {
            
            let dwld = downloadQueue[indexPath.row]
            cell.setFileDownload(dwld, animated: false)
            
        } else if let cell = cell as? PTArchivedFileCell {
            
            let file = downloadedFiles[indexPath.row]
            cell.setDownloadedFile(file)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let identifier: String
        
        if indexPath.section == 0 {
            identifier = PTDownloadCell.identifier
        } else {
            identifier = PTArchivedFileCell.identifier
        }
        
        return tableView.dequeueReusableCell(withIdentifier: identifier, for: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            
            if let cell = tableView.cellForRow(at: indexPath) {
                
                cell.setEditing(true, animated: true)
            }
            
        } else {
            
            let downloadedFile = downloadedFiles[indexPath.row]
            
            documentInteractionController = UIDocumentInteractionController()
            documentInteractionController?.url = URL(fileURLWithPath: downloadedFile.path)
            documentInteractionController?.uti = "public.filename-extension"
            
            documentInteractionController?.presentOpenInMenu(from: view.bounds, in: view, animated: true)
        }
    }
    
    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        
        self.dismiss(animated: true, completion: nil)
    }
    
}


class PTDownloadCell: UITableViewCell {
    
    static let identifier = "PTDownloadCell_id"
    static let height = 113 as CGFloat
    
    @IBOutlet var fileNameLabel: UILabel!
    @IBOutlet var subjectNameLabel: UILabel!
    @IBOutlet var progressLabel: UILabel!
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var progressBar: UIProgressView!
    
    func setFileDownload(_ download: PTFileDownload, animated: Bool) {
        
        fileNameLabel.text = download.file.description
        subjectNameLabel.text = download.subject.name
        
        setProgress(download.progress, animated: animated, finalSizeKB: download.file.size)
        
        statusLabel.text = download.status.localizedDescription()
    }
    
    private func setProgress(_ progress: Float, animated: Bool, finalSizeKB: Int?) {
        
        if let size = finalSizeKB {
            
            let downloadedKB = progress*Float(size)
            
            progressLabel.text = "\(downloadedKB)"+(~" of ")+"\(size) KB (\(progress*100.0)%)"
        }
        
        progressBar.setProgress(progress, animated: animated)
    }
}

class PTArchivedFileCell: UITableViewCell {
    
    static let identifier = "PTArchivedFileCell_id"
    static let height = 90 as CGFloat
    
    @IBOutlet var fileNameLabel: UILabel!
    @IBOutlet var subjectNameLabel: UILabel!
    @IBOutlet var detailsLabel: UILabel!
    
    func setDownloadedFile(_ file: PTDownloadedFile) {
        
        fileNameLabel.text = file.fileDescription
        subjectNameLabel.text = file.subjectName
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.Turin
        formatter.dateStyle = .medium
        
        detailsLabel.text = ~"Downloaded on "+formatter.string(from: file.downloadDate)
    }
}















