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
    var transfersQueue: [PTFileTransfer] {
        return downloadManager.queue
    }
    var downloadedFiles: [PTDownloadedFile] {
        return downloadManager.downloadedFiles
    }
    var documentInteractionController: UIDocumentInteractionController?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        downloadManager.delegate = self
        
        // Removes annoying row separators after the last cell
        tableView.tableFooterView = UIView()
    }
    
    func fileTransferDidChangeStatus(_ transfer: PTFileTransfer) {
        
        if transfer.status == .Completed {
            
            tableView.reloadData()
            return
        }
        
        if let index = transfersQueue.index(of: transfer) {
            
            let indexPath = IndexPath(row: index, section: 0)
            
            if let visibleIndexPaths = tableView.indexPathsForVisibleRows {
                
                if visibleIndexPaths.contains(indexPath) {
                    
                    let cell = tableView.cellForRow(at: indexPath) as? PTFileTransferCell
                    cell?.setFileTransfer(transfer, animated: true)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if transfersQueue.isEmpty && downloadedFiles.isEmpty {
            tableView.backgroundView = NoDownloadsBackgroundView(frame: tableView.bounds)
        } else {
            tableView.backgroundView = nil
        }
        
        switch section {
        case 0:
            return transfersQueue.count
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
            return (transfersQueue.isEmpty ? nil : ~"Transfers")
        case 1:
            return (downloadedFiles.isEmpty ? nil : ~"Completed")
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        if indexPath.section == 0 {
            
            let transfer = transfersQueue[indexPath.row]
            
            
            let retryAction = UITableViewRowAction(style: .normal, title: ~"Retry", handler: {
                (action, indexPath) in
                
                self.setEditing(false, animated: true)
                self.downloadManager.retry(fileTransfer: transfer)
            })
            retryAction.backgroundColor = #colorLiteral(red: 0.4028071761, green: 0.7315050364, blue: 0.2071235478, alpha: 1)
            
            let resumeAction = UITableViewRowAction(style: .normal, title: ~"Resume", handler: {
                (action, indexPath) in
                
                self.setEditing(false, animated: true)
                self.downloadManager.resume(fileTransfer: transfer)
            })
            resumeAction.backgroundColor = #colorLiteral(red: 0.4028071761, green: 0.7315050364, blue: 0.2071235478, alpha: 1)
            
            let pauseAction = UITableViewRowAction(style: .normal, title: ~"Pause", handler: {
                (action, indexPath) in
                
                self.setEditing(false, animated: true)
                self.downloadManager.pause(fileTransfer: transfer)
            })
            
            let cancelAction = UITableViewRowAction(style: .destructive, title: ~"Cancel", handler: {
                (action, indexPath) in
                
                tableView.beginUpdates()
                
                self.downloadManager.cancel(fileTransfer: transfer)
                tableView.deleteRows(at: [indexPath], with: .automatic)
                
                tableView.endUpdates()
            })
            
            switch transfer.status {
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
                
                self.downloadManager.delete(downloadedFile: file)
                tableView.deleteRows(at: [indexPath], with: .automatic)
                
                tableView.endUpdates()
            })
            
            return [deleteAction]
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return PTFileTransferCell.height
        } else {
            return PTDownloadedFileCell.height
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if let cell = cell as? PTFileTransferCell {
            
            let transfer = transfersQueue[indexPath.row]
            cell.setFileTransfer(transfer, animated: false)
            
        } else if let cell = cell as? PTDownloadedFileCell {
            
            let file = downloadedFiles[indexPath.row]
            cell.setDownloadedFile(file)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let identifier: String
        
        if indexPath.section == 0 {
            identifier = PTFileTransferCell.identifier
        } else {
            identifier = PTDownloadedFileCell.identifier
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
            let fileName = downloadedFile.fileName
            
            if let path = downloadManager.absolutePath(forDownloadedFileNamed: fileName, checkValidity: true) {
                
                documentInteractionController = UIDocumentInteractionController()
                documentInteractionController?.url = URL(fileURLWithPath: path)
                documentInteractionController?.uti = "public.filename-extension"
                
                documentInteractionController?.presentOpenInMenu(from: view.bounds, in: view, animated: true)
                
            } else {
                
                // File does not exist!
                
                let alert = UIAlertController(title: ~"Oops!", message: ~"This file appears to be damaged! Try to download it again.", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: ~"Dismiss", style: .default, handler: {
                    action in
                    
                    tableView.beginUpdates()
                    
                    self.downloadManager.delete(downloadedFileNamed: fileName)
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                    
                    tableView.endUpdates()
                }))
                
                present(alert, animated: true, completion: nil)
            }
        }
    }
    
    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        
        self.dismiss(animated: true, completion: nil)
    }
    
}

class PTFileTransferCell: UITableViewCell {
    
    static let identifier = "PTFileTransferCell_id"
    static let height = 113 as CGFloat
    
    @IBOutlet var fileNameLabel: UILabel!
    @IBOutlet var subjectNameLabel: UILabel!
    @IBOutlet var progressLabel: UILabel!
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var progressBar: UIProgressView!
    
    func setFileTransfer(_ transfer: PTFileTransfer, animated: Bool) {
        
        fileNameLabel.text = transfer.file.description
        subjectNameLabel.text = transfer.subject.name
        
        setProgress(transfer.progress, animated: animated, finalSizeKB: transfer.file.size)
        
        statusLabel.text = transfer.status.localizedDescription()
    }
    
    private func setProgress(_ progress: Float, animated: Bool, finalSizeKB: Int?) {
        
        if let size = finalSizeKB {
            
            let downloadedKB = progress*Float(size)
            
            progressLabel.text = "\(downloadedKB)"+(~" of ")+"\(size) KB (\(progress*100.0)%)"
        }
        
        progressBar.setProgress(progress, animated: animated)
    }
}

class PTDownloadedFileCell: UITableViewCell {
    
    static let identifier = "PTDownloadedFileCell_id"
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

fileprivate class NoDownloadsBackgroundView: UIView {
    
    private let label: UILabel
    
    override init(frame: CGRect) {
        
        label = UILabel()
        
        super.init(frame: frame)
        
        backgroundColor = UIColor.clear
        
        label.font = UIFont.systemFont(ofSize: 15.0)
        label.textColor = UIColor.lightGray
        label.text = ~"Nothing to see here!"
        label.sizeToFit()
        
        addSubview(label)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        label.center = CGPoint(x: frame.width/2.0, y: frame.height/2.0)
    }
    
}

