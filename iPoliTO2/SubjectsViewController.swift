//
//  SubjectsViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

// TODO: Rename this class (and VC) to something more appropriate!
// TODO: Show something when the table is empty

class SubjectsViewController: UITableViewController {
    
    var content: [Any] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }
    var dataOfSubjects: [PTSubject: PTSubjectData] = [:] {
        didSet {
            self.tableView.reloadData()
        }
    }
    var rootTable: SubjectsViewController?
    
    var expandedIndexPath: IndexPath?
    
    var subject: PTSubject? = nil

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        if rootTable == nil {
            
            self.tableView.delaysContentTouches = false
            rootTable = self
            
        } else if content.first is PTMessage {
            
            self.navigationItem.setRightBarButton(nil, animated: false)
        }
    }
    
    func downloadFile(_ file: PTMFile, subject: PTSubject) {
        
        if PTDownloadManager.shared.needsToOverwrite(byDownloadingFile: file) {
            
            let alertTitle = ~"File already downloaded!"
            let alertMessage = ~"A file with that name already exists. Do you want to overwrite it?"
            
            let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
            
            let alertCancel = ~"Cancel"
            let alertConfirm = ~"Confirm"
            
            alert.addAction(UIAlertAction(title: alertCancel, style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: alertConfirm, style: .destructive, handler: {
                action in
                
                PTDownloadManager.shared.enqueueFileDownload(file: file, subject: subject)
                self.performSegue(withIdentifier: "ShowDownloads_segue", sender: self)
            }))
            
            present(alert, animated: true, completion: nil)
            
        } else {
            
            PTDownloadManager.shared.enqueueFileDownload(file: file, subject: subject)
            performSegue(withIdentifier: "ShowDownloads_segue", sender: self)
        }
    }
    
    func moveToFolder(_ folder: PTMFolder) {
        
        guard let childController = storyboard?.instantiateViewController(withIdentifier: "SubjectsViewController_id") as? SubjectsViewController else {
            
            return
        }
        
        if folder.isEmpty {
            return
        }
        
        let children = folder.children
        
        childController.rootTable = self.rootTable
        childController.content = children.map({ $0 as Any })
        childController.title = folder.description
        childController.subject = self.subject
        
        self.navigationController?.pushViewController(childController, animated: true)
    }
    
    func showMessages(forSubject subject: PTSubject) {
        
        // Assuming self is the root controller
        
        guard let childController = storyboard?.instantiateViewController(withIdentifier: "SubjectsViewController_id") as? SubjectsViewController else {
            
            return
        }
        
        let subjectData = self.dataOfSubjects[subject]
        
        guard let messages = subjectData?.messages else {
            
            return
        }
        
        childController.rootTable = self
        childController.content = messages.map({ $0 as Any })
        childController.title = subject.name
        childController.subject = subject
        
        self.navigationController?.pushViewController(childController, animated: true)
    }
    
    func showDocuments(forSubject subject: PTSubject) {
        
        // Assuming self is the root controller
        
        
        guard let childController = storyboard?.instantiateViewController(withIdentifier: "SubjectsViewController_id") as? SubjectsViewController else {
            
            return
        }
        
        let subjectData = self.dataOfSubjects[subject]
        
        guard let documents = subjectData?.documents else {
            
            return
        }
        
        childController.rootTable = self
        childController.content = documents.map({ $0 as Any })
        childController.title = subject.name
        childController.subject = subject
        
        self.navigationController?.pushViewController(childController, animated: true)
    }
    
    func messagesButtonPressed(sender: UIButton)  {
        let touchPoint: CGPoint = sender.convert(CGPoint.zero, to: self.tableView)
        let indexPath = self.tableView.indexPathForRow(at: touchPoint)!
        
        if let subject = content[indexPath.row] as? PTSubject {
            
            showMessages(forSubject: subject)
        }
    }
    
    func documentsButtonPressed(sender: UIButton)  {
        let touchPoint: CGPoint = sender.convert(CGPoint.zero, to: self.tableView)
        let indexPath = self.tableView.indexPathForRow(at: touchPoint)!
        
        if let subject = content[indexPath.row] as? PTSubject {
            
            showDocuments(forSubject: subject)
        }
    }
    
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        
        let this = content[indexPath.row]
        
        if this is PTSubject {
            
            if indexPath == expandedIndexPath {
                return PTSubjectCell.expandedHeight
            } else {
                return PTSubjectCell.height
            }
            
        } else if this is PTMessage {
            
            let message = this as! PTMessage
            return PTMessageCell.estimatedHeight(message: message, rowWidth: tableView.frame.width)
            
        } else if this is PTMFolder {
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
        
        if this is PTSubject {
            identifier = PTSubjectCell.identifier
            
        } else if this is PTMessage {
            identifier = PTMessageCell.identifier
            
        } else if this is PTMFolder {
            identifier = PTFolderCell.identifier
            
        } else if this is PTMFile {
            identifier = PTFileCell.identifier
        }
        
        return tableView.dequeueReusableCell(withIdentifier: identifier)!
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let this = content[indexPath.row]
        
        if let theCell = cell as? PTSubjectCell, let subject = this as? PTSubject {
            
            theCell.setSubject(subject, andData: dataOfSubjects[subject])
            
            theCell.messagesButton.addTarget(self, action: #selector(self.messagesButtonPressed), for: .touchUpInside)
            theCell.documentsButton.addTarget(self, action: #selector(self.documentsButtonPressed), for: .touchUpInside)
            
        } else if let theCell = cell as? PTMessageCell, let message = this as? PTMessage {
            
            theCell.setMessage(message: message)
            
        } else if let theCell = cell as? PTFolderCell, let folder = this as? PTMFolder {
            
            theCell.setFolder(folder: folder)
            
        } else if let theCell = cell as? PTFileCell, let file = this as? PTMFile {
            
            theCell.setFile(file: file)
        }
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if tableView.cellForRow(at: indexPath)?.selectionStyle == .none {
            return nil
        } else {
            return indexPath
        }
    }
    
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let this = content[indexPath.row]
        
        if this is PTSubject {
            
            tableView.beginUpdates()
            
            if expandedIndexPath != indexPath {
                expandedIndexPath = indexPath
            } else {
                expandedIndexPath = nil
            }
            
            tableView.endUpdates()
            
        } else if let folder = this as? PTMFolder {
            
            moveToFolder(folder)
            
        } else if let file = this as? PTMFile {
            
            let alertTitle = ~"Do you want to proceed?"
            let alertMessage = ~"You chose \""+file.description+"\"."
            
            let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
            
            let alertCancel = ~"Cancel"
            let alertConfirm = ~"Confirm"
            
            alert.addAction(UIAlertAction(title: alertCancel, style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: alertConfirm, style: .default, handler: {
                action in
                
                self.downloadFile(file, subject: self.subject!)
            }))
            
            present(alert, animated: true, completion: nil)
        }
        
        
    }

}

