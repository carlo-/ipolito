//
//  SubjectInfoViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 29/09/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit


class SubjectInfoViewController: UIViewController {
    
    static let identifier = "SubjectInfoViewController_id"

    private var subjectGuide: PTSubjectData.Guide!
    private var subjectInfo: PTSubjectData.Info?
    
    @IBOutlet var lecturerLabel: UILabel!
    @IBOutlet var academicYearLabel: UILabel!
    @IBOutlet var guideView: UITextView!
    
    func configure(forSubject subject: PTSubject, withGuide guide:PTSubjectData.Guide, andInfo info: PTSubjectData.Info?) {
        
        self.title = subject.name
        self.subjectGuide = guide
        self.subjectInfo = info
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guideView.attributedText = attributedString(forGuide: subjectGuide)
        lecturerLabel.text = subjectInfo?.lecturer.fullName.capitalized ?? "??"
        
        if let year = subjectInfo?.year {
            
            if let term = subjectInfo?.term?.localizedDescription {
                academicYearLabel.text = year + " (\(term))"
            } else {
                academicYearLabel.text = year
            }
        } else {
            academicYearLabel.text = "??"
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guideView.setContentOffset(CGPoint.zero, animated: false)
    }
    
    func attributedString(forGuide guide: PTSubjectData.Guide) -> NSAttributedString {
        
        let titleAttributes = [NSFontAttributeName: UIFont.systemFont(ofSize: 17.0),
                               NSForegroundColorAttributeName: UIColor.iPoliTO.darkGray]
        
        let bodyAttributes = [NSFontAttributeName: UIFont.systemFont(ofSize: 12.0),
                              NSForegroundColorAttributeName: UIColor.lightGray]
        
        let attributedString = NSMutableAttributedString()
        
        var first = true
        for entry in guide.entries {
            
            if !first {
                attributedString.append(NSAttributedString(string: "\n\n\n"))
            }
            
            let char: Character = "\u{0C}"
            let cleanBody = entry.body.replacingOccurrences(of: String(char), with: "")
            
            let titleStr = NSAttributedString(string: entry.title+"\n", attributes: titleAttributes)
            let bodyStr = NSAttributedString(string: "\n"+cleanBody, attributes: bodyAttributes)
            
            attributedString.append(titleStr)
            attributedString.append(bodyStr)
            
            first = false
        }
        
        return attributedString
    }
}
