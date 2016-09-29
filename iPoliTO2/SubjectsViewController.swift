//
//  SubjectsViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

class SubjectsViewController: UITableViewController {
    
    var subjects: [PTSubject] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }
    var dataOfSubjects: [PTSubject: PTSubjectData] = [:] {
        didSet {
            self.tableView.reloadData()
        }
    }
    var status: PTViewControllerStatus = .loggedOut {
        didSet {
            statusDidChange()
        }
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
    
    
    func statusDidChange() {
        
        let isTableEmpty = subjects.isEmpty
        
        if isTableEmpty {
            
            navigationItem.titleView = nil
            
            switch status {
            case .logginIn:
                tableView.backgroundView = PTLoadingTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.loggingIn")
            case .offline:
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.offline")
            case .error:
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.couldNotRetrieve")
            case .ready:
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.subjectsVC.status.noSubjects")
            default:
                tableView.backgroundView = nil
            }
            
        } else {
            
            tableView.backgroundView = nil
            
            switch status {
            case .logginIn:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.generic.status.loggingIn")
            case .fetching:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.subjectsVC.status.loading")
            case .offline:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.generic.status.offline")
            default:
                navigationItem.titleView = nil
            }
        }
    }
    
    func handleTabBarItemSelection(wasAlreadySelected: Bool) {
        return
    }
    
    func showMessages(forSubject subject: PTSubject) {
        
        let id = MessagesViewController.identifier
        
        if let childController = storyboard?.instantiateViewController(withIdentifier: id) as? MessagesViewController,
           let messages = dataOfSubjects[subject]?.messages {
            
            childController.configure(forSubject: subject, withMessages: messages)
            
            navigationController?.pushViewController(childController, animated: true)
        }
    }
    
    func showDocuments(forSubject subject: PTSubject) {
        
        let id = DocumentsViewController.identifier
        
        if let childController = storyboard?.instantiateViewController(withIdentifier: id) as? DocumentsViewController,
           let documents = dataOfSubjects[subject]?.documents {
            
            childController.configure(forSubject: subject, withDocuments: documents)
            
            navigationController?.pushViewController(childController, animated: true)
        }
    }
    
    func showInfo(forSubject subject: PTSubject) {
        
        let id = SubjectInfoViewController.identifier
        
        if let childController = storyboard?.instantiateViewController(withIdentifier: id) as? SubjectInfoViewController,
            let guide = dataOfSubjects[subject]?.guide {
            
            let info = dataOfSubjects[subject]?.info
            
            childController.configure(forSubject: subject, withGuide: guide, andInfo: info)
            
            navigationController?.pushViewController(childController, animated: true)
        }
    }
    
    func presentOptions(forSubject subject: PTSubject) {
        
        guard let data = dataOfSubjects[subject] else {
            // Still fetching data for this particular subject
            return
        }
        
        let alertController: UIAlertController
        
        if data.isValid {
            
            let nmessages = data.messages.count
            let ndocuments = data.numberOfFiles
            
            if nmessages > 0 || ndocuments > 0 || data.guide != nil {
                
                alertController = UIAlertController(title: subject.name, message: nil, preferredStyle: .actionSheet)
                
                if data.guide != nil {
                    
                    let documentsTitle = ~"ls.subjectsVC.subjectOptions.info"
                    alertController.addAction(UIAlertAction(title: documentsTitle, style: .default, handler: {
                        action in
                        self.showInfo(forSubject: subject)
                    }))
                }
                
                if nmessages > 0 {
                    let messagesTitle = ~"ls.subjectsVC.subjectOptions.messages"+" (\(nmessages))"
                    alertController.addAction(UIAlertAction(title: messagesTitle, style: .default, handler: {
                        action in
                        self.showMessages(forSubject: subject)
                    }))
                }
                
                if ndocuments > 0 {
                    
                    let documentsTitle = ~"ls.subjectsVC.subjectOptions.documents"+" (\(ndocuments))"
                    alertController.addAction(UIAlertAction(title: documentsTitle, style: .default, handler: {
                        action in
                        self.showDocuments(forSubject: subject)
                    }))
                }
                
                alertController.addAction(UIAlertAction(title: ~"ls.generic.alert.cancel", style: .cancel, handler: nil))
                
            } else {
                
                alertController = UIAlertController(title: ~"ls.generic.alert.error.title",
                                                    message: ~"ls.subjectsVC.noFilesOrMessagesAlert.body",
                                                    preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: ~"ls.generic.alert.dismiss", style: .default, handler: nil))
            }
            
        } else {
            // Data for this subject is invalid, which means parsing has failed
            
            alertController = UIAlertController(title: ~"ls.generic.alert.error.title",
                                                message: ~"ls.subjectsVC.invalidSubjectDataAlert.body",
                                                preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: ~"ls.generic.alert.dismiss", style: .default, handler: nil))
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
    
    
    // MARK: TableView delegate methods
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return PTSubjectCell.height
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return subjects.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        return tableView.dequeueReusableCell(withIdentifier: PTSubjectCell.identifier)!
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        guard let cell = cell as? PTSubjectCell else { return }
        
        let subject = subjects[indexPath.row]
        
        cell.configure(forSubject: subject)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let subject = subjects[indexPath.row]
        
        presentOptions(forSubject: subject)
    }
}


class PTSubjectCell: UITableViewCell {
    
    static let identifier = "PTSubjectCell_id"
    static let height = 70 as CGFloat
    
    @IBOutlet var mainLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    
    func configure(forSubject subject: PTSubject) {
        mainLabel.text = subject.name
        subtitleLabel.text = subject.inserimento+" - \(subject.credits) "+(~"ls.generic.credits")
    }
}
