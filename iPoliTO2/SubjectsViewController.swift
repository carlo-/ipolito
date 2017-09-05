//
//  SubjectsViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

class SubjectsViewController: UITableViewController {

    fileprivate let latestUploadsLimit: Int = 5
    
    fileprivate var searchController = UISearchController(searchResultsController: nil)
    fileprivate var searchBar: UISearchBar { return searchController.searchBar }
    fileprivate var searchBarText: String { return searchBar.text ?? "" }
    fileprivate let searchOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    fileprivate var searchResults: [SearchResult] = []
    fileprivate var latestUploadsResults: [SearchResult] = []
    fileprivate var allFilesResults: [SearchResult] = []
    
    fileprivate var isSearchBarActive: Bool {
        return searchController.isActive
    }
    
    fileprivate var isShowingSearchResults: Bool {
        return isSearchBarActive && !searchBarText.isEmpty
    }
    
    fileprivate var isShowingLatestUploads: Bool {
        return isSearchBarActive && searchBarText.isEmpty
    }
    
    var subjects: [PTSubject] = [] {
        didSet { tableView.reloadData() }
    }
    
    var dataOfSubjects: [PTSubject: PTSubjectData] = [:]
    
    var status: PTViewControllerStatus = .loggedOut {
        didSet { statusDidChange() }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 11.0, *) {
            // Disable use of 'large title' display mode
            navigationItem.largeTitleDisplayMode = .never
        }
        
        // Removes annoying row separators after the last cell
        tableView.tableFooterView = UIView()
        
        setupRefreshControl()
        setupSearchController()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigationItem.rightBarButtonItem?.isEnabled = !(DownloadsViewController.hasContentToShow)
        
        tableView.reloadData()
        updateTabBarBadge()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { _ in
            self.tableView.backgroundView?.setNeedsDisplay()
        }, completion: nil)
    }
    
    func statusDidChange() {
        
        searchBar.isUserInteractionEnabled = false
        
        if status != .fetching && status != .logginIn {
            refreshControl?.endRefreshing()
        }
        
        let isTableEmpty = subjects.isEmpty
        
        if isTableEmpty {
            
            setSearchBarVisible(false)
            tableView.isScrollEnabled = false
            navigationItem.titleView = nil
            
            let refreshButton = UIButton(type: .system)
            refreshButton.addTarget(self, action: #selector(refreshButtonPressed), for: .touchUpInside)
            
            switch status {
                
            case .logginIn:
                tableView.backgroundView = PTLoadingTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.loggingIn")
                
            case .offline:
                refreshButton.setTitle(~"ls.generic.alert.retry", for: .normal)
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.offline", button: refreshButton)
                
            case .error:
                refreshButton.setTitle(~"ls.generic.alert.retry", for: .normal)
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.generic.status.couldNotRetrieve", button: refreshButton)
                
            case .ready:
                refreshButton.setTitle(~"ls.generic.refresh", for: .normal)
                tableView.backgroundView = PTSimpleTableBackgroundView(frame: view.bounds, title: ~"ls.subjectsVC.status.noSubjects", button: refreshButton)
                navigationItem.titleView = PTSession.shared.lastUpdateTitleView(title: ~"ls.subjectsVC.title")
                
            default:
                tableView.backgroundView = nil
            }
            
        } else {
            
            setSearchBarVisible(true)
            tableView.isScrollEnabled = true
            tableView.backgroundView = nil
            
            switch status {
            case .logginIn:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.generic.status.loggingIn")
            case .fetching:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.subjectsVC.status.loading")
            case .offline:
                navigationItem.titleView = PTLoadingTitleView(withTitle: ~"ls.generic.status.offline")
            default:
                searchBar.isUserInteractionEnabled = true
                navigationItem.titleView = PTSession.shared.lastUpdateTitleView(title: ~"ls.subjectsVC.title")
            }
        }
        
        if status == .ready {
            
            dataOfSubjectsReady()
        }
    }
    
    func dataOfSubjectsReady() {
        
        OperationQueue().addOperation({ [unowned self] _ in
            
            self.updateAllFilesResults()
            self.updateLatestUploadsResults()
            
            OperationQueue.main.addOperation {
                
                self.updateTabBarBadge()
                self.tableView.reloadData()
            }
        })
    }
    
    func handleTabBarItemSelection(wasAlreadySelected: Bool, poppingFromNavigationStack: Bool) {
        
        if (wasAlreadySelected && !poppingFromNavigationStack) {
            
            if searchController.isActive {
                dismissSearchBar()
            } else {
                scrollToTopOfTableView()
            }
        }
    }
    
    func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refreshControlActuated), for: .valueChanged)
    }
    
    func setRefreshControlEnabled(_ enabled: Bool) {
        
        if enabled && refreshControl == nil {
            setupRefreshControl()
        } else if !enabled {
            refreshControl = nil
        }
    }
    
    @objc
    func refreshControlActuated() {
        if PTSession.shared.isBusy || isShowingSearchResults {
            refreshControl?.endRefreshing()
        } else {
            (UIApplication.shared.delegate as! AppDelegate).login()
        }
    }
    
    @objc
    func refreshButtonPressed() {
        (UIApplication.shared.delegate as! AppDelegate).login()
    }
    
    func updateTabBarBadge() {
        var total = 0
        for (_, data) in dataOfSubjects {
            total += data.numberOfUnreadMessages
        }
        if #available(iOS 10.0, *) {
            parent?.tabBarItem.badgeColor = #colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1)
        }
        parent?.tabBarItem.badgeValue = total > 0 ? String(total) : nil
    }
}



