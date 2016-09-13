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
    var subjectsVC: SubjectsViewController? {
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
        
        login()
    }
    
    func login() {
        
        homeVC?.status = .logginIn
        subjectsVC?.status = .logginIn
        careerVC?.status = .logginIn
        mapVC?.status = .logginIn
        
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
    
    func showLoginErrorAlert(error: PTRequestError) {
        
        let alert = UIAlertController(title: ~"Oops...", message: nil, preferredStyle: .alert)
        
        alert.message = {
            switch (error) {
            case .NotConnectedToInternet:
                return ~"You're not connected to the internet!"
            case .ServerUnreachable:
                return ~"Servers unreachable or under maintenance!"
            case .TimedOut:
                return ~"Request took too long! Try again."
            default:
                return ~"An unknown error has occurred!"
            }
        }()
        
        alert.addAction(UIAlertAction(title: ~"Retry", style: .default, handler: {
            action in
            self.login()
        }))
        
        window?.rootViewController?.present(alert, animated: true)
    }

    func sessionDidFinishOpening() {
        
        print("sessionDidFinishOpening")
        guard let session = session else { return }
        
        mapVC?.status = .ready
        
        if let passedExams = session.passedExams {
            
            careerVC?.passedExams = passedExams
        }
        
        careerVC?.status = .fetching
        session.requestTemporaryGrades()
        
        homeVC?.status = .fetching
        session.requestSchedule()
        
        if let subjects = self.session?.subjects {
            
            subjectsVC?.subjects = subjects
            subjectsVC?.status = .fetching
            session.requestDataForSubjects(subjects: subjects)
            
        } else {
            
            // No subjects!
            subjectsVC?.status = .ready
        }
    }
    
    func managerDidRetrieveSchedule(schedule: [PTLecture]?) {
        
        print("managerDidRetrieveSchedule")
        
        homeVC?.schedule = schedule ?? []
        homeVC?.status = .ready
    }
    
    func managerDidFailRetrievingScheduleWithError(error: PTRequestError) {
        
        print("managerDidFailRetrievingScheduleWithError: \(error)")
        
        homeVC?.status = .error
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
        
        homeVC?.status = .error
        subjectsVC?.status = .error
        careerVC?.status = .error
        mapVC?.status = .error
        
        switch error {
        case .InvalidCredentials:
            // Presents login window
            presentSignInViewController()
        default:
            showLoginErrorAlert(error: error)
            break
        }
    }
    
    func managerDidRetrieveTemporaryGrades(_ temporaryGrades: [PTTemporaryGrade]?) {
        
        if let temporaryGrades = temporaryGrades {
            careerVC?.temporaryGrades = temporaryGrades
        }
        
        careerVC?.status = .ready
    }
    
    func managerDidFailRetrievingTemporaryGradesWithError(error: PTRequestError) {
        careerVC?.status = .error
    }
    
    func managerDidRetrieveSubjectData(data: PTSubjectData?, subject: PTSubject) {
        
        if let data = data {
            subjectsVC?.dataOfSubjects[subject] = data
        }
        
        if session?.dataOfSubjects.count == session?.subjects?.count {
            subjectsVC?.status = .ready
        }
    }
    
    func managerDidFailRetrievingSubjectDataWithError(error: PTRequestError, subject: PTSubject) {
        subjectsVC?.status = .error
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

