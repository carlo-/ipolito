//
//  MapViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController {

    @IBOutlet fileprivate var searchResultsTable: UITableView!
    @IBOutlet fileprivate var mapView: MKMapView!
    
    fileprivate var locationManager = CLLocationManager()
    
    fileprivate var searchBarContainer: UIView!
    fileprivate var searchController = UISearchController(searchResultsController: nil)
    fileprivate var searchBar: UISearchBar { return searchController.searchBar }
    fileprivate var searchBarText: String { return searchBar.text ?? "" }
    
    fileprivate var timePicker: CRTimePicker?
    fileprivate var timePickerVisible: Bool = false
    
    fileprivate lazy var allRooms: [PTRoom] = [PTRoom].fromBundle()
    
    fileprivate var filteredRooms: [PTRoom] = []
    fileprivate var roomsToShow: [PTRoom] = []
    fileprivate var roomToFocus: PTRoom?
    
    fileprivate(set) var isDownloadingFreeRooms: Bool = false
    fileprivate var freeRoomsLoadedDate: Date? = nil
    fileprivate var freeRoomsAnnotations: [MKAnnotation] = []
    fileprivate var freeRooms: [PTFreeRoom] = []
    
    fileprivate var freeRoomsLoadedDateDescription: String? {
        
        guard let date = freeRoomsLoadedDate else { return nil; }
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.Turin
        formatter.dateFormat = "HH:mm"
        
        return ~"ls.mapVC.showingFreeRoomsFor"+" "+formatter.string(from: date)
    }
    
    var status: PTViewControllerStatus = .loggedOut {
        didSet {
            statusDidChange()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.showsCompass = false

        setupSearchController()
        
        navigationItem.leftBarButtonItem = presentTimePickerButton()
        
        locationManager.delegate = self
        if CLLocationManager.authorizationStatus() != .authorizedWhenInUse {
            locationManager.requestWhenInUseAuthorization()
        }
        
        showAllRooms()
        zoomToMainCampus(animated: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        dismissSearchBar()
        
        reloadFreeRoomsIfNeeded()
        
        focusOnRoom(roomToFocus, animated: true)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        guard isViewLoaded else { return; }
        
        UIView.animate(withDuration: 0.35, animations: {
            
            self.layoutSearchBar(withControllerViewSize: size)
            self.layoutTimePicker(withControllerViewSize: size)
        })
    }
    
    func statusDidChange() {
        
        switch status {
        case .logginIn:
            navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.generic.status.loggingIn")
        case .ready:
            navigationItem.titleView = PTDualTitleView(withTitle: ~"ls.mapVC.title", subtitle: freeRoomsLoadedDateDescription ?? "")
            if isViewLoaded { reloadFreeRoomsIfNeeded() }
        case .loggedOut:
            navigationItem.titleView = nil
            freeRoomsLoadedDate = nil
        default:
            navigationItem.titleView = PTDualTitleView(withTitle: ~"ls.generic.status.offline", subtitle: freeRoomsLoadedDateDescription ?? "")
        }
    }
    
    func handleTabBarItemSelection(wasAlreadySelected: Bool) {
        
        if wasAlreadySelected {
            
            dismissSearchBar()
            focusOnRoom(nil, animated: true)
        }
    }
    
    deinit {
        searchController.view.removeFromSuperview()
    }
}



// MARK: - Room Managing methods

extension MapViewController {
    
    func shouldFocus(onRoom room: PTRoom?) {
        
        // Dismiss search bar if needed
        dismissSearchBar()
        roomToFocus = room
    }
    
    /// Reloads free rooms if lastest data is nil or not from today
    fileprivate func reloadFreeRoomsIfNeeded() {
        
        if status != .ready {
            return
        }
        
        if freeRoomsLoadedDate != nil && Calendar.current.isDateInToday(freeRoomsLoadedDate!) {
            return
        }
        
        downloadFreeRooms()
    }
    
    
    fileprivate func downloadFreeRooms(forDate date: Date? = nil) {
        
        if isDownloadingFreeRooms {
            return
        }
        
        isDownloadingFreeRooms = true
        
        navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.mapVC.status.loading")
        
        PTSession.shared.requestFreeRooms(forDate: date, completion: { [unowned self]
            result in
            
            OperationQueue.main.addOperation({
                
                switch result {
                    
                case .success(let freeRooms):
                    self.freeRoomsLoadedDate = date ?? Date()
                    self.freeRooms = freeRooms
                    self.reloadRoomAnnotations()
                    self.navigationItem.titleView = PTDualTitleView(withTitle: ~"ls.mapVC.title", subtitle: self.freeRoomsLoadedDateDescription ?? "")
                    
                case .failure(_):
                    self.freeRoomsLoadedDate = nil
                    self.freeRooms = []
                    self.reloadRoomAnnotations()
                    self.navigationItem.titleView = PTDualTitleView(withTitle: ~"ls.mapVC.title", subtitle: ~"ls.mapVC.freeRoomsError")
                    
                }
                
                self.isDownloadingFreeRooms = false
            })
        })
    }
    
    fileprivate func isRoomFree(_ room: PTRoom) -> Bool {
        
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
    fileprivate func reloadRoomAnnotations() -> [MKPointAnnotation] {
        
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
    
    fileprivate func showAllRooms() {
        
        roomsToShow = allRooms
        reloadRoomAnnotations()
    }
}
    


// MARK: - Time Picker methods
    
extension MapViewController {
    
    fileprivate func presentTimePickerButton() -> UIBarButtonItem {
        let image = #imageLiteral(resourceName: "clock")
        return UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(presentTimePicker))
    }
    
    fileprivate func dismissTimePickerButton() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(dismissTimePicker))
    }
    
    fileprivate func confirmTimePickerButton() -> UIBarButtonItem {
        return UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(confirmTimePicker))
    }
    
    fileprivate func layoutTimePicker(withControllerViewSize newSize: CGSize) {
        layoutTimePicker(withControllerViewSize: newSize, visible: timePickerVisible)
    }
    
    private func layoutTimePicker(withControllerViewSize newSize: CGSize, visible: Bool) {
        
        let orientation = UIDevice.current.orientation
        
        let height: CGFloat = 50.0 + 44.0
        let width = newSize.width
        
        let topBarMaxY: CGFloat
        
        if orientation.isLandscape {
            topBarMaxY = 32.0
        } else {
            topBarMaxY = 64.0
        }
        
        var newTimePickerFrame = CGRect(x: 0, y: topBarMaxY, width: width, height: height)
        
        if !visible {
            newTimePickerFrame = newTimePickerFrame.offsetBy(dx: width, dy: 0)
        }
        
        timePicker?.frame = newTimePickerFrame
    }
    
    @objc fileprivate func presentTimePicker() {
        
        searchBar.isUserInteractionEnabled = false
        
        navigationItem.rightBarButtonItem = confirmTimePickerButton()
        navigationItem.leftBarButtonItem = dismissTimePickerButton()
        
        if timePicker == nil {
            
            timePicker = CRTimePicker(frame: .zero, date: freeRoomsLoadedDate)
            timePicker?.backgroundColor = UIColor.clear
            timePicker?.tintColor = UIColor.iPoliTO.darkGray
            
            view.addSubview(timePicker!)
            
            timePickerVisible = false
            
            layoutTimePicker(withControllerViewSize: view.frame.size, visible: false)
        }
        
        UIView.animate(withDuration: 0.25, animations: {
            
            self.layoutTimePicker(withControllerViewSize: self.view.frame.size, visible: true)
            
        }, completion: { _ in
            
            self.searchController.isActive = false
            self.timePickerVisible = true
            self.layoutTimePicker(withControllerViewSize: self.view.frame.size, visible: true)
        })
    }
    
    @objc fileprivate func dismissTimePicker() {
        
        navigationItem.rightBarButtonItem = nil
        navigationItem.leftBarButtonItem = presentTimePickerButton()
        
        guard let timePicker = timePicker else { return }
        
        timePicker.stopScrollView()
        
        UIView.animate(withDuration: 0.25, animations: {
            
            self.layoutTimePicker(withControllerViewSize: self.view.frame.size, visible: false)
            
        }, completion: { _ in
                
            self.searchBar.isUserInteractionEnabled = true
            self.timePickerVisible = false
            self.layoutTimePicker(withControllerViewSize: self.view.frame.size, visible: false)
        })
    }
    
    @objc fileprivate func confirmTimePicker() {
        guard let timePicker = timePicker else {
            navigationItem.rightBarButtonItem = nil
            return
        }
        
        let selectedDate = timePicker.currentSelection()
        downloadFreeRooms(forDate: selectedDate)
        
        dismissTimePicker()
    }
}
    

