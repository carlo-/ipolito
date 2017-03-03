//
//  VideolecturesViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 03/03/2017.
//  Copyright © 2017 crapisarda. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class VideolecturesViewController: UITableViewController {
    
    static let identifier = "VideolecturesViewController_id"
    
    fileprivate var videolectures: [PTVideolecture] = []
    
    func configure(forSubject subject: PTSubject, andVideolectures videolectures: [PTVideolecture]) {
        
        self.title = subject.name
        self.videolectures = videolectures
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Removes annoying row separators after the last cell
        tableView.tableFooterView = UIView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        tableView.reloadData()
    }
}

extension VideolecturesViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return videolectures.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: PTVideolectureCell.identifier, for: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let videolecture = videolectures[indexPath.row]
        let cell = cell as! PTVideolectureCell
        cell.configure(for: videolecture)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let videolecture = videolectures[indexPath.row]
        presentPlayer(withVideolecture: videolecture)
    }
}

extension VideolecturesViewController {

    private func updatePlayerPosition(_ position: CMTime, forVideolecture videolecture: PTVideolecture) {
        videolecture.rememberPosition(position)
    }
    
    private func updateVideoDurationIfNeeded(_ duration: CMTime, forVideolecture videolecture: PTVideolecture) {
        
        if videolecture.duration == nil, duration.isValid, duration.isNumeric {
            videolecture.rememberDuration(duration)
        }
    }
    
    func presentPlayer(withVideolecture videolecture: PTVideolecture) {
        
        let player = AVPlayer(url: videolecture.videoURL)
        player.actionAtItemEnd = .pause
        
        let playerController = AVPlayerViewController()
        playerController.player = player
        
        let updateInterval = CMTime(seconds: 1, preferredTimescale: 1)
        
        player.addPeriodicTimeObserver(forInterval: updateInterval, queue: .main, using: { [weak self]
            time in
            
            guard let currentItem = player.currentItem else { return; }
            
            if currentItem.asset.isPlayable {
                
                self?.updatePlayerPosition(time, forVideolecture: videolecture)
                self?.updateVideoDurationIfNeeded(currentItem.duration, forVideolecture: videolecture)
            }
        })
        
        let previousPosition = videolecture.lastPositionPlayed
        
        present(playerController, animated: true, completion: {
            player.play()
            player.seek(to: previousPosition)
        })
    }
}

class PTVideolectureCell: UITableViewCell {
    
    static let identifier = "PTVideolectureCell_id"
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var progressLabel: UILabel!
    
    func configure(for videolecture: PTVideolecture) {
        
        self.titleLabel.text = videolecture.title
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        self.dateLabel.text = formatter.string(from: videolecture.date)
        
        if let duration_s = videolecture.duration?.seconds, duration_s > 0 {
            
            let position_s = videolecture.lastPositionPlayed.seconds
            
            let progress = 100 * position_s / duration_s
            
            self.progressLabel.text = "\(Int(progress))%"
            
        } else {
            self.progressLabel.text = nil
        }
    }
}
