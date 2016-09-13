//
//  MessagesViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 09/09/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

class MessagesViewController: UITableViewController {
    
    static let identifier = "MessagesViewController_id"
    
    private var content: [PTMessageCell.PrecomputedPTMessage] = []
    private var subject: PTSubject!
    
    func configure(forSubject subject: PTSubject, withMessages messages: [PTMessage]) {
        
        self.title = subject.name
        self.subject = subject
        precomputeMessages(messages)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Removes annoying row separators after the last cell
        tableView.tableFooterView = UIView()
    }
    
    func precomputeMessages(_ messages: [PTMessage]) {
        
        OperationQueue().addOperation({
            
            for message in messages {
                
                let precompMessage = PTMessageCell.PrecomputedPTMessage(message: message)
                self.content.append(precompMessage)
            }
            
            OperationQueue.main.addOperation {
                
                self.tableView.reloadData()
            }
        })
    }
    
    
    
    // MARK: TableView delegate methods
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        let precompMessage = content[indexPath.row]
        
        return PTMessageCell.estimatedHeight(messageBody: precompMessage.body, rowWidth: tableView.frame.width)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if content.isEmpty {
            tableView.backgroundView = PTLoadingTableBackgroundView(frame: tableView.bounds)
        } else {
            tableView.backgroundView = nil
        }
            
        return content.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        return tableView.dequeueReusableCell(withIdentifier: PTMessageCell.identifier)!
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        guard let cell = cell as? PTMessageCell else { return }
        
        let precompMessage = content[indexPath.row]
        
        cell.configure(forPrecomputedMessage: precompMessage)
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return nil
    }
}


class PTMessageCell: UITableViewCell {
    
    static let identifier = "PTMessageCell_id"
    
    struct PrecomputedPTMessage {
        
        let originalMessage: PTMessage
        let body: String
        let dateString: String
        
        init(message: PTMessage) {
            
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeZone = TimeZone.Turin
            
            self.originalMessage = message
            self.body = message.cleanBody
            self.dateString = formatter.string(from: message.date)
        }
    }
    
    class func estimatedHeight(messageBody: String, rowWidth: CGFloat) -> CGFloat {
        
        let minimumHeight: CGFloat = 27.0
        let textViewWidth = rowWidth-16.0
        
        let textView = UITextView()
        textView.text = messageBody
        textView.font = UIFont.systemFont(ofSize: 13)
        
        let textViewSize = textView.sizeThatFits(CGSize(width: textViewWidth, height: CGFloat.greatestFiniteMagnitude))
        
        return minimumHeight + textViewSize.height + 8.0
    }
    
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var bodyTextView: UITextView!
    
    func configure(forMessage message: PTMessage) {
        
        let precomp = PrecomputedPTMessage(message: message)
        configure(forPrecomputedMessage: precomp)
    }
    
    func configure(forPrecomputedMessage precompMessage: PrecomputedPTMessage) {
        
        dateLabel.text = precompMessage.dateString
        bodyTextView.text = precompMessage.body
        
        repositionSubviews()
    }
    
    private func repositionSubviews() {
        
        let rowWidth = frame.width
        
        let textViewWidth = rowWidth-16.0
        
        dateLabel.sizeToFit()
        dateLabel.frame.origin = CGPoint(x: 13.0, y: 8.0)
        
        let textViewSize = bodyTextView.sizeThatFits(CGSize(width: textViewWidth, height: CGFloat.greatestFiniteMagnitude))
        
        bodyTextView.frame.size = textViewSize
        bodyTextView.frame.origin = CGPoint(x: 8.0, y: 27)
    }
}
