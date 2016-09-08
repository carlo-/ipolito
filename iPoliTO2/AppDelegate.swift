//
//  AppDelegate.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

enum ControllerIndex: Int {
    case home = 0
    case subjects = 1
    case career = 2
    case map = 3
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, PTSessionDelegate {

    var window: UIWindow?
    var session: PTSession? {
        return PTSession.shared
    }
    
    var homeVC: HomeViewController? {
        return getController(.home)     as? HomeViewController
    }
    var subjectsRootVC: SubjectsViewController? {
        return getController(.subjects) as? SubjectsViewController
    }
    var careerVC: CareerViewController? {
        return getController(.career)   as? CareerViewController
    }
    var mapVC: MapViewController? {
        return getController(.map)      as? MapViewController
    }
    

    func applicationDidFinishLaunching(_ application: UIApplication) {
        
        window?.makeKeyAndVisible()
        
        homeVC?.navigationItem.titleView = PTLoadingTitleView(withTitle: ~"Logging in...")
        
        if let account = storedAccount() {

            session?.account = account
            session?.delegate = self
            
            if account == kDemoAccount {
                session?.shouldLoadTestData = true
            }
            
            session?.open()
        } else {
            
            // User has to login
            presentSignInViewController()
        }
    }
    
    func showMapViewController(withHighlightedRoom room: PTRoom? = nil) {
        
        mapVC?.shouldFocus(onRoom: room)
        selectController(.map)
    }

    func sessionDidFinishOpening() {
        
        print("sessionDidFinishOpening")
        guard let session = session else { return }
        
        homeVC?.navigationItem.titleView = nil
        
        if let passedExams = session.passedExams {
            
            careerVC?.passedExams = passedExams
        }
        
        careerVC?.navigationItem.titleView = PTLoadingTitleView(withTitle: ~"Loading temporary grades...")
        session.requestTemporaryGrades()
        
        session.requestSchedule()
        
        if let subjects = self.session?.subjects {
            
            
            subjectsRootVC?.navigationItem.titleView = PTLoadingTitleView(withTitle: ~"Loading subjects data...")
            subjectsRootVC?.content = subjects.map({ $0 as Any })
            session.requestDataForSubjects(subjects: subjects)
            
        } else {
            
            // No subjects!
            // [...]
        }
    }
    
    func managerDidRetrieveSchedule(schedule: [PTLecture]?) {
        
        homeVC?.schedule = schedule ?? []
    }
    
    func presentSignInViewController() {
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let signInController = storyboard.instantiateViewController(withIdentifier: "SignInViewController_id") as? SignInViewController,
        let presenterController = window?.rootViewController else {
            return
        }
        
        presenterController.modalPresentationStyle = .currentContext
        presenterController.present(signInController, animated: true, completion: nil)
    }
    
    func sessionDidFailOpeningWithError(error: PTRequestError) {
        
        print("sessionDidFailOpeningWithError: \(error)")
        
        homeVC?.navigationItem.titleView = nil
        
        switch error {
        case .InvalidCredentials:
            // Display login window
            presentSignInViewController()
        default:
            break
        }
    }
    
    func managerDidRetrieveTemporaryGrades(_ temporaryGrades: [PTTemporaryGrade]?) {
        
        if let temporaryGrades = temporaryGrades {
            careerVC?.temporaryGrades = temporaryGrades
        }
        
        careerVC?.navigationItem.titleView = nil
    }
    
    func managerDidRetrieveSubjectData(data: PTSubjectData?, subject: PTSubject) {
        
        if let data = data {
            subjectsRootVC?.dataOfSubjects[subject] = data
        }
        
        if session?.dataOfSubjects.count == session?.subjects?.count {
            subjectsRootVC?.navigationItem.titleView = nil
        }
    }
    
    
    func performLogout() {
        session?.close()
    }
    
    func selectController(_ index: ControllerIndex) {
        let tabbarCtrl = self.window?.rootViewController as? UITabBarController
        tabbarCtrl?.selectedIndex = index.rawValue
    }
    
    func getController(_ index: ControllerIndex) -> UIViewController? {
        let tabbarCtrl = self.window?.rootViewController as? UITabBarController
        let navCtrl = tabbarCtrl?.viewControllers?[index.rawValue] as? UINavigationController
        
        return navCtrl?.viewControllers.first
    }

    func sessionDidFinishClosing() {
        presentSignInViewController()
    }
    
    func sessionDidFailClosingWithError(error: PTRequestError) {
        let alert = UIAlertController(title: ~"Oops!", message: ~"Could not logout at this time!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: ~"Dismiss", style: .cancel, handler: nil))
        window?.rootViewController?.present(alert, animated: true, completion: nil)
    }
}


private func storedAccount() -> PTAccount? {
    
    if kDebugForcePresentLoginVC {
        return nil
    }
    
    if kDebugShouldForceCredentials {
        return kDebugForcingCredentials
    }
    
    return PTKeychain.retrieveAccount()
}

