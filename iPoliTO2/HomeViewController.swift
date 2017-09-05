//
//  HomeViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit
import MapKit


class PTLectureCell: CRTableViewCell {
    
    static let identifier = "PTLectureCell_id"
    
    @IBOutlet private var myChildView: UIView? {
        didSet { childView = myChildView }
    }
    
    @IBOutlet private weak var subjectLabel: UILabel!
    @IBOutlet private weak var lecturerLabel: UILabel!
    @IBOutlet private weak var timeLabel: UILabel!
    @IBOutlet private weak var roomLabel: UILabel!
    @IBOutlet private weak var detailsLabel: UILabel!
    @IBOutlet private weak var mapSnapshotView: UIImageView!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    
    static let height: CGFloat = 80
    static let expandedHeight: CGFloat = 222
    static let snapshotHeight: CGFloat = 155
    static let horizontalMarginsWidth: CGFloat = 18
    
    var isExpanded: Bool = false
    
    var indexPath: IndexPath!
    
    var mapSelectionHandler: ((IndexPath) -> Void)?
    
    var lecture: PTLecture! {
        didSet { configure(forLecture: lecture) }
    }
    
    
    override func draw(_ rect: CGRect) {
        
        if (mapSnapshotView.gestureRecognizers ?? []).isEmpty == true {
            
            let gestureRecog = UITapGestureRecognizer(target: self, action: #selector(mapSnapshotViewPressed))
            
            gestureRecog.numberOfTapsRequired = 1
            gestureRecog.numberOfTouchesRequired = 1
            
            mapSnapshotView.isUserInteractionEnabled = true
            mapSnapshotView.addGestureRecognizer(gestureRecog)
        }
        
        mapSnapshotView.isHidden = !isExpanded
        
        cornerRadius = 14
        borderWidth = 0.5
        borderColor = UIColor(red:0.47, green:0.47, blue:0.47, alpha:0.5).cgColor
        
        super.draw(rect)
    }
    
    
    func configure(forLecture lecture: PTLecture) {
        
        subjectLabel.text = lecture.subjectName
        lecturerLabel.text = lecture.lecturerName?.capitalized
        timeLabel.text = getNiceTimeIntervalString(fromLecture: lecture)
        roomLabel.text = lecture.roomName
        
        var details: [String] = []
        
        if let cohort = lecture.cohortDesctiption {
            details.append(cohort)
        }
        
        if let descr = lecture.eventDescription {
            details.append(descr)
        }
        
        detailsLabel.text = details.joined(separator: " | ")
    }
    
    
    func startLoadingIndicator() {
        activityIndicator.startAnimating()
    }
    
    func stopLoadingIndicator() {
        activityIndicator.stopAnimating()
    }
    
    func setMapSnapshot(_ snapshot: UIImage?) {
        mapSnapshotView.image = snapshot
    }
    
    
    func mapSnapshotViewPressed(_ gestureRecognizer: UIGestureRecognizer) {
        mapSelectionHandler?(indexPath)
    }
    
    
    private func getNiceTimeIntervalString(fromLecture lecture:PTLecture) -> String {
        
        let begDate = lecture.date
        let endDate = lecture.date.addingTimeInterval(lecture.length)
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.Turin
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        return formatter.string(from: begDate) + "~" + formatter.string(from: endDate)
    }
}



// MARK: - PTSchedule & PTScheduleDay

private enum PTScheduleDay: Int {
    
    case monday = 0, tuesday, wednesday, thursday, friday
    
    static var allValues: [PTScheduleDay] = [.monday, .tuesday, .wednesday, .thursday, .friday]
    
    init?(fromDate date: Date) {
        
        let dayIndex = italianWeekday(fromDate: date)
        
        if let day = PTScheduleDay(rawValue: dayIndex) {
            self = day
        } else {
            return nil
        }
    }
}

private struct PTSchedule {
    
    private let scheduleByDay: [PTScheduleDay: [PTLecture]]
    
    let count: Int
    
    var isEmpty: Bool { return count < 1 }
    
