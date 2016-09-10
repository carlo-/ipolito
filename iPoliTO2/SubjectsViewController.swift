//
//  SubjectsViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

class SubjectsViewController: UITableViewController {
    
    var content: [PTSubject] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }
    var dataOfSubjects: [PTSubject: PTSubjectData] = [:] {
        didSet {
            self.tableView.reloadData()
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
    
    func presentOptions(forSubject subject: PTSubject, withData data: PTSubjectData?) {
        
        let alertController: UIAlertController
        
        if let data = data {
            
            let nmessages = data.messages.count
            let ndocuments = data.numberOfFiles
            
            if nmessages > 0 || ndocuments > 0 {
                
                alertController = UIAlertController(title: subject.name, message: nil, preferredStyle: .actionSheet)
                
                if nmessages > 0 {
                    let messagesTitle = ~"Messages"+" (\(nmessages))"
                    alertController.addAction(UIAlertAction(title: messagesTitle, style: .default, handler: {
                        action in
                        self.showMessages(forSubject: subject)
                    }))
                }
                
                if ndocuments > 0 {
                    
                    let documentsTitle = ~"Documents"+" (\(ndocuments))"
                    alertController.addAction(UIAlertAction(title: documentsTitle, style: .default, handler: {
                        action in
                        self.showDocuments(forSubject: subject)
                    }))
                }
                
                alertController.addAction(UIAlertAction(title: ~"Cancel", style: .cancel, handler: nil))
                
            } else {
                
                alertController = UIAlertController(title: ~"Oops!",
                                                    message: ~"This course doesn't have any messages or files",
                                                    preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: ~"Dismiss", style: .default, handler: nil))
            }
            
        } else {
            // data is nil, which means it's still loading
            return
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
    
    
    // MARK: TableView delegate methods
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return PTSubjectCell.height
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if content.isEmpty {
            tableView.backgroundView = EmptyCourseLoadBackgroundView(frame: tableView.bounds)
        } else {
            tableView.backgroundView = nil
        }
        
        return content.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        return tableView.dequeueReusableCell(withIdentifier: PTSubjectCell.identifier)!
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        guard let cell = cell as? PTSubjectCell else { return }
        
        let subject = content[indexPath.row]
        
        cell.configure(forSubject: subject)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let subject = content[indexPath.row]
        
        presentOptions(forSubject: subject, withData: dataOfSubjects[subject])
    }
}


class PTSubjectCell: UITableViewCell {
    
    static let identifier = "PTSubjectCell_id"
    static let height = 70 as CGFloat
    
    @IBOutlet var mainLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    
    func configure(forSubject subject: PTSubject) {
        mainLabel.text = subject.name
        subtitleLabel.text = subject.inserimento+" - \(subject.credits) "+(~"ECTS")
    }
}


fileprivate class EmptyCourseLoadBackgroundView: UIView {
    
    private let label: UILabel
    
    override init(frame: CGRect) {
        
        label = UILabel()
        
        super.init(frame: frame)
        
        backgroundColor = UIColor.clear
        
        label.font = UIFont.systemFont(ofSize: 15.0)
        label.textColor = UIColor.lightGray
        label.text = ~"No subjects on your course load!"
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
