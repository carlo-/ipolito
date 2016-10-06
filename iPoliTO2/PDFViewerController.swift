//
//  PDFViewerController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 06/10/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

class PDFViewerController: UIViewController, UIWebViewDelegate {
    
    static let identifier =  "PDFViewerController_id"
    static let parentIdentifier =  "PDFViewerNavigationController_id"
    
    @IBOutlet var webView: UIWebView!
    @IBOutlet var shareButton: UIBarButtonItem!
    
    private(set) var barTitle: String!
    private(set) var filePath: String!
    private(set) var canShare: Bool!
    
    private var documentInteractionController: UIDocumentInteractionController?

    override func viewDidLoad() {
        super.viewDidLoad()

        shareButton.isEnabled = canShare
        
        navigationItem.title = barTitle
        
        
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:)))
        singleTap.numberOfTapsRequired = 1
        
        let doubleTap = UITapGestureRecognizer()
        doubleTap.numberOfTapsRequired = 2
        
        singleTap.require(toFail: doubleTap)
        
        webView.addGestureRecognizer(singleTap)
        webView.addGestureRecognizer(doubleTap)
        
        

        let fileURL = URL(fileURLWithPath: filePath)
        
        guard let data = try? Data(contentsOf: fileURL) else { return; }
        
        webView.load(data, mimeType: "application/pdf", textEncodingName: "", baseURL: fileURL)
    }
    
    class func canHandleFile(atPath path: String) -> Bool {
        
        let fileURL = URL(fileURLWithPath: path)
        
        guard let data = try? Data(contentsOf: fileURL) else { return false; }
        
        return isDataPDF(data)
    }
    
    class func isDataPDF(_ data: Data) -> Bool {
        
        guard data.count > 0 else { return false; }
        
        var pointer: UInt8 = 0
        
        data.copyBytes(to: &pointer, count: 1)
        
        return pointer == 0x25
    }
    
    
    
    func handleTap(recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return; }
        toggleBars()
    }
    
    func toggleBars() {
        
        guard let shouldShow = navigationController?.isNavigationBarHidden else { return; }
        
        navigationController?.setNavigationBarHidden(!shouldShow, animated: true)
        navigationController?.setToolbarHidden(!shouldShow, animated: true)
        
        statusBarHidden = !shouldShow
    }
    
    
    
    
    var statusBarHidden: Bool = false {
        didSet {
            UIView.animate(withDuration: 0.2, animations: {
                self.setNeedsStatusBarAppearanceUpdate()
            })
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        get {
            return statusBarHidden
        }
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .fade
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
    
    
    
    
    
    func configure(title: String, filePath: String, canShare: Bool) {
        
        self.barTitle = title
        self.filePath = filePath
        self.canShare = canShare
    }
    
    
    

    @IBAction func sharePressed(_ sender: UIBarButtonItem) {
        
        presentOpenIn()
    }
    
    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        
        dismiss(animated: true, completion: nil)
    }
    
    
    
    
    func presentOpenIn() {
        
        documentInteractionController = UIDocumentInteractionController()
        documentInteractionController?.url = URL(fileURLWithPath: filePath)
        documentInteractionController?.uti = "public.filename-extension"
        
        documentInteractionController?.presentOpenInMenu(from: view.bounds, in: view, animated: true)
    }

}
