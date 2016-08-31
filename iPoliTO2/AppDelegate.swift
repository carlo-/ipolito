//
//  AppDelegate.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, PTSessionDelegate {

    var window: UIWindow?
    var session: PTSession? {
        return PTSession.shared
    }
    
    var homeVC: HomeViewController? {
        
        let tabbarCtrl = self.window?.rootViewController as? UITabBarController
        let navCtrl = tabbarCtrl?.viewControllers?[0] as? UINavigationController
        
        return navCtrl?.viewControllers.first as? HomeViewController
    }
    
    var subjectsRootVC: SubjectsViewController? {
        
        let tabbarCtrl = self.window?.rootViewController as? UITabBarController
        let navCtrl = tabbarCtrl?.viewControllers?[1] as? UINavigationController
        
        return navCtrl?.viewControllers.first as? SubjectsViewController
    }
    
    var careerVC: CareerViewController? {
        
        let tabbarCtrl = self.window?.rootViewController as? UITabBarController
        let navCtrl = tabbarCtrl?.viewControllers?[2] as? UINavigationController
        
        return navCtrl?.viewControllers.first as? CareerViewController
    }
    
    var mapVC: MapViewController? {
        
        let tabbarCtrl = self.window?.rootViewController as? UITabBarController
        let navCtrl = tabbarCtrl?.viewControllers?[3] as? UINavigationController
        
        return navCtrl?.viewControllers.first as? MapViewController
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
        
        let tabbarCtrl = self.window?.rootViewController as? UITabBarController
        
        // TODO: Write this in a cleaner way!
        tabbarCtrl?.selectedIndex = 3
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

}


private func storedAccount() -> PTAccount? {
    
    if kDebugForcePresentLoginVC {
        return nil
    }
    
    if kDebugShouldForceCredentials {
        return kDebugForcingCredentials
    }
    
    // TODO: Must use the user's account!
    return nil
}