    init(withLectures lectures: [PTLecture]) {
        
        let sortedLectures = lectures.sorted(by: { $0.date < $1.date })
        
        var _scheduleByDay: [PTScheduleDay: [PTLecture]] = [:]
        
        PTScheduleDay.allValues.forEach({ _scheduleByDay[$0] = [] })
        
        for lecture in sortedLectures {
            
            guard let day = PTScheduleDay(fromDate: lecture.date) else { continue; }
            
            var todaysSchedule = _scheduleByDay[day]!
            
            todaysSchedule.append(lecture)
            
            _scheduleByDay[day] = todaysSchedule
        }
        
        self.count = lectures.count
        self.scheduleByDay = _scheduleByDay
    }
    
    static var empty: PTSchedule {
        return PTSchedule(withLectures: [])
    }
    
    func lectures(on day: PTScheduleDay) -> [PTLecture] {
        return scheduleByDay[day]!
    }
    
    /// Mon = 0, Tue = 1, ...
    func lectures(on dayIndex: Int) -> [PTLecture]? {
        
        guard let day = PTScheduleDay(rawValue: dayIndex) else {
            return nil
        }
        
        return lectures(on: day)
    }
}



// MARK: - HomeViewController

class HomeViewController: UITableViewController {

    var allRooms: [PTRoom] {
        return PTSession.shared.allRooms
    }
    
    var allLectures: [PTLecture] = [] {
        didSet { lecturesDidChange() }
    }
    
    var status: PTViewControllerStatus = .loggedOut {
        didSet { statusDidChange() }
    }
    
    fileprivate var schedule: PTSchedule = PTSchedule.empty
    
    fileprivate var expandedIndexPath: IndexPath? = nil
    
    fileprivate let mapSnapshotCache = PTMapSnapshotCache()
    
    
    func statusDidChange() {
        
        if status != .fetching && status != .logginIn {
            refreshControl?.endRefreshing()
        }
        
        let isTableEmpty = allLectures.isEmpty
        
        if isTableEmpty {
            
            tableView.isScrollEnabled = false
            navigationItem.titleView = nil
            
            let refreshButton = UIButton(type: .system)
            refreshButton.addTarget(self, action: #selector(refreshButtonPressed), for: .touchUpInside)
            
            switch status {
                
            case .logginIn:
                tableView.backgroundView = PTLoadingTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.loggingIn")
                
            case .fetching:
                tableView.backgroundView = PTLoadingTableBackgroundView(frame: view.bounds, title: ~"ls.homeVC.status.loading")
                
            case .offline:
                refreshButton.setTitle(~"ls.generic.alert.retry", for: .normal)
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.offline", button: refreshButton)
                
            case .error:
                refreshButton.setTitle(~"ls.generic.alert.retry", for: .normal)
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.couldNotRetrieve", button: refreshButton)
                
            default:
                refreshButton.setTitle(~"ls.generic.refresh", for: .normal)
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.homeVC.status.noLectures", button: refreshButton)
                navigationItem.titleView = PTSession.shared.lastUpdateTitleView(title: ~"ls.homeVC.title")
            }
            
        } else {
            
            tableView.isScrollEnabled = true
            tableView.backgroundView = nil
            
            switch status {
            case .logginIn:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.generic.status.loggingIn")
            case .fetching:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.homeVC.status.updating")
            case .offline:
                navigationItem.titleView = PTSession.shared.lastUpdateTitleView(title: ~"ls.generic.status.offline")
            default:
                navigationItem.titleView = PTSession.shared.lastUpdateTitleView(title: ~"ls.homeVC.title")
            }
        }
    }
    
    func lecturesDidChange() {
        
        OperationQueue().addOperation { [unowned self] _ in
            
            self.reloadSchedule()
            
            OperationQueue.main.addOperation {
                
                self.tableView.reloadData()
                self.scrollToMostRelevantRow()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 11.0, *) {
            // Disable use of 'large title' display mode
            navigationItem.largeTitleDisplayMode = .never
        }
        
        setupRefreshControl()
        
        // TODO: Consider running this on a separate thread
        mapSnapshotCache.importFromDisk()
    }
    
    func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refreshControlActuated), for: .valueChanged)
    }
    
