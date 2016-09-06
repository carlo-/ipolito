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
    
    private var searchController = UISearchController(searchResultsController: nil)
    private var searchBar: UISearchBar { return searchController.searchBar }
    private var timePicker: CRTimePicker?
    
    private lazy var allRooms: [PTRoom] = {
        
        if let plistPath = Bundle.main.path(forResource: "Rooms", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: plistPath) {
            
            return PTParser.roomsFromRawContainer(dict)
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
        searchBar.placeholder = ~"Search for a room"
        
        searchResultsTable.tableHeaderView = searchBar
        searchResultsTable.isScrollEnabled = false
        
        self.definesPresentationContext = true
        
        navigationItem.leftBarButtonItem = presentTimePickerButton()
        
        
        showAllRooms()
        zoomToMainCampus(animated: false)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        reloadFreeRoomsIfNeeded()
        
        focusOnRoom(roomToFocus, animated: true)
        roomToFocus = nil
    }
    
    deinit {
        searchController.view.removeFromSuperview()
    }
    
    
    
    // MARK: Room Managing Methods
    
    func shouldFocus(onRoom room: PTRoom?) {
        roomToFocus = room
    }
    
    /// Reloads free rooms if lastest data is nil or not from today
    private func reloadFreeRoomsIfNeeded() {
        
        if freeRoomsLoadedDate != nil && Calendar.current.isDateInToday(freeRoomsLoadedDate!) {
            return
        }
        
        downloadFreeRooms()
    }
    
    private func downloadFreeRooms(forDate date: Date? = nil) {
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.Turin
        formatter.dateFormat = "HH:mm"
        
        let subtitle = ~"Showing free rooms for"+" "+formatter.string(from: date ?? Date())
        
        
        navigationItem.titleView = PTLoadingTitleView(withTitle: ~"Loading free rooms...")
        
        PTSession.shared.requestFreeRooms(forDate: date, completion: {
            freeRooms in
            
            OperationQueue.main.addOperation({
                
                self.freeRoomsLoadedDate = date ?? Date()
                self.freeRooms = freeRooms ?? []
                self.reloadRoomAnnotations()
                self.navigationItem.titleView = PTDualTitleView(withTitle: ~"Map", subtitle: subtitle)
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
    
    private func reloadRoomAnnotations() {
        
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
        
        guard timePicker == nil else { return }
        
        navigationItem.rightBarButtonItem = confirmTimePickerButton()
        navigationItem.leftBarButtonItem = dismissTimePickerButton()
        
        let pickerFrame = CGRect(x: 0, y: searchResultsTable.frame.origin.y+64, width: view.frame.width, height: 50+60)
        
        timePicker = CRTimePicker(frame: pickerFrame.offsetBy(dx: view.frame.width, dy: 0), date: freeRoomsLoadedDate)
        guard let timePicker = timePicker else { return }
        
        timePicker.backgroundColor = UIColor.clear
        timePicker.tintColor = UIColor.black
        
        view.addSubview(timePicker)
        
        UIView.animate(withDuration: 0.25, animations: {
            timePicker.frame = pickerFrame
        })
    }
    
    @objc private func dismissTimePicker() {
        
        guard let timePicker = timePicker else { return }
        
        navigationItem.rightBarButtonItem = nil
        navigationItem.leftBarButtonItem = presentTimePickerButton()
        
        UIView.animate(withDuration: 0.25, animations: {
            
            timePicker.frame = timePicker.frame.offsetBy(dx: self.view.frame.width, dy: 0)
            
            }, completion: { complete in
                
                timePicker.removeFromSuperview()
                self.timePicker = nil
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
            focusOnRoom(room)
        } else {
            searchBar.text = nil
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
        
        if let annotation = mapView.annotations.first {
            mapView.selectAnnotation(annotation, animated: true)
        }
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
        
        let roomStatus = free ? ~"Free" : ~"Occupied"
        
        self.coordinate = coords
        self.title = roomName
        self.subtitle = roomStatus+" - "+roomFloor
    }
}