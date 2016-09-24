//
//  SignInViewController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 22/08/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

class SignInViewController: UIViewController, UITextFieldDelegate, PTSessionDelegate {

    @IBOutlet var spacerView1: UIView!
    @IBOutlet var signinLabel: UILabel!
    @IBOutlet var spacerView2: UIView!
    @IBOutlet var studentIdField: UITextField!
    @IBOutlet var passwordField: UITextField!
    @IBOutlet var signinButton: UIButton!
    @IBOutlet var stackTopMarginContraint: NSLayoutConstraint!
    @IBOutlet var activityIndicatorView: UIView!
    @IBOutlet var blurEffectView: UIVisualEffectView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        modalPresentationStyle = .overCurrentContext
        
        studentIdField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        passwordField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        
        if UIAccessibilityIsReduceTransparencyEnabled() {
            blurEffectView.isHidden = true
            view.backgroundColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1).withAlphaComponent(0.9)
        }
    }
    
    func textFieldDidChange(_ textField: UITextField) {
        
        if textField == studentIdField {
            
            let digits = NSCharacterSet.decimalDigits
            
            var newText = ""
            
            if let text = textField.text {
                
                for char in text.unicodeScalars {
                    
                    if digits.contains(char) {
                        
                        // append(c: Character) not available anymore for some reason
                        newText += String(char)
                    }
                }
            }
            
            if newText.isEmpty {
                textField.text = ""
            } else {
                textField.text = "s"+newText
            }
        }
        
        signinButton.isEnabled = fieldsAreValid()
    }
    
    func fieldsAreValid() -> Bool {
        
        guard let matricola = studentIdField.text, let password = passwordField.text else {
            return false
        }
        
        return !(matricola.isEmpty) && !(password.isEmpty)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if fieldsAreValid() {
            adjustUIforLoading()
            signIn()
        } else {
            studentIdField.becomeFirstResponder()
        }
        
        return false
    }
    
    
    
    func adjustUIforLoading(isLoading loading: Bool = true) {
        
        if loading {
            studentIdField.resignFirstResponder()
            passwordField.resignFirstResponder()
        }
        
        studentIdField.isEnabled = !loading
        passwordField.isEnabled = !loading
        
        signinButton.isHidden = loading
        activityIndicatorView.isHidden = !loading
    }
    
    func showRequestErrorAlert(error: PTRequestError) {
        
        
        let alert = UIAlertController(title: ~"ls.generic.alert.error.title", message: nil, preferredStyle: .alert)
        
        alert.message = {
            switch (error) {
            case .InvalidCredentials:
                return ~"ls.generic.ptRequestError.invalidCredentials"
            case .NotConnectedToInternet:
                return ~"ls.generic.ptRequestError.notConnectedToInternet"
            case .ServerUnreachable:
                return ~"ls.generic.ptRequestError.serverUnreachable"
            case .TimedOut:
                return ~"ls.generic.ptRequestError.timedOut"
            default:
                return ~"ls.generic.ptRequestError.unknown"
            }
        }()
        
        alert.addAction(UIAlertAction(title: ~"ls.generic.alert.edit", style: .cancel, handler: {
            action in
            self.studentIdField.becomeFirstResponder()
        }))
        alert.addAction(UIAlertAction(title: ~"ls.generic.alert.retry", style: .default, handler: {
            action in
            self.signinButtonPressed(self.signinButton)
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func signinButtonPressed(_ sender: UIButton) {
        
        adjustUIforLoading()
        signIn()
    }
    
    func sessionDidFinishOpening() {
        // Success!
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        
        let session = PTSession.shared
        session.delegate = appDelegate
        
        dismiss(animated: true, completion: {
            appDelegate.sessionDidFinishOpening()
        })
    }
    
    func sessionDidFailOpeningWithError(error: PTRequestError) {
        
        self.adjustUIforLoading(isLoading: false)
        self.showRequestErrorAlert(error: error)
    }
    
    func signIn() {
        
        guard let studentID = studentIdField.text,
            let password = passwordField.text else {
            return
        }
        
        let account: PTAccount = {
            
            if kDebugShouldForceCredentials {
                return kDebugForcingCredentials
            } else {
                return PTAccount(rawStudentID: studentID, password: password)
            }
        }()
        
        let session = PTSession.shared
        session.account = account
        session.delegate = self
        
        if account == kDemoAccount {
            session.shouldLoadTestData = true
        }
        
        
        session.open()
    }
    
    func showSignInLabel(_ shouldShow: Bool = true) {
        
        let smallScreen = UIScreen.main.bounds.height < 500
        
        let scale: CGFloat = shouldShow ? 1 : 0.5
        
        UIView.animate(withDuration: 0.3, animations: {
            
            self.signinLabel.transform = CGAffineTransform(scaleX: scale, y: scale)
            
            self.spacerView1.isHidden = !shouldShow
            self.spacerView2.isHidden = !shouldShow
            
            if smallScreen {
                self.stackTopMarginContraint.constant = 10
            }
        })
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        showSignInLabel(false)
    }
}