    @objc
    func refreshControlActuated() {
        if PTSession.shared.isBusy {
            refreshControl?.endRefreshing()
        } else {
            (UIApplication.shared.delegate as! AppDelegate).login()
        }
    }
    
    @objc
    func refreshButtonPressed() {
        (UIApplication.shared.delegate as! AppDelegate).login()
    }
}



// MARK: TableView Methods

extension HomeViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return PTScheduleDay.allValues.count
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        let todaysLectures = schedule.lectures(on: section)!
        return todaysLectures.isEmpty ? 0 : (28+5)
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let todaysLectures = schedule.lectures(on: section)!
        if todaysLectures.isEmpty {
            return nil
        }
        guard let today = todaysLectures.first?.date else {
            return nil
        }
        
        let title = titleForHeader(withDate: today)
        
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
        let todaysLectures = schedule.lectures(on: section)!
        
        // Empty day => No section => No footer for that section (i.e. footer of 0 height)
        return todaysLectures.isEmpty ? 0 : 10
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let v = UIView()
        v.backgroundColor = UIColor.clear
        return v
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let todaysLectures = schedule.lectures(on: section)!
        return todaysLectures.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if expandedIndexPath == indexPath {
            return PTLectureCell.expandedHeight
        } else {
            return PTLectureCell.height
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        return tableView.dequeueReusableCell(withIdentifier: PTLectureCell.identifier, for: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let cell = cell as! PTLectureCell
        
        let todaysLectures = schedule.lectures(on: indexPath.section)!
        let lecture = todaysLectures[indexPath.row]
        
        cell.lecture = lecture
        cell.indexPath = indexPath
        cell.mapSelectionHandler = handleLectureMapSelection
        cell.isExpanded = (expandedIndexPath == indexPath)
        cell.stopLoadingIndicator()
        
        if cell.isExpanded, let roomName = lecture.roomName, let room = room(answearingName: roomName) {
            
            if let snapshot = cachedMapSnapshot(forRoom: room) {
                
                cell.stopLoadingIndicator()
                cell.setMapSnapshot(snapshot)
                
            } else {
                
                cell.startLoadingIndicator()
                cell.setMapSnapshot(nil)
                let snapshotSize = estimateSnapshotSize()
                reloadMapSnapshot(forRoom: room, size: snapshotSize, indexPath: indexPath)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // Checks if the selected row can be expanded
        if room(forIndexPath: indexPath) != nil {
            
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
}



// MARK: TableView Utilities

extension HomeViewController {
    
    func handleLectureMapSelection(indexPath: IndexPath) {
        
        if let room = room(forIndexPath: indexPath) {
            showRoomInMapViewController(room: room)
        }
    }
    
    func titleForHeader(withDate date: Date) -> String {
        
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = false
        formatter.timeStyle = .none
        
        if let relative = formatter.relativeDateString(from: date) {
            
            formatter.dateStyle = .long
            return "\(relative.capitalized) (\(formatter.string(from: date).capitalized))"
            
        } else {
            
            formatter.dateStyle = .full
            return formatter.string(from: date).capitalized
        }
    }
    
    func room(forIndexPath indexPath: IndexPath) -> PTRoom? {
        
        let todaysLectures = schedule.lectures(on: indexPath.section)!
        
        guard todaysLectures.count > indexPath.row else { return nil; }
        
        let lecture = todaysLectures[indexPath.row]
        
        guard let roomName = lecture.roomName else { return nil; }
        
        return room(answearingName: roomName)
    }
    
    func room(answearingName roomName: String) -> PTRoom? {
        
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
    
    /// Returns the IndexPath of the specified lecture, if found in the table, otherwise nil
    func indexPath(ofLecture lecture: PTLecture) -> IndexPath? {
        
        for day in PTScheduleDay.allValues {
            
            let todaysLectures = schedule.lectures(on: day)
            
            for r in 0..<todaysLectures.count {
                
                if lecture == todaysLectures[r] {
                    return IndexPath(row: r, section: day.rawValue)
                }
            }
        }
        
        return nil
    }
    
    /// Scrolls to the top of the table
    func scrollToFirstRow() {
        
        if allLectures.isEmpty { return; }
        
        // Looks for the first non-empty section
        for day in PTScheduleDay.allValues {
            
            if !(schedule.lectures(on: day).isEmpty) {
                
                // Scrolls to the first row of that section
                let indexPath = IndexPath(row: 0, section: day.rawValue)
                self.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
                return;
            }
        }
    }
    
    /// Scrolls to the current lecture if possible, otherwise scrolls to the next lecture.
    func scrollToMostRelevantRow() {
        
        let now = Date()
        let dayIndex = italianWeekday(fromDate: now)
        
        if dayIndex > 4 {
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
        
        guard let day = PTScheduleDay(fromDate: now) else {
            // It's the weekend!
            return nil
        }
        
        let todaysLectures = schedule.lectures(on: day)
        
        for lecture in todaysLectures {
            
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
        
        for day in PTScheduleDay.allValues {
            
            let todaysLectures = schedule.lectures(on: day)
            
            for lecture in todaysLectures {
                
                let interval = now.timeIntervalSince(lecture.date)
                if interval < 0 {
                    return lecture
                }
            }
        }
        
        return nil
    }
}



// MARK: Map Methods

extension HomeViewController {
    
    func cachedMapSnapshot(forRoom room: PTRoom) -> UIImage? {
        
        let orientation = UIApplication.shared.statusBarOrientation
        
        return mapSnapshotCache.snapshot(for: room, orientation: orientation)
    }
    
    func estimateSnapshotSize() -> CGSize {
        
        let snapshotHeight = PTLectureCell.snapshotHeight
        let cellMargins = PTLectureCell.horizontalMarginsWidth
        let tableWidth = tableView.frame.width
        
        let cellWidth = tableWidth - cellMargins
        
        return CGSize(width: cellWidth, height: snapshotHeight)
    }

    func reloadMapSnapshot(forRoom room: PTRoom, size: CGSize, indexPath: IndexPath) {
        
        let coordinates = CLLocationCoordinate2D(latitude: room.latitude, longitude: room.longitude)
        
        let orientation = UIApplication.shared.statusBarOrientation
        
        let span = MKCoordinateSpan(latitudeDelta: 0.00125, longitudeDelta: 0.00125)
        let region = MKCoordinateRegion(center: coordinates, span: span)
        
        let options = MKMapSnapshotOptions()
        
        options.size = size
        options.mapType = .standard
        options.region = region
        options.showsBuildings = true
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        snapshotter.start(completionHandler: { [unowned self]
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
                
                
                if finalImage != nil {
                    
                    self.mapSnapshotCache.storeSnapshot(finalImage!, for: room, orientation: orientation)
                    self.tableView.reloadRows(at: [indexPath], with: .fade)
                }
            }
        })
    }
    
    func showMapNotAvailableAlert() {
        
        let alert = UIAlertController(title: ~"ls.generic.alert.error.title", message: ~"ls.homeVC.noMapAlert.body", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: ~"ls.generic.alert.dismiss", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func showRoomInMapViewController(room: PTRoom) {
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return; }
        appDelegate.showMapViewController(withHighlightedRoom: room)
    }
}



// MARK: Misc. Methods

extension HomeViewController {
    
    func handleTabBarItemSelection(wasAlreadySelected: Bool, poppingFromNavigationStack: Bool) {
        if wasAlreadySelected {
            scrollToMostRelevantRow()
        }
    }
    
    func reloadSchedule() {
        schedule = PTSchedule(withLectures: allLectures)
    }
    
    // Required to unwind from settings programmatically
    @IBAction func unwindFromSettings(_ segue: UIStoryboardSegue) {}
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        tableView.reloadData()
        
        coordinator.animate(alongsideTransition: { _ in
            self.tableView.backgroundView?.setNeedsDisplay()
        }, completion: nil)
    }
}



// MARK: PTMapSnapshotCache

fileprivate class PTMapSnapshotCache {
    
    private var snapshotsLandscape: [String: UIImage] = [:]
    private var snapshotsPortrait:  [String: UIImage] = [:]
    
    private class var documentsFolderURL: URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private class var snapshotsFolderURL: URL {
        return documentsFolderURL.appendingPathComponent("MapSnapshots")
    }
    
    init() {
        createCacheFolderIfNeeded()
    }
    
    func snapshot(for room: PTRoom, orientation: UIInterfaceOrientation) -> UIImage? {
        
        let roomID: String = room.hashValue.description
        
        if orientation.isPortrait {
            return snapshotsPortrait[roomID]
        } else {
            return snapshotsLandscape[roomID]
        }
    }
    
    func storeSnapshot(_ snapshot: UIImage, for room: PTRoom, orientation: UIInterfaceOrientation) {
        
        let roomID: String = room.hashValue.description
        
        if orientation.isPortrait {
            
            guard snapshotsPortrait[roomID] == nil else { return; }
            snapshotsPortrait[roomID] = snapshot
            
        } else {
            
            guard snapshotsLandscape[roomID] == nil else { return; }
            snapshotsLandscape[roomID] = snapshot
        }
        
        let url = snapshotURL(for: room, orientation: orientation)
        
        let data = UIImagePNGRepresentation(snapshot)
        try? data?.write(to: url)
    }
    
    func importFromDisk() {
        
        snapshotsLandscape.removeAll()
        snapshotsPortrait.removeAll()
        
        let folderURL = PTMapSnapshotCache.snapshotsFolderURL
        
        let urls = try? FileManager.default.contentsOfDirectory(at: folderURL,
                                                                includingPropertiesForKeys: nil,
                                                                options: .skipsSubdirectoryDescendants)
        
        guard urls != nil else { return; }
        
        for snapshotURL in urls! {
            
            let fileName = snapshotURL.lastPathComponent.components(separatedBy: ".").first
            guard fileName != nil, !(fileName!.isEmpty) else { continue; }
            
            let comps = fileName!.components(separatedBy: "_")
            guard comps.count == 2 else { continue; }
            
            let roomID = comps[0]
            let orientationID = comps[1]
            
            guard let data = try? Data(contentsOf: snapshotURL),
                let snapshot = UIImage(data: data)
                else { continue; }
            
            if orientationID == "p" {
                snapshotsPortrait[roomID] = snapshot
            } else if orientationID == "l" {
                snapshotsLandscape[roomID] = snapshot
            }
        }
    }
    
    class func fromDisk() -> PTMapSnapshotCache {
        let cache = PTMapSnapshotCache()
        cache.importFromDisk()
        return cache
    }
    
    func clear() {
        
        snapshotsLandscape.removeAll()
        snapshotsPortrait.removeAll()
        
        PTMapSnapshotCache.clearCacheFolder()
    }
    
    class func clearCacheFolder() {
        try? FileManager.default.removeItem(at: snapshotsFolderURL)
    }
    
    private func snapshotName(for room: PTRoom, orientation: UIInterfaceOrientation) -> String {
        
        let roomID: String = room.hashValue.description
        let orientationID: String = orientation.isPortrait ? "p" : "l"
        
        return "\(roomID)_\(orientationID).png"
    }
    
    private func snapshotURL(for room: PTRoom, orientation: UIInterfaceOrientation) -> URL {
        
        let name = snapshotName(for: room, orientation: orientation)
        return PTMapSnapshotCache.snapshotsFolderURL.appendingPathComponent(name)
    }
    
    private func createCacheFolderIfNeeded() {
        
        let fileManager = FileManager.default
        let path = PTMapSnapshotCache.snapshotsFolderURL.path
        
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue { return; }
        }
        
        try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
    }
}
