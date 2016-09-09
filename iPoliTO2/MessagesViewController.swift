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
    
    private var content: [PTMessage] = []
    private var subject: PTSubject!
    
    func configure(forSubject subject: PTSubject, withMessages messages: [PTMessage]) {
        
        self.title = subject.name
        self.subject = subject
        self.content = messages
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Removes annoying row separators after the last cell
        tableView.tableFooterView = UIView()
    }
    
    
    
    // MARK: TableView delegate methods
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        let message = content[indexPath.row]
        
        return PTMessageCell.estimatedHeight(message: message, rowWidth: tableView.frame.width)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
        
        let message = content[indexPath.row]
        
        cell.configure(forMessage: message)
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return nil
    }
}


class PTMessageCell: UITableViewCell {
    
    static let identifier = "PTMessageCell_id"
    
    class func estimatedHeight(message: PTMessage, rowWidth: CGFloat) -> CGFloat {
        
        let minimumHeight: CGFloat = 27.0
        let textViewWidth = rowWidth-16.0
        
        let bodyText = message.cleanBody
        
        let textView = UITextView()
        textView.text = bodyText
        textView.font = UIFont.systemFont(ofSize: 13)
        
        let textViewSize = textView.sizeThatFits(CGSize(width: textViewWidth, height: CGFloat.greatestFiniteMagnitude))
        
        return minimumHeight + textViewSize.height + 8.0
    }
    
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var bodyTextView: UITextView!
    
    func configure(forMessage message: PTMessage) {
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = TimeZone.Turin
        
        dateLabel.text = formatter.string(from: message.date)
        bodyTextView.text = message.cleanBody
        
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