// MARK: - TableView methods
    
extension MapViewController: UITableViewDelegate, UITableViewDataSource {
    
    func setSearchResultsTableVisible(_ visible: Bool, animated: Bool) {
        
        if animated {
            
            UIView.transition(with: mapView, duration: 0.25, options: .transitionCrossDissolve, animations: {
                self.searchResultsTable.layer.opacity = (visible ? 1.0 : 0.0)
            }, completion: nil)
            
        } else { searchResultsTable.layer.opacity = (visible ? 1.0 : 0.0)}
    }
    
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
        
        dismissSearchBar()
        
        focusOnRoom(room)
    }
    
}



// MARK: - Search related methods

extension MapViewController: UISearchControllerDelegate, UISearchResultsUpdating {
    
    func layoutSearchBar(withControllerViewSize newSize: CGSize) {
        
        let orientation = UIDevice.current.orientation
        
        let height: CGFloat = 44.0
        let width = newSize.width
        
        let bottomBarHeight: CGFloat = 49.0
        
        let searchBarMaxY: CGFloat
        let topBarMaxY: CGFloat
        
        if orientation.isLandscape {
            topBarMaxY = 32.0
            searchBarMaxY = 44.0
        } else {
            topBarMaxY = 64.0
            searchBarMaxY = 64.0
        }
        
        if !(searchController.isActive) {
            
            searchBar.frame = CGRect(x: 0, y: 0, width: width, height: height)
        }
        
        searchBarContainer.frame = CGRect(x: 0, y: topBarMaxY, width: width, height: height)
        
        searchResultsTable.contentInset = UIEdgeInsets(top: searchBarMaxY, left: 0, bottom: bottomBarHeight, right: 0)
        searchResultsTable.scrollIndicatorInsets = UIEdgeInsets(top: searchBarMaxY, left: 0, bottom: bottomBarHeight, right: 0)
    }
    
