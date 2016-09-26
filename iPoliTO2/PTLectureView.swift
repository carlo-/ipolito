//
//  PTLectureView.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 25/08/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit
import MapKit

class PTLectureView: UIView {
    
    @IBOutlet var subjectLabel: UILabel!
    @IBOutlet var lecturerLabel: UILabel!
    @IBOutlet var timeLabel: UILabel!
    @IBOutlet var roomLabel: UILabel!
    @IBOutlet var detailsLabel: UILabel!
    @IBOutlet var mapSnapshotView: UIImageView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    static let height: CGFloat = 80
    static let expandedHeight: CGFloat = 222
    static let snapshotHeight: CGFloat = 155
    
    var room: PTRoom?
    var lecture: PTLecture? {
        didSet {
            if let lecture = lecture {
                subjectLabel.text = lecture.subjectName
                lecturerLabel.text = lecture.lecturerName?.capitalized
                timeLabel.text = getNiceTimeIntervalString(fromLecture: lecture)
                roomLabel.text = lecture.roomName
                detailsLabel.text = lecture.cohortDesctiption
            }
        }
    }
    
    var expanded: Bool = false
    
    var mapSelectionHandler: ((_ room: PTRoom) -> Void)?
    
    private func getNiceTimeIntervalString(fromLecture lecture:PTLecture) -> String {
        
        let begDate = lecture.date
        let endDate = lecture.date.addingTimeInterval(lecture.length)
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.Turin
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        // formatter.locale = Locale(identifier: "it-IT")
        
        return formatter.string(from: begDate) + "~" + formatter.string(from: endDate)
    }
    
    override func draw(_ rect: CGRect) {
        
        let gestureRecog = UITapGestureRecognizer(target: self, action: #selector(mapSnapshotViewPressed))
        
        gestureRecog.numberOfTapsRequired = 1
        gestureRecog.numberOfTouchesRequired = 1
        
        mapSnapshotView.isUserInteractionEnabled = true
        mapSnapshotView.addGestureRecognizer(gestureRecog)
        
        mapSnapshotView.isHidden = !expanded
        
        if expanded {
            
            if !canExpand() {
                expanded = false
                return
            }
        }
    }
    
    func mapSnapshotViewPressed(_ gestureRecognizer: UIGestureRecognizer) {
        
        if let room = room {
            mapSelectionHandler?(room)
        }
    }
    
    func canExpand() -> Bool {
        return room != nil
    }
    
}
