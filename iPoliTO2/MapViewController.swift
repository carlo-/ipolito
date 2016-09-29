//
//  MapViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController, UISearchResultsUpdating, UITableViewDelegate, UITableViewDataSource, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet private var searchResultsTable: UITableView!
    @IBOutlet private var mapView: MKMapView!
    
    private var locationManager = CLLocationManager()
    private var searchController = UISearchController(searchResultsController: nil)
    private var searchBar: UISearchBar { return searchController.searchBar }
    private var timePicker: CRTimePicker?
    
    var status: PTViewControllerStatus = .loggedOut {
        didSet {
            statusDidChange()
        }
    }
    
    private lazy var allRooms: [PTRoom] = {
        
        if let plistPath = Bundle.main.path(forResource: "Rooms", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: plistPath) {
            
            return PTParser.roomsFromRawContainer(dict) ?? []
        } else {
            return []
        }
    }()
    
    private var filteredRooms: [PTRoom] = []
    
    private var freeRoomsLoadedDate: Date? = nil
    private var freeRooms: [PTFreeRoom] = []
    private var freeRoomsAnnotations: [MKAnnotation] = []
    
    private var roomsToShow: [PTRoom] = []
    
    private var roomToFocus: PTRoom?
    
    
    
    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        
        let searchBar = searchController.searchBar
        searchBar.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 44)
        searchBar.placeholder = ~"ls.mapVC.searchBarPlaceholder"
        
        searchResultsTable.tableHeaderView = searchBar
        searchResultsTable.isScrollEnabled = false
        
        self.definesPresentationContext = true
        
        navigationItem.leftBarButtonItem = presentTimePickerButton()
        
        let cancelButtonAttributes: NSDictionary = [NSForegroundColorAttributeName: UIColor.iPoliTO.darkGray]
        UIBarButtonItem.appearance().setTitleTextAttributes(cancelButtonAttributes as? [String : AnyObject], for: .normal)
        
        locationManager.delegate = self
        if CLLocationManager.authorizationStatus() != .authorizedWhenInUse {
            locationManager.requestWhenInUseAuthorization()
        }
        
        showAllRooms()
        zoomToMainCampus(animated: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        reloadFreeRoomsIfNeeded()
        
        focusOnRoom(roomToFocus, animated: true)
    }
    
    deinit {
        searchController.view.removeFromSuperview()
    }
    
    func statusDidChange() {
        
        switch status {
        case .logginIn:
            navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.generic.status.loggingIn")
        case .ready:
            navigationItem.titleView = nil
            if isViewLoaded {
                reloadFreeRoomsIfNeeded()
            }
        case .loggedOut:
            navigationItem.titleView = nil
            freeRoomsLoadedDate = nil
        default:
            navigationItem.titleView = PTDualTitleView(withTitle: ~"ls.mapVC.title", subtitle: ~"ls.generic.status.offline")
        }
    }
    
    func handleTabBarItemSelection(wasAlreadySelected: Bool) {
        if wasAlreadySelected {
            focusOnRoom(nil, animated: true)
        }
    }
    
    // MARK: Room Managing Methods
    
    func shouldFocus(onRoom room: PTRoom?) {
        roomToFocus = room
    }
    
    /// Reloads free rooms if lastest data is nil or not from today
    private func reloadFreeRoomsIfNeeded() {
        
        if status != .ready {
            return
        }
        
        if freeRoomsLoadedDate != nil && Calendar.current.isDateInToday(freeRoomsLoadedDate!) {
            return
        }
        
        downloadFreeRooms()
    }
    
    private(set) var isDownloadingFreeRooms: Bool = false
    private func downloadFreeRooms(forDate date: Date? = nil) {
        
        if isDownloadingFreeRooms {
            return
        }
        
        isDownloadingFreeRooms = true
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.Turin
        formatter.dateFormat = "HH:mm"
        
        let subtitle = ~"ls.mapVC.showingFreeRoomsFor"+" "+formatter.string(from: date ?? Date())
        
        
        navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.mapVC.status.loading")
        
        PTSession.shared.requestFreeRooms(forDate: date, completion: {
            (freeRooms, error) in
            
            OperationQueue.main.addOperation({
                
                if error != nil {
                    
                    self.freeRoomsLoadedDate = nil
                    self.freeRooms = []
                    self.reloadRoomAnnotations()
                    self.navigationItem.titleView = PTDualTitleView(withTitle: ~"ls.mapVC.title", subtitle: ~"ls.mapVC.freeRoomsError")
                    
                } else {
                    
                    self.freeRoomsLoadedDate = date ?? Date()
                    self.freeRooms = freeRooms ?? []
                    self.reloadRoomAnnotations()
                    self.navigationItem.titleView = PTDualTitleView(withTitle: ~"ls.mapVC.title", subtitle: subtitle)
                }
                
                self.isDownloadingFreeRooms = false
            })
        })
    }
    
    private func isRoomFree(_ room: PTRoom) -> Bool {
        
        guard freeRooms.count > 0, let roomName = room.name[.Italian]?.lowercased() else {
            return false
        }
        
        for freeRoom in freeRooms {
            
            if freeRoom.lowercased() == roomName {
                return true
            }
        }
        
        return false
    }
    
    @discardableResult
    private func reloadRoomAnnotations() -> [MKPointAnnotation] {
        
        removeAllAnnotations()
        
        var annotations: [MKPointAnnotation] = []
        
        for room in roomsToShow {
            
            let isRoomFree = self.isRoomFree(room)
            
            let annot = MKPointAnnotation(fromRoom: room, free: isRoomFree)
            
            if isRoomFree {
                freeRoomsAnnotations.append(annot)
            }
            
            annotations.append(annot)
        }
        
        mapView.addAnnotations(annotations)
        
        if annotations.count == 1 {
            mapView.selectAnnotation(annotations.first!, animated: true)
        }
        
        return annotations
    }
    
    private func showAllRooms() {
        
        roomsToShow = allRooms
        reloadRoomAnnotations()
    }
    
    
    
    // MARK: Time Picker Methods
    
    private func presentTimePickerButton() -> UIBarButtonItem {
        let image = #imageLiteral(resourceName: "clock")
        return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(presentTimePicker))
    }
    
    private func dismissTimePickerButton() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissTimePicker))
    }
    
    private func confirmTimePickerButton() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(confirmTimePicker))
    }
    
    @objc private func presentTimePicker() {
        
        searchBar.isUserInteractionEnabled = false
        
        navigationItem.rightBarButtonItem = confirmTimePickerButton()
        navigationItem.leftBarButtonItem = dismissTimePickerButton()
        
        let finalFrame = CGRect(x: 0, y: searchResultsTable.frame.origin.y+64, width: view.frame.width, height: 50+44)
        let initialFrame = finalFrame.offsetBy(dx: view.frame.width, dy: 0)
        
        if timePicker == nil {
            timePicker = CRTimePicker(frame: initialFrame, date: freeRoomsLoadedDate)
            view.addSubview(timePicker!)
        } else {
            timePicker?.frame = initialFrame
        }
        
        guard let timePicker = timePicker else { return }
        
        timePicker.backgroundColor = UIColor.clear
        timePicker.tintColor = UIColor.black
        
        UIView.animate(withDuration: 0.25, animations: {
            timePicker.frame = finalFrame
            }, completion: { complete in
            self.searchController.isActive = false
        })
    }
    
    @objc private func dismissTimePicker() {
        
        guard let timePicker = timePicker else { return }
        
        navigationItem.rightBarButtonItem = nil
        navigationItem.leftBarButtonItem = presentTimePickerButton()
        
        UIView.animate(withDuration: 0.25, animations: {
            
            timePicker.frame = timePicker.frame.offsetBy(dx: self.view.frame.width, dy: 0)
            
            }, completion: { complete in
                
                self.searchBar.isUserInteractionEnabled = true
        })
    }
    
    @objc private func confirmTimePicker() {
        guard let timePicker = timePicker else {
            navigationItem.rightBarButtonItem = nil
            return
        }
        
        let selectedDate = timePicker.currentSelection()
        downloadFreeRooms(forDate: selectedDate)
        
        dismissTimePicker()
    }
    
    
    
    // MARK: Table View Delegate Methods
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "searchResultsCell", for: indexPath)
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredRooms.count
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        let room = filteredRooms[indexPath.row]
        
        cell.textLabel?.text = room.localizedName
        cell.detailTextLabel?.text = room.localizedFloor
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let room = filteredRooms[indexPath.row]
        
        searchBar.resignFirstResponder()
        
        if CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(fromRoom: room)) {
            roomToFocus = room
            focusOnRoom(room)
        } else {
            focusOnRoom(nil)
        }
    }
    
    
    
    // MARK: Search Controller Methods
    
    func updateSearchResults(for searchController: UISearchController) {
        
        guard let query = searchBar.text else { return }
        filteredRooms.removeAll()
        
        if searchBar.isFirstResponder {
            
            mapView.isHidden = true
            searchResultsTable.isScrollEnabled = true
            
        } else {
            
            mapView.isHidden = false
            searchResultsTable.isScrollEnabled = false
            
            if query.isEmpty {
                
                roomToFocus = nil
                showAllRooms()
                zoomToMainCampus()
                return
            }
        }
        
        
        let queryComps = query.lowercased().components(separatedBy: " ")
        
        filteredRooms = allRooms.filter({
            room in
            
            let roomName = room.localizedName.lowercased()
            
            for comp in queryComps {
                
                if comp.contains("aula") || comp.contains("room") {
                    continue
                }
                
                if roomName.contains(comp) {
                    return true
                }
            }
            
            return false
        })
        
        searchResultsTable.reloadData()
    }
    
    
    
    // MARK: Map View Methods
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if annotation is MKPointAnnotation {
            
            let isRoomFree = freeRoomsAnnotations.contains(where: { annot in
                return annot.hash == annotation.hash
            })
            
            let pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "roomPin")
            pinView.animatesDrop = false
            pinView.canShowCallout = true
            pinView.pinTintColor = isRoomFree ? #colorLiteral(red: 0.4028071761, green: 0.7315050364, blue: 0.2071235478, alpha: 1) : #colorLiteral(red: 0.6823074818, green: 0.08504396677, blue: 0.06545677781, alpha: 1)
            
            return pinView
        }
        
        return nil
    }
    
    private func removeAllAnnotations() {
        freeRoomsAnnotations.removeAll()
        mapView.removeAnnotations(mapView.annotations)
    }
    
    private func focusOnRoom(_ room: PTRoom?, animated: Bool = true) {
        
        guard let room = room else {
            
            searchController.isActive = false
            searchBar.text = nil
            roomToFocus = nil
            showAllRooms()
            zoomToMainCampus(animated: animated)
            return
        }
        
        
        searchBar.text = room.localizedName
        
        roomsToShow = [room]
        reloadRoomAnnotations()
        
        let coords = CLLocationCoordinate2D(fromRoom: room)
        guard CLLocationCoordinate2DIsValid(coords) else { return }
        
        zoomToCoordinates(coords, withDelta: 0.00125, animated: animated)
    }
    
    private func zoomToMainCampus(animated: Bool = true) {
        zoomToCoordinates(CLLocationCoordinate2D.PolitecnicoMainCampus, withDelta: 0.00925, animated: animated)
    }
    
    private func zoomToCoordinates(_ coordinates: CLLocationCoordinate2D, withDelta delta: Double, animated: Bool = true) {
        
        guard CLLocationCoordinate2DIsValid(coordinates) else {
            return
        }
        
        let span = MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        let region = MKCoordinateRegion(center: coordinates, span: span)
        
        mapView.setRegion(region, animated: animated)
    }
}

fileprivate extension CLLocationCoordinate2D {
    static let PolitecnicoMainCampus = CLLocationCoordinate2D(latitude: 45.063371, longitude: 7.659864)
    
    init(fromRoom room: PTRoom) {
        self.latitude = room.latitude
        self.longitude = room.longitude
    }
}

fileprivate extension MKPointAnnotation {
    convenience init(fromRoom room: PTRoom, free: Bool) {
        
        self.init()
        
        let roomName = room.localizedName
        let roomFloor = room.localizedFloor
        let coords = CLLocationCoordinate2D(fromRoom: room)
        
        let roomStatus = free ? ~"ls.mapVC.freeRoom.status.free" : ~"ls.mapVC.freeRoom.status.occupied"
        
        self.coordinate = coords
        self.title = roomName
        self.subtitle = roomStatus+" - "+roomFloor
    }
}