// MARK: - Tap on subject cell

extension SubjectsViewController {

    func showMessages(forSubject subject: PTSubject) {
        
        let id = MessagesViewController.identifier
        
        if let childController = storyboard?.instantiateViewController(withIdentifier: id) as? MessagesViewController,
           let messages = dataOfSubjects[subject]?.messages {
            
            childController.configure(forSubject: subject, withMessages: messages)
            
            navigationController?.pushViewController(childController, animated: true)
        }
    }
    
    func showDocuments(forSubject subject: PTSubject) {
        
        let id = DocumentsViewController.identifier
        
        if let childController = storyboard?.instantiateViewController(withIdentifier: id) as? DocumentsViewController,
           let documents = dataOfSubjects[subject]?.documents {
            
            childController.configure(forSubject: subject, withDocuments: documents)
            
            navigationController?.pushViewController(childController, animated: true)
        }
    }
    
    func showInfo(forSubject subject: PTSubject) {
        
        let id = SubjectInfoViewController.identifier
        
        if let childController = storyboard?.instantiateViewController(withIdentifier: id) as? SubjectInfoViewController,
            let guide = dataOfSubjects[subject]?.guide {
            
            let info = dataOfSubjects[subject]?.info
            
            childController.configure(forSubject: subject, withGuide: guide, andInfo: info)
            
            navigationController?.pushViewController(childController, animated: true)
        }
    }
    
    func showVideolectures(forSubject subject: PTSubject) {
        
        let id = VideolecturesViewController.identifier
        
        if let childController = storyboard?.instantiateViewController(withIdentifier: id) as? VideolecturesViewController,
            let videos = dataOfSubjects[subject]?.videolectures {
            
            childController.configure(forSubject: subject, andVideolectures: videos)
            
            navigationController?.pushViewController(childController, animated: true)
        }
    }
    
    func presentOptions(forSubject subject: PTSubject) {
        
        guard let data = dataOfSubjects[subject] else {
            // Still fetching data for this particular subject
            return
        }
        
        let alertController: UIAlertController
        
        if data.isValid {
            
            let nmessages = data.messages.count
            let ndocuments = data.numberOfFiles
            let nvideos = (data.videolectures ?? []).count
            
            if nmessages > 0 || ndocuments > 0 || data.guide != nil || nvideos > 0 {
                
                alertController = UIAlertController(title: subject.name, message: nil, preferredStyle: .actionSheet)
                
                if data.guide != nil {
                    
                    let documentsTitle = ~"ls.subjectsVC.subjectOptions.info"
                    alertController.addAction(UIAlertAction(title: documentsTitle, style: .default, handler: {
                        action in
                        self.showInfo(forSubject: subject)
                    }))
                }
                
                if nmessages > 0 {
                    let messagesTitle = ~"ls.subjectsVC.subjectOptions.messages"
                    alertController.addAction(UIAlertAction(title: messagesTitle, style: .default, handler: {
                        action in
                        self.showMessages(forSubject: subject)
                    }))
                }
                
                if ndocuments > 0 {
                    
                    let documentsTitle = ~"ls.subjectsVC.subjectOptions.documents"
                    alertController.addAction(UIAlertAction(title: documentsTitle, style: .default, handler: {
                        action in
                        self.showDocuments(forSubject: subject)
                    }))
                }
                
                if nvideos > 0 {
                    
                    let documentsTitle = ~"ls.subjectsVC.subjectOptions.videolectures"
                    alertController.addAction(UIAlertAction(title: documentsTitle, style: .default, handler: {
                        action in
                        self.showVideolectures(forSubject: subject)
                    }))
                }
                
                alertController.addAction(UIAlertAction(title: ~"ls.generic.alert.cancel", style: .cancel, handler: nil))
                
            } else {
                
                alertController = UIAlertController(title: ~"ls.generic.alert.error.title",
                                                    message: ~"ls.subjectsVC.noFilesOrMessagesAlert.body",
                                                    preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: ~"ls.generic.alert.dismiss", style: .default, handler: nil))
            }
            
        } else {
            // Data for this subject is invalid, which means parsing has failed
            
            alertController = UIAlertController(title: ~"ls.generic.alert.error.title",
                                                message: ~"ls.subjectsVC.invalidSubjectDataAlert.body",
                                                preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: ~"ls.generic.alert.dismiss", style: .default, handler: nil))
        }
        
        present(alertController, animated: true, completion: nil)
    }
    
}



