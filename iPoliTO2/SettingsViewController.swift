//
//  SettingsViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/07/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit
import MessageUI

class SettingsViewController: UITableViewController, MFMailComposeViewControllerDelegate {

    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var usernameLabel: UILabel!
    
    private let logoutIndexPath = IndexPath(row: 1, section: 0)
    private let learnMoreIndexPath = IndexPath(row: 0, section: 1)
    private let feedbackIndexPath = IndexPath(row: 0, section: 2)
    private let reviewIndexPath = IndexPath(row: 0, section: 3)
    private let tellSomeFriendsIndexPath = IndexPath(row: 1, section: 3)

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 11.0, *) {
            // Disable use of 'large title' display mode
            navigationItem.largeTitleDisplayMode = .never
        }
        
        let session = PTSession.shared
        
        nameLabel.text = session.studentInfo?.fullName ?? "???"
        usernameLabel.text = session.account?.studentID ?? "??"
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath {
        case logoutIndexPath:
            logoutPressed()
        case learnMoreIndexPath:
            learnMorePressed()
        case feedbackIndexPath:
            feedbackPressed()
        case reviewIndexPath:
            reviewPressed()
        case tellSomeFriendsIndexPath:
            tellSomeFriendsPressed()
        default:
            break
        }
    }
    
    func logoutPressed() {
        
        let alert = UIAlertController(title: ~"ls.settingsVC.logoutAlert.title", message: ~"ls.settingsVC.logoutAlert.body", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: ~"ls.generic.alert.cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: ~"ls.generic.alert.confirm", style: .destructive, handler: {
            action in
            self.performLogout()
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    func learnMorePressed() {
        let url = URL(string: PTConstants.gitHubReadmeLink)!
        UIApplication.shared.openURL(url)
    }
    
    func feedbackPressed() {
        
        if MFMailComposeViewController.canSendMail() {
            
            let subject = "iPoliTO -> Feedback"
            let body = ""
            
            presentEmailComposer(withSubject: subject, andBody: body)
        } else {
            showNoEmailAccountAlert()
        }
    }
    
    func reviewPressed() {
        let url = URL(string: PTConstants.appStoreReviewLink)!
        UIApplication.shared.openURL(url)
    }
    
    func tellSomeFriendsPressed() {
        
        let url = URL(string: PTConstants.appStoreLink)
        let text = ~"ls.settingsVC.tellSomeFriendsBody"
        
        presentSharePopup(withText: text, image: nil, andURL: url)
    }
    
    
    func presentEmailComposer(withSubject subject: String?, andBody body: String?) {
        
        guard MFMailComposeViewController.canSendMail() else {
            return
        }
        
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        
        composer.setSubject(subject ?? "")
        composer.setMessageBody(body ?? "", isHTML: false)
        composer.setToRecipients([PTConstants.feedbackEmail])
        
        present(composer, animated: true, completion: nil)
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true, completion: nil)
    }
    
    func showNoEmailAccountAlert() {
        
        let title = ~"ls.generic.alert.error.title"
        let message = ~"ls.settingsVC.noEmailConfiguredAlert.body"
        let dismissal = ~"ls.generic.alert.dismiss"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: dismissal, style: .cancel, handler: nil))
    }
    
    func presentSharePopup(withText text: String?, image: UIImage?, andURL url: URL?) {
        
        var items: [Any] = []
        
        if (text  != nil) { items.append(text!)  }
        if (image != nil) { items.append(image!) }
        if (url   != nil) { items.append(url!)   }
        
        if items.isEmpty { return; }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        present(activityVC, animated: true, completion: nil)
    }
    
    func performLogout() {
        
        performSegue(withIdentifier: "unwindFromSettings_id", sender: self)
        
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.logout()
        }
    }
}
