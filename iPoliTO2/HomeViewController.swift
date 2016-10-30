//
//  HomeViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit
import MapKit


class HomeViewController: UITableViewController {

    var allRooms: [PTRoom] {
        return PTSession.shared.allRooms
    }
    
    var schedule: [PTLecture] = [] {
        didSet {
            recomputeScheduleByWeekday()
            tableView.reloadData()
            scrollToMostRelevantRow()
        }
    }
    
    var status: PTViewControllerStatus = .loggedOut {
        didSet {
            statusDidChange()
        }
    }
    
    // Mon = 0, Tue = 1, ...
    var scheduleByWeekday: [Int: [PTLecture]] = [:]
    
    var expandedIndexPath: IndexPath? = nil
    
    var cachedMapSnapshotsLandscape: [PTRoom: UIImage] = [:]
    var cachedMapSnapshotsPortrait: [PTRoom: UIImage] = [:]
    
    
    func cachedMapSnapshot(forRoom room: PTRoom) -> UIImage? {
        
        if UIApplication.shared.statusBarOrientation.isLandscape {
            return cachedMapSnapshotsLandscape[room]
        } else {
            return cachedMapSnapshotsPortrait[room]
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func statusDidChange() {
        
        let isTableEmpty = schedule.isEmpty
        
        if isTableEmpty {
            
            navigationItem.titleView = nil
            
            switch status {
            case .logginIn:
                tableView.backgroundView = PTLoadingTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.loggingIn")
            case .fetching:
                tableView.backgroundView = PTLoadingTableBackgroundView(frame: view.bounds, title: ~"ls.homeVC.status.loading")
            case .offline:
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.offline")
            case .error:
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.couldNotRetrieve")
            default:
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.homeVC.status.noLectures")
            }
            
        } else {
            
            tableView.backgroundView = nil
            
            switch status {
            case .logginIn:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.generic.status.loggingIn")
            case .fetching:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.homeVC.status.updating")
            case .offline:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.generic.status.offline")
            default:
                navigationItem.titleView = nil
            }
        }
    }
    
    func handleTabBarItemSelection(wasAlreadySelected: Bool) {
        if wasAlreadySelected {
            scrollToMostRelevantRow()
        }
    }
    
    func recomputeScheduleByWeekday() {
        
        let sortedSchedule = schedule.sorted { (lectureA, lectureB) -> Bool in
            
            return lectureA.date.compare(lectureB.date) == .orderedAscending
        }
        
        
        
        scheduleByWeekday.removeAll()
        
        for lecture in sortedSchedule {
            
            let date = lecture.date
            let weekday = italianWeekday(fromDate: date)
            var todaysSchedule = scheduleByWeekday[weekday] ?? []
            
            todaysSchedule.append(lecture)
            
            scheduleByWeekday[weekday] = todaysSchedule
        }
        
        
    }
    
    // Required to unwind from settings programmatically
    @IBAction func unwindFromSettings(_ segue: UIStoryboardSegue) {}
    
    
    
    // MARK: -
    
    /// Scrolls to the top of the table
    func scrollToFirstRow() {
        let indexPath = IndexPath(row: 0, section: 0)
        self.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
    }
    
    /// Scrolls to the current lecture if possible, otherwise scrolls to the next lecture.
    func scrollToMostRelevantRow() {
        
        let now = Date()
        let weekday = italianWeekday(fromDate: now)
        
        if weekday > 4 {
            // It's the weekend!
            scrollToFirstRow()
            return
        }
        
        var relevantLecture: PTLecture? = nil
        
        if let lecture = currentLecture() {
            relevantLecture = lecture
        } else if let lecture = nextLecture() {
            relevantLecture = lecture
        }
        
        if let relevantLecture = relevantLecture,
            let indexPath = indexPath(ofLecture: relevantLecture) {
            
            tableView.scrollToRow(at: indexPath, at: .top, animated: true)
            
        } else {
            scrollToFirstRow()
        }
    }
    
    /// Returns the current lecture, if any, otherwise nil
    func currentLecture() -> PTLecture? {
        
        let now = Date()
        let weekday = italianWeekday(fromDate: now)
        if weekday > 4 {
            // It's the weekend!
            return nil
        }
        
        let todaysSchedule = scheduleByWeekday[weekday] ?? []
        
        for lecture in todaysSchedule {
            
            let interval = now.timeIntervalSince(lecture.date)
            if interval < 0 {
                continue
            } else if interval < lecture.length {
                return lecture
            }
        }
        return nil
    }
    
    /// Returns the next lecture, if any, otherwise nil
    func nextLecture() -> PTLecture? {
        
        let now = Date()
        let weekday = italianWeekday(fromDate: now)
        if weekday > 4 {
            // It's the weekend!
            return nil
        }
        
        for i in weekday...4 {
            
            let todaysSchedule = scheduleByWeekday[i] ?? []
            
            for lecture in todaysSchedule {
                
                let interval = now.timeIntervalSince(lecture.date)
                if interval > lecture.length {
                    return lecture
                }
            }
        }
        
        return nil
    }
    
    /// Returns the IndexPath of the specified lecture, if found in the table, otherwise nil
    func indexPath(ofLecture lecture: PTLecture) -> IndexPath? {
        
        for s in 0...4 {
            
            let todaysSchedule = scheduleByWeekday[s] ?? []
            
            for r in 0..<todaysSchedule.count {
                
                if lecture == todaysSchedule[r] {
                    return IndexPath(row: r, section: s)
                }
            }
        }
        
        return nil
    }
    
    
    
    // MARK: TableView Methods
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // Seven days in a week
        return 7
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        let todaysSchedule = scheduleByWeekday[section] ?? []
        return todaysSchedule.isEmpty ? 0 : (28+5)
    }
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let todaysSchedule = scheduleByWeekday[section] ?? []
        if todaysSchedule.isEmpty {
            return nil
        }
        guard let today = todaysSchedule.first?.date else {
            return nil
        }
        
        let formatter = DateFormatter()
        // formatter.timeZone = TimeZone.Turin
        formatter.timeStyle = .none
        formatter.dateStyle = .full
        formatter.doesRelativeDateFormatting = true
        
        let title = formatter.string(from: today).capitalized
        
        
        let bottomSpacing: CGFloat = 5
        let labelHeight: CGFloat = 28
        
        let totalHeight = bottomSpacing + labelHeight
        let tableWidth = tableView.frame.width
        
        let container = UIView(frame: CGRect(x: 0, y: 0, width: tableWidth, height: totalHeight))
        
        let label = UILabel(frame: CGRect(x: 16, y: 0, width: tableWidth-16, height: labelHeight))
        label.text = title
        label.font = UIFont.systemFont(ofSize: 17, weight: UIFontWeightSemibold)
        label.backgroundColor = UIColor.clear
        
        let cal = Calendar.current
        // cal.timeZone = TimeZone.Turin
        
        label.textColor = cal.isDateInToday(today) ? UIColor.black : UIColor.gray
        
        let labelBackgroundView = UIView(frame: CGRect(x: 0, y: 0, width: tableWidth, height: labelHeight))
        labelBackgroundView.backgroundColor = #colorLiteral(red: 0.968627451, green: 0.968627451, blue: 0.968627451, alpha: 1)
        
        let space = UIView(frame: CGRect(x: 0, y: labelHeight, width: tableWidth, height: bottomSpacing))
        space.backgroundColor = UIColor.clear
        
        container.addSubview(labelBackgroundView)
        container.addSubview(label)
        container.addSubview(space)
        
        return container
    }
 
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let todaysSchedule = scheduleByWeekday[section] ?? []
        