// MARK: - General TableView methods

extension SubjectsViewController {
    
    func scrollToTopOfTableView(animated: Bool = true) {
        
        let topBarMaxY = navigationController!.navigationBar.frame.maxY
        let searchBarMaxY = searchBar.frame.maxY
        
        let yOffset: CGFloat = searchController.isActive ? -searchBarMaxY : -topBarMaxY
        tableView.setContentOffset(CGPoint(x: 0, y: yOffset), animated: animated)
    }
    
    func reloadTable(animated: Bool = false) {
        
        if animated {
            
            UIView.transition(with: tableView, duration: 0.25, options: .transitionCrossDissolve, animations: {
                self.tableView.reloadData()
            }, completion: nil)
            
        } else { tableView.reloadData() }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if isSearchBarActive {
            return 44.0
        } else {
            return PTSubjectCell.height
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if isShowingSearchResults {
            return (section == 0 ? searchResults.count : 0)
        } else if isShowingLatestUploads {
            return (section == 0 ? latestUploadsResults.count : allFilesResults.count)
        } else {
            return (section == 0 ? subjects.count : 0)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        if isSearchBarActive {
            return 2
        } else {
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if isShowingLatestUploads {
            return (section == 0 ? ~"ls.subjectsVC.latestUploads" : ~"ls.subjectsVC.allFiles")
        } else {
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if isSearchBarActive {
            return tableView.dequeueReusableCell(withIdentifier: "searchResultCell_id")!
        } else {
            return tableView.dequeueReusableCell(withIdentifier: PTSubjectCell.identifier)!
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        if isSearchBarActive {
            
            cell.textLabel?.textColor = UIColor.iPoliTO.darkGray
            cell.detailTextLabel?.font = .systemFont(ofSize: 11)
            cell.detailTextLabel?.textColor = .lightGray
            
            if isShowingSearchResults {
                // Showing search results
                
                let result = searchResults[indexPath.row]
                cell.textLabel?.text = result.file.description
                cell.detailTextLabel?.text = result.subject.name + result.file.path
                
            } else if isShowingLatestUploads && indexPath.section == 0 {
                // Showing latest uploads
                
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                
                let result = latestUploadsResults[indexPath.row]
                cell.textLabel?.text = result.file.description
                cell.detailTextLabel?.text = formatter.string(from: result.file.date!) + " - " + result.subject.name
                
            } else if isShowingLatestUploads && indexPath.section == 1 {
                // Showing all files
                
                let result = allFilesResults[indexPath.row]
                cell.textLabel?.text = result.file.description
                cell.detailTextLabel?.text = result.subject.name + result.file.path
            }
            
        } else if let cell = cell as? PTSubjectCell {
            
            let subject = subjects[indexPath.row]
            cell.configure(forSubject: subject, unreadMessages: dataOfSubjects[subject]?.numberOfUnreadMessages ?? 0)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        if isSearchBarActive {
            
            let result: SearchResult
            
            if isShowingSearchResults {
                // Showing search results
                
                result = searchResults[indexPath.row]
                
            } else if isShowingLatestUploads && indexPath.section == 0 {
                // Showing latest uploads
                
                result = latestUploadsResults[indexPath.row]
                
            } else if isShowingLatestUploads && indexPath.section == 1 {
                // Showing all files
                
                result = allFilesResults[indexPath.row]
                
            } else { return; }
            
            showFileInItsLocation(file: result.file, subject: result.subject)
            
        } else {
            
            let subject = subjects[indexPath.row]
            presentOptions(forSubject: subject)
        }
    }
}



// MARK: Tap on search result

extension SubjectsViewController {
    
    func showFileInItsLocation(file: PTMFile, subject: PTSubject) {
        
        searchBar.resignFirstResponder()
        
        let stack = getDVControllersStack(forElement: file, subject: subject)
        let completeStack: [UIViewController] = [self] + stack
        navigationController?.setViewControllers(completeStack, animated: true)
        
        delay(0.3) {
            
            if let topController = completeStack.last as? DocumentsViewController {
                topController.highlightRow(ofElement: file)
            }
        }
    }
    
    private func getDVControllersStack(forElement elem: PTMElement, subject: PTSubject) -> [DocumentsViewController] {
        
        if let parent = elem.parent {
            
            let currentStack = getDVControllersStack(forElement: parent, subject: subject)
            let rootController = currentStack.first
            
            if let enclosingFolder = parent as? PTMFolder {
                
                if let childController = storyboard?.instantiateViewController(withIdentifier: DocumentsViewController.identifier) as? DocumentsViewController {
                    
                    childController.configure(forFolder: enclosingFolder, andRootController: rootController ?? childController)
                    return currentStack + [childController]
                }
            }
            
            return currentStack
            
        } else {
            
            if let childController = storyboard?.instantiateViewController(withIdentifier: DocumentsViewController.identifier) as? DocumentsViewController,
               let documents = dataOfSubjects[subject]?.documents {
                
                childController.configure(forSubject: subject, withDocuments: documents)
                
                return [childController]
                
            } else {
                return []
            }
        }
    }
}



// MARK: - Search related methods

extension SubjectsViewController: UISearchResultsUpdating, UISearchControllerDelegate {
    
    fileprivate struct SearchResult {
        let file: PTMFile
        let subject: PTSubject
        let score: Double
    }
    
    func updateAllFilesResults() {
        
        var _allFiles: [SearchResult] = []
        
        for s in subjects {
            guard let someFiles = dataOfSubjects[s]?.flatFiles else { continue; }
            _allFiles += someFiles.map({ SearchResult(file: $0, subject: s, score: 0.0) })
        }
        
        allFilesResults = _allFiles.sorted(by: { $0.file.description < $1.file.description })
    }
    
    func updateLatestUploadsResults() {
        
        // Filter out files with nil date
        var allFilesWithDate = allFilesResults.filter({ $0.file.date != nil })
        
        // Sort by date
        allFilesWithDate.sort(by: { $0.file.date! > $1.file.date! })
        
        // Grab the first elements up to the limit
        latestUploadsResults = Array(allFilesWithDate.prefix(latestUploadsLimit))
    }
    
    fileprivate func setSearchBarVisible(_ enabled: Bool) {

        if #available(iOS 11.0, *) {

            if enabled && self.navigationItem.searchController == nil {
                self.navigationItem.searchController = searchController
            } else if !enabled {
                self.navigationItem.searchController = nil
            }
            tableView.safeAreaInsetsDidChange()

        } else {
            // Fallback on earlier versions

            if enabled && tableView.tableHeaderView == nil {
                tableView.tableHeaderView = searchBar
            } else if !enabled {
                tableView.tableHeaderView = nil
            }
        }
    }
    
    fileprivate func setupSearchController() {
        
        tableView.keyboardDismissMode = .onDrag
        
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.dimsBackgroundDuringPresentation = false
        
        let searchBar = searchController.searchBar
        searchBar.placeholder = ~"ls.subjectsVC.searchBarPlaceholder"

        if #available(iOS 11.0, *) {
            self.navigationItem.searchController = searchController
            tableView.contentInsetAdjustmentBehavior = .always

        } else {
            // Fallback on earlier versions
            searchBar.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 44)
            tableView.tableHeaderView = searchBar
        }

        self.definesPresentationContext = true
        
        let cancelButtonAttributes: NSDictionary = [NSForegroundColorAttributeName: UIColor.iPoliTO.darkGray]
        UIBarButtonItem.appearance().setTitleTextAttributes(cancelButtonAttributes as? [String : AnyObject], for: .normal)
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {

        if #available(iOS 11.0, *) {
            // tableView.setContentOffset(CGPoint(x: 0, y: -64), animated: false)
        } else {
            // Fallback on earlier versions
            tableView.setContentOffset(CGPoint(x: 0, y: -64+44), animated: false)
        }
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        setRefreshControlEnabled(true)
        tableView.tableFooterView = UIView()

        if #available(iOS 11.0, *) {
            tableView.safeAreaInsetsDidChange()
        } else {
            // Fallback on earlier versions
            tableView.scrollIndicatorInsets = UIEdgeInsets(top: 64, left: 0, bottom: 49, right: 0)
        }
    }
    
    func willPresentSearchController(_ searchController: UISearchController) {
        setRefreshControlEnabled(false)
        tableView.tableFooterView = nil
    }
    
    func didPresentSearchController(_ searchController: UISearchController) {

        if #available(iOS 11.0, *) {
            tableView.safeAreaInsetsDidChange()
            // tableView.setContentOffset(CGPoint(x: 0, y: -64), animated: false)
            // tableView.scrollIndicatorInsets = UIEdgeInsets(top: 64, left: 0, bottom: 49, right: 0)

        } else {
            // Fallback on earlier versions
            tableView.scrollIndicatorInsets = UIEdgeInsets(top: 64, left: 0, bottom: 49, right: 0)
        }
    }
    
    func dismissSearchBar(force: Bool = false) {
        if force || searchController.isActive {
            searchController.isActive = false
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        
        searchOperationQueue.cancelAllOperations()
        
        let query = searchBarText
        
        if query.isEmpty {
            searchResults.removeAll()
            reloadTable(animated: true)
            return;
        }
        
        let searchOperation = BlockOperation()
        
        searchOperation.addExecutionBlock { [unowned self, unowned searchOperation] in
            
            var results = self.evaluateQuery(query)
            
            if searchOperation.isCancelled { return; }
            
            results.sort(by: {
                
                if $0.score == $1.score {
                    return $0.file.description < $1.file.description
                } else {
                    return $0.score > $1.score
                }
            })
            
            if searchOperation.isCancelled { return; }
            
            OperationQueue.main.addOperation {
                self.searchResults = results
                self.reloadTable(animated: false)
            }
        }
        
        searchOperationQueue.addOperation(searchOperation)
    }
    
    private func evaluateQuery(_ query: String) -> [SearchResult] {
        
        let queryLC = query.lowercased()
        let queryComps = queryLC.components(separatedBy: " ")
        
        if queryLC.isEmpty { return [] }
        
        let results: [SearchResult] = allFilesResults.flatMap({ result in
            
            let file = result.file
            let subject = result.subject
            
            let descrLC = file.description.lowercased()
            
            let score = evaluateScore(forQueryComponents: queryComps, onTarget: descrLC, strictly: true)
            
            if score > 0.0 {
                return SearchResult(file: file, subject: subject, score: score)
            } else {
                return nil
            }
        })
        
        return results
    }
    
    private func evaluateScore(forQueryComponents queryComps: [String], onTarget target: String, strictly: Bool) -> Double {
        
        var score: Double = 0.0
        
        let targetComps = target.components(separatedBy: " ")
        
        for qComp in queryComps {
            
            if qComp.isEmpty { continue; }
            
            if target.contains(qComp) {
                
                let qCompLen = Double(qComp.characters.count)
                
                for tComp in targetComps {
                    
                    if tComp.contains(qComp) {
                        
                        let tCompLen = Double(tComp.characters.count)
                        
                        score += qCompLen/tCompLen
                        
                    }
                }
                
            } else if strictly {
                // Target must contain all query comps
                return 0.0
            }
        }
        
        let normalized = score/Double(targetComps.count)
        return normalized
    }
}



// MARK: -

class PTSubjectCell: UITableViewCell {
    
    static let identifier = "PTSubjectCell_id"
    static let height = 70 as CGFloat
    
    @IBOutlet var mainLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet var messagesLabel: UILabel!
    @IBOutlet var messagesIcon: UIImageView!
    @IBOutlet var messagesIconWidth: NSLayoutConstraint!
    
    func configure(forSubject subject: PTSubject, unreadMessages: Int = 0) {
        mainLabel.text = subject.name
        
        var subtitle = ""
        
        if unreadMessages > 0 {
            subtitle = "  - "
            
            messagesLabel.text = String(unreadMessages) + " "
            messagesIconWidth.constant = 18
        } else {
            
            messagesLabel.text = nil
            messagesIconWidth.constant = 0
        }
        
        subtitleLabel.text = subtitle+subject.inserimento+" - \(subject.credits) "+(~"ls.generic.credits")
        
        messagesIcon.tintColorDidChange()
    }
}
