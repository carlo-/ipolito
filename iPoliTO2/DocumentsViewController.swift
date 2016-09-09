//
//  DocumentsViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 09/09/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

class DocumentsViewController: UITableViewController {
    
    static let identifier = "DocumentsViewController_id"
    
    private var content: [PTMElement] = []
    private var subject: PTSubject!
    private var rootController: DocumentsViewController!
    
    func configure(forSubject subject: PTSubject, withDocuments documents: [PTMElement]) {
        
        self.title = subject.name
        self.content = documents
        self.rootController = self
        self.subject = subject
    }
    
    private func configure(forFolder folder: PTMFolder, andRootController rootController: DocumentsViewController) {
        
        self.title = folder.description
        self.content = folder.children
        self.rootController = rootController
        self.subject = rootController.subject
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Removes annoying row separators after the last cell
        tableView.tableFooterView = UIView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let dlManager = PTDownloadManager.shared
        
        let cannotShowDownloads = dlManager.queue.isEmpty && dlManager.downloadedFiles.isEmpty
        
        navigationItem.rightBarButtonItem?.isEnabled = !cannotShowDownloads
    }
    
    
    
    func didSelectFolder(_ folder: PTMFolder) {
        
        moveToFolder(folder)
    }
    
    func didSelectFile(_ file: PTMFile) {
        
        let alertTitle = ~"Do you want to proceed?"
        let alertMessage = ~"You chose \""+file.description+"\"."
        
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        
        let alertCancel = ~"Cancel"
        let alertConfirm = ~"Confirm"
        
        alert.addAction(UIAlertAction(title: alertCancel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: alertConfirm, style: .default, handler: {
            action in
            
            self.downloadFile(file)
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    func moveToFolder(_ folder: PTMFolder) {
        
        if folder.isEmpty {
            return
        }
        
        let id = DocumentsViewController.identifier
        
        if let childController = storyboard?.instantiateViewController(withIdentifier: id) as? DocumentsViewController {
            
            childController.configure(forFolder: folder, andRootController: rootController)
            
            navigationController?.pushViewController(childController, animated: true)
        }
    }
    
    func downloadFile(_ file: PTMFile) {
        
        
        if PTDownloadManager.shared.needsToOverwrite(byDownloadingFile: file) {
            
            let alertTitle = ~"File already downloaded!"
            let alertMessage = ~"A file with that name already exists. Do you want to overwrite it?"
            
            let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
            
            let alertCancel = ~"Cancel"
            let alertConfirm = ~"Confirm"
            
            alert.addAction(UIAlertAction(title: alertCancel, style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: alertConfirm, style: .destructive, handler: {
                action in
                
                PTDownloadManager.shared.enqueueForDownload(file: file, ofSubject: self.subject)
                self.performSegue(withIdentifier: "ShowDownloads_segue", sender: self)
            }))
            
            present(alert, animated: true, completion: nil)
            
        } else {
            
            PTDownloadManager.shared.enqueueForDownload(file: file, ofSubject: subject)
            performSegue(withIdentifier: "ShowDownloads_segue", sender: self)
        }
    }
    
    
    
    // MARK: TableView delegate methods
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        let this = content[indexPath.row]
        
        if this is PTMFolder {
            return PTFolderCell.height
            
        } else if this is PTMFile {
            return PTFileCell.height
        }
        
        return 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return content.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var identifier = ""
        
        let this = content[indexPath.row]
        
        if this is PTMFolder {
            identifier = PTFolderCell.identifier
            
        } else if this is PTMFile {
            identifier = PTFileCell.identifier
        }
        
        return tableView.dequeueReusableCell(withIdentifier: identifier)!
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let this = content[indexPath.row]
        
        if let theCell = cell as? PTFolderCell, let folder = this as? PTMFolder {
            
            theCell.configure(forFolder: folder)
            
        } else if let theCell = cell as? PTFileCell, let file = this as? PTMFile {
            
            theCell.configure(forFile: file)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let this = content[indexPath.row]
        
        if let folder = this as? PTMFolder {
            
            didSelectFolder(folder)
            
        } else if let file = this as? PTMFile {
            
            didSelectFile(file)
        }
    }
}


class PTFolderCell: UITableViewCell {
    
    static let identifier = "PTFolderCell_id"
    static let height = 70 as CGFloat
    
    @IBOutlet var mainLabel: UILabel!
    @IBOutlet var iconView: UIImageView!
    
    func configure(forFolder folder: PTMFolder) {
        
        mainLabel.text = folder.description
    }
}


class PTFileCell: UITableViewCell {
    
    static let identifier = "PTFileCell_id"
    static let height = 70 as CGFloat
    
    @IBOutlet var mainLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet var iconView: UIImageView!
    
    func configure(forFile file: PTMFile) {
        
        var arr: [String] = []
        
        if let date = file.date {
            
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            formatter.timeZone = TimeZone.Turin
            
            arr.append(formatter.string(from: date))
        }
        
        if let ext = file.extension {
            arr.append(ext)
            
            iconView.image = PTIcon(forFileWithExtension: ext)
        }
        
        if let size = file.size {
            arr.append("\(size)KB")
        }
        
        let subtitle = arr.joined(separator: " - ")
        
        mainLabel.text = file.description
        subtitleLabel.text = subtitle
    }
}