        // Empty day => No section => No footer for that section (i.e. footer of 0 height)
        return todaysSchedule.isEmpty ? 0 : 5
    }
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = UIColor.clear
        return v
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let todaysSchedule = scheduleByWeekday[section] ?? []
        return todaysSchedule.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if expandedIndexPath == indexPath {
            return PTLectureView.expandedHeight
        } else {
            return PTLectureView.height
        }
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        return CRRoundedCell(indexPath: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        // Prevents selection
        return nil
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        guard let cell = cell as? CRRoundedCell else {
            return
        }
        
        cell.selectionHandler = handleRoundedCellSelection
        
        let nibViews = Bundle.main.loadNibNamed("PTLectureView", owner: self, options: nil)
        
        guard let lectureView = nibViews?.filter( { $0 is PTLectureView }).first as? PTLectureView else {
            return
        }
        
        let todaysSchedule = scheduleByWeekday[indexPath.section] ?? []
        
        let lecture = todaysSchedule[indexPath.row]
        
        lectureView.lecture = lecture
        lectureView.mapSelectionHandler = handleLectureMapSelection
        
        lectureView.expanded = (expandedIndexPath == indexPath)
        lectureView.activityIndicator.stopAnimating()
        
        if let roomName = lecture.roomName {
            
            let room = roomAnswearingName(roomName)
            lectureView.room = room
            
            if let room = room, lectureView.expanded {
                
                if let snapshot = cachedMapSnapshot(forRoom: room) {

                    lectureView.activityIndicator.stopAnimating()
                    lectureView.mapSnapshotView.image = snapshot
                } else {
                    
                    lectureView.activityIndicator.startAnimating()
                    lectureView.mapSnapshotView.image = nil
                    let snapshotSize = estimateSnapshotSize()
                    reloadMapSnapshot(forRoom: room, size: snapshotSize, indexPath: indexPath)
                }
            }
        }
        
        cell.childView = lectureView
    }
    
    func estimateSnapshotSize() -> CGSize {
        
        let snapshotHeight = PTLectureView.snapshotHeight
        
        let tableWidth = tableView.frame.width
        let cellMargins = CRRoundedCell.defaultHorizontalMarginsWidth
        let cellWidth = tableWidth - cellMargins
        
        return CGSize(width: cellWidth, height: snapshotHeight)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        tableView.reloadData()
    }
    
    func handleRoundedCellSelection(_ cell: CRRoundedCell, _ indexPath: IndexPath) {
        
        guard let lectureView = cell.childView as? PTLectureView else {
            return
        }
        
        // Checks if the selected row can be expanded
        if lectureView.canExpand() {
            
            var indexPathsToReload = [indexPath]
            
            // Checks if the selected row is not already expanded
            if expandedIndexPath != indexPath {
                
                // Compresses the currently expanded cell if it exists
                if expandedIndexPath != nil {
                    indexPathsToReload.append(expandedIndexPath!)
                }
                
                expandedIndexPath = indexPath
                
            } else {
                
                // Cell was already expanded => Compresses
                expandedIndexPath = nil
            }
            
            tableView.reloadRows(at: indexPathsToReload, with: .fade)
            
        } else {
            
            // Cell cannot be expanded (i.e. map is not available for this room)
            
            // Compresses the currently expanded cell if it exists
            if let currentlyExpandedIndexPath = expandedIndexPath {
                
                self.expandedIndexPath = nil
                tableView.reloadRows(at: [currentlyExpandedIndexPath], with: .fade)
                
            }
            
            showMapNotAvailableAlert()
        }
    }
    
    func handleLectureMapSelection(room: PTRoom) {
        showRoomInMapViewController(room: room)
    }
    
    
    
    // MARK: Map Methods
    
    func reloadMapSnapshot(forRoom room: PTRoom, size: CGSize, indexPath: IndexPath) {
        
        let coordinates = CLLocationCoordinate2D(latitude: room.latitude, longitude: room.longitude)
        
        let isLandscape = UIApplication.shared.statusBarOrientation.isLandscape
        
        let span = MKCoordinateSpan(latitudeDelta: 0.00125, longitudeDelta: 0.00125)
        let region = MKCoordinateRegion(center: coordinates, span: span)
        
        let options = MKMapSnapshotOptions()
        
        options.size = size
        options.mapType = .standard
        options.region = region
        options.showsBuildings = true
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        snapshotter.start(completionHandler: {
            (snapshot: MKMapSnapshot?, error: Error?) in
            
            if let snapshot = snapshot {
                
                let pin = MKPinAnnotationView(annotation: nil, reuseIdentifier: "")
                pin.pinTintColor = #colorLiteral(red: 0.8949507475, green: 0.1438436359, blue: 0.08480125666, alpha: 1)
                
                var point = snapshot.point(for: coordinates)
                
                point.x -= pin.bounds.width / 2.0
                point.y -= pin.bounds.height / 2.0
                point.x += pin.centerOffset.x
                point.y += pin.centerOffset.y
                
                let image = snapshot.image
                let pinImage = pin.image
                
                UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
                
                image.draw(at: CGPoint.zero)
                pinImage?.draw(at: point)
                
                let finalImage = UIGraphicsGetImageFromCurrentImageContext()
                
                UIGraphicsEndImageContext()
                
                
                if isLandscape {
                    self.cachedMapSnapshotsLandscape[room] = finalImage
                } else {
                    self.cachedMapSnapshotsPortrait[room] = finalImage
                }
                
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        })
    }
    
    func showMapNotAvailableAlert() {
        
        let alert = UIAlertController(title: ~"ls.generic.alert.error.title", message: ~"ls.homeVC.noMapAlert.body", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: ~"ls.generic.alert.dismiss", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func showRoomInMapViewController(room: PTRoom) {
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        
        appDelegate.showMapViewController(withHighlightedRoom: room)
    }
    
    
    
    // MARK: Utilities
    
    func roomAnswearingName(_ roomName: String) -> PTRoom? {
        
        let queryComps = roomName.lowercased().components(separatedBy: " ")
        
        for room in allRooms {
            
            let thisComps = room.localizedName.lowercased().components(separatedBy: " ")
            
            var found = true
            
            for comp in queryComps {
                
                if !(thisComps.contains(comp)) {
                    found = false
                    break
                }
            }
            
            if found {
                return room
            }
        }
        return nil
    }
}

