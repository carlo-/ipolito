//
//  PTSubjectsCells.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

// TODO: Rename this file to something more appropriate!

class PTSubjectCell: UITableViewCell {
    
    static let identifier = "PTSubjectCell_id"
    static let height = 70 as CGFloat
    static let expandedHeight = 120 as CGFloat
    
    @IBOutlet var mainLabel: UILabel!
    @IBOutlet var creditsLabel: UILabel!
    @IBOutlet var messagesButton: UIButton!
    @IBOutlet var documentsButton: UIButton!
    
    private func setMessagesBadge(badge: String) {
        
        let title = ~"Messages"+" (\(badge))"
        
        messagesButton.setTitle(title, for: UIControlState())
    }
    
    private func setDocumentsBadge(badge: String) {
        
        let title = ~"Documents"+" (\(badge))"
        
        documentsButton.setTitle(title, for: UIControlState())
    }
    
    func setSubject(_ subject: PTSubject, andData data: PTSubjectData?) {
        
        var nmessages: Int = 0
        var ndocuments: Int = 0
        
        if let data = data {
            
            nmessages = data.messages.count
            ndocuments = data.numberOfFiles
        }
        
        setMessagesBadge(badge: "\(nmessages)")
        setDocumentsBadge(badge: "\(ndocuments)")
        
        messagesButton.isEnabled = nmessages > 0
        documentsButton.isEnabled = ndocuments > 0
        
        mainLabel.text = subject.name
        creditsLabel.text = "\(subject.credits)"
    }
}

class PTFolderCell: UITableViewCell {
    
    static let identifier = "PTFolderCell_id"
    static let height = 70 as CGFloat
    
    @IBOutlet var mainLabel: UILabel!
    @IBOutlet var iconView: UIImageView!
    
    func setFolder(folder: PTMFolder) {
        
        mainLabel.text = folder.description
    }
}

class PTFileCell: UITableViewCell {
    
    static let identifier = "PTFileCell_id"
    static let height = 70 as CGFloat
    
    @IBOutlet var mainLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet var iconView: UIImageView!
    
    func setFile(file: PTMFile) {
        
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

class PTMessageCell: UITableViewCell {
    
    static let identifier = "PTMessageCell_id"
    
    class func estimatedHeight(message: PTMessage, rowWidth: CGFloat) -> CGFloat {
        
        let minimumHeight: CGFloat = 42.0
        let textViewWidth = rowWidth-16.0
        
        let bodyText = message.plainBody
        
        let textView = UITextView()
        textView.text = bodyText
        textView.font = UIFont.systemFont(ofSize: 13)
        
        let textViewSize = textView.sizeThatFits(CGSize(width: textViewWidth, height: CGFloat.greatestFiniteMagnitude))
        
        return minimumHeight + textViewSize.height + 8.0
    }
    
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var bodyTextView: UITextView!
    
    func setMessage(message: PTMessage) {
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = TimeZone.Turin
        
        dateLabel.text = formatter.string(from: message.date)
        bodyTextView.text = message.plainBody
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        selectionStyle = .none
    }
}