    func setupSearchController() {
        
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.dimsBackgroundDuringPresentation = false
        
        searchBar.placeholder = ~"ls.mapVC.searchBarPlaceholder"
        
        searchBarContainer = UIView()
        searchBarContainer.addSubview(searchBar)
        searchBarContainer.isOpaque = false
        view.insertSubview(searchBarContainer, belowSubview: searchResultsTable)
        
        definesPresentationContext = true
        
        let cancelButtonAttributes: NSDictionary = [NSForegroundColorAttributeName: UIColor.iPoliTO.darkGray]
        UIBarButtonItem.appearance().setTitleTextAttributes(cancelButtonAttributes as? [String : AnyObject], for: .normal)
        
        layoutSearchBar(withControllerViewSize: view.frame.size)
    }
    
    func dismissSearchBar(force: Bool = false) {
        if force || searchController.isActive {
            searchController.isActive = false
        }
    }
    
    /*
    func didPresentSearchController(_ searchController: UISearchController) {
    }
    */
 
    func didDismissSearchController(_ searchController: UISearchController) {
        searchController.searchBar.frame = searchBarContainer.bounds
    }
    
    func willPresentSearchController(_ searchController: UISearchController) {
        setSearchResultsTableVisible(true, animated: true)
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        setSearchResultsTableVisible(false, animated: true)
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        
        let query = searchBarText
        
        if query.isEmpty {
            
            filteredRooms.removeAll()
            searchResultsTable.reloadData()
            
            if searchController.isBeingDismissed {
                focusOnRoom(nil)
            }
            
            return;
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
}



// MARK: - MapView methods

extension MapViewController: MKMapViewDelegate, CLLocationManagerDelegate {
    
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
    
    fileprivate func removeAllAnnotations() {
        freeRoomsAnnotations.removeAll()
        mapView.removeAnnotations(mapView.annotations)
    }
    
    fileprivate func focusOnRoom(_ room: PTRoom?, animated: Bool = true) {
        
        guard let room = room else {
            
            roomToFocus = nil
            
            if !searchBarText.isEmpty {
                searchBar.text = nil
            }
            
            showAllRooms()
            zoomToMainCampus(animated: animated)
            return
        }
        
        let coords = CLLocationCoordinate2D(fromRoom: room)
        guard CLLocationCoordinate2DIsValid(coords) else {
            
            focusOnRoom(nil, animated: animated)
            return
        }
        
        roomToFocus = room
        searchBar.text = room.localizedName
        
        roomsToShow = [room]
        reloadRoomAnnotations()
        
        zoomToCoordinates(coords, withDelta: 0.00125, animated: animated)
    }
    
    fileprivate func zoomToMainCampus(animated: Bool = true) {
        zoomToCoordinates(CLLocationCoordinate2D.PolitecnicoMainCampus, withDelta: 0.00925, animated: animated)
    }
    
    fileprivate func zoomToCoordinates(_ coordinates: CLLocationCoordinate2D, withDelta delta: Double, animated: Bool = true) {
        
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
