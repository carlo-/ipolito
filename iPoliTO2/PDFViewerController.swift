//
//  PDFViewerController.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 06/10/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

// MARK: -
// MARK: PDFScrollBarView

protocol PDFScrollBarViewDelegate {
    func cursorDidScroll(toPercent percent: Float)
}

class PDFScrollBarView: UIView {
    
    private(set) var cursor: UIView
    
    private let initialCursorPercent: Float
    
    var delegate: PDFScrollBarViewDelegate?
    
    var cursorPercent: Float {
        set {
            cursor.center.y = cursorCenterY(fromPercent: newValue)
        }
        get {
            return cursorPercent(fromCenterY: cursor.center.y)
        }
    }
    
    var cursorHeight: CGFloat = 30 {
        didSet {
            let cursorCenter = cursor.center
            var cursorFrame = cursor.frame
            
            cursorFrame.size.height = cursorHeight
            
            cursor.frame = cursorFrame
            cursor.center = cursorCenter
        }
    }
    
    override init(frame: CGRect) {
        
        cursor = UIView()
        initialCursorPercent = 0
        
        super.init(frame: frame)
        
        backgroundColor = #colorLiteral(red: 0.9777022546, green: 0.9777022546, blue: 0.9777022546, alpha: 1)
        
        cursor.backgroundColor = #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        addSubview(cursor)
        
        let recog = UIPanGestureRecognizer(target: self, action: #selector(cursorDidScroll(recognizer:)))
        cursor.addGestureRecognizer(recog)
    }
    
    private var panLocation: CGPoint = CGPoint.zero
    func cursorDidScroll(recognizer: UIPanGestureRecognizer) {
        
        if recognizer.state == .began {
            panLocation = recognizer.location(in: cursor)
            return
        }
        
        let location = recognizer.location(in: cursor)
        let dy = location.y - panLocation.y
        
        let newCenterY = cursor.center.y + dy
 
        let percent = cursorPercent(fromCenterY: newCenterY)
        
        cursorPercent = percent
        
        delegate?.cursorDidScroll(toPercent: percent)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        
        cursor.frame = CGRect(x: 0, y: 0, width: rect.width, height: cursorHeight)
        cursorPercent = initialCursorPercent
    }
    
    private func cursorCenterY(fromPercent percent: Float) -> CGFloat {
        
        let minY: CGFloat = cursorHeight / 2.0
        let maxY: CGFloat = frame.height - minY
        let span = maxY - minY
        
        if percent >= 1 {
            return maxY
        } else if percent <= 0 {
            return minY
        }
        
        return (CGFloat(percent) * span) + minY
    }
    
    private func cursorPercent(fromCenterY centerY: CGFloat) -> Float {
        
        let minY: CGFloat = cursorHeight / 2.0
        let maxY: CGFloat = frame.height - minY
        let span = maxY - minY
        
        let percent = Float((centerY - minY) / span)
        
        if percent >= 1 {
            return 1
        } else if percent <= 0 {
            return 0
        } else {
            return percent
        }
    }
}


// MARK: -
// MARK: PDFViewer

protocol PDFViewerDelegate: UIWebViewDelegate {
    func viewerDidScroll(toContentOffset contentOffset: CGPoint)
    func viewerDidReceiveSingleTap()
}

class PDFViewer: UIWebView {
    
    private func setup() {
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:)))
        singleTap.numberOfTapsRequired = 1
        
        let doubleTap = UITapGestureRecognizer()
        doubleTap.numberOfTapsRequired = 2
        
        singleTap.require(toFail: doubleTap)
        
        self.addGestureRecognizer(singleTap)
        self.addGestureRecognizer(doubleTap)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private var customDelegate: PDFViewerDelegate? {
        return delegate as? PDFViewerDelegate
    }
    
    func handleTap(recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return; }
        customDelegate?.viewerDidReceiveSingleTap()
    }
    
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)
        customDelegate?.viewerDidScroll(toContentOffset: scrollView.contentOffset)
    }
}


// MARK: -
// MARK: PDFViewerController

class PDFViewerController: UIViewController, PDFViewerDelegate, PDFScrollBarViewDelegate {
    
    static let identifier =  "PDFViewerController_id"
    static let parentIdentifier =  "PDFViewerNavigationController_id"
    
    @IBOutlet var viewer: PDFViewer!
    @IBOutlet var shareButton: UIBarButtonItem!
    @IBOutlet var viewerRightMargin: NSLayoutConstraint!
    
    private(set) var barTitle: String!
    private(set) var filePath: String!
    private(set) var canShare: Bool!
    
    private var scrollBarView: PDFScrollBarView!
    private var documentInteractionController: UIDocumentInteractionController?
    
    private var scrollBarHidden: Bool = false
    
    private var topBarHeight: CGFloat {
        
        if UIDevice.current.orientation.isPortrait {
            return 64.0
        } else {
            return 52.0
        }
    }
    
    private var bottomBarHeight: CGFloat {
        
        if UIDevice.current.orientation.isPortrait {
            return 44.0
        } else {
            return 32.0
        }
    }
    
    private let scrollBarWidth: CGFloat = 20.0
    
    
    
    // MARK: Loading and initial config
    
    override func viewDidLoad() {
        super.viewDidLoad()

        shareButton.isEnabled = canShare
        
        navigationItem.title = barTitle
        
        scrollBarView = PDFScrollBarView()
        view.addSubview(scrollBarView)
        scrollBarView.delegate = self
        
        setBarsHidden(false)
        
        loadFile(atPath: filePath)
    }
    
    func configure(title: String, filePath: String, canShare: Bool) {
        
        self.barTitle = title
        self.filePath = filePath
        self.canShare = canShare
    }
    
    func webViewDidFinishLoad(_ webView: UIWebView) {
        webView.scrollView.contentOffset.y = -topBarHeight
    }
    
    func loadFile(atPath path: String) {
        let fileURL = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: fileURL) else { return; }
        viewer.load(data, mimeType: "application/pdf", textEncodingName: "", baseURL: fileURL)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        let viewerOffset = viewer.scrollView.contentOffset
        
        coordinator.animate(alongsideTransition: { _ in
            
            self.layoutScrollBar(withControllerViewSize: size)
            self.viewerDidScroll(toContentOffset: viewerOffset)
            
        }, completion: nil)
    }
    
    
    
    // MARK: Class Funcs
    
    class func canOpenFile(atPath path: String) -> Bool {
        
        let fileURL = URL(fileURLWithPath: path)
        
        guard let data = try? Data(contentsOf: fileURL) else { return false; }
        
        return isDataPDF(data)
    }
    
    class func isDataPDF(_ data: Data) -> Bool {
        
        guard data.count > 0 else { return false; }
        
        var byte: UInt8 = 0
        
        data.copyBytes(to: &byte, count: 1)
        
        return byte == 0x25
    }
    
    
    
    // MARK: Single Tap / Bars Visibility
    
    func viewerDidReceiveSingleTap() {
        toggleBars(animated: true)
    }
    
    func toggleBars(animated: Bool = false) {
        
        guard let shouldShow = navigationController?.isNavigationBarHidden else { return; }
        
        setBarsHidden(!shouldShow, animated: animated)
    }
    
    func setBarsHidden(_ hidden: Bool, animated: Bool = false) {
        
        let prevYoffset = viewer.scrollView.contentOffset.y
        
        
        navigationController?.setNavigationBarHidden(hidden, animated: animated)
        navigationController?.setToolbarHidden(hidden, animated: animated)
        
        statusBarHidden = hidden
        
        setScrollBarHidden(hidden, animated: animated)
        
        viewerRightMargin.constant = hidden ? 0 : scrollBarWidth
        
        viewer.scrollView.showsVerticalScrollIndicator = hidden
        
        
        if !hidden {
            viewer.scrollView.contentOffset.y = prevYoffset - topBarHeight
        }
    }
    
    func layoutScrollBar(withControllerViewSize newSize: CGSize, visible: Bool) {
        
        let newFrame: CGRect
        
        if visible {
            
            newFrame = CGRect(x: newSize.width - scrollBarWidth,
                              y: topBarHeight,
                              width: scrollBarWidth,
                              height: newSize.height - topBarHeight - bottomBarHeight)
            
        } else {
            
            newFrame = CGRect(x: newSize.width,
                              y: topBarHeight,
                              width: scrollBarWidth,
                              height: newSize.height - topBarHeight - bottomBarHeight)
        }
        
        scrollBarView.frame = newFrame
    }
    
    func layoutScrollBar(withControllerViewSize newSize: CGSize) {
        layoutScrollBar(withControllerViewSize: newSize, visible: !scrollBarHidden)
    }
    
    func setScrollBarHidden(_ hidden: Bool, animated: Bool = false) {
        
        if animated {
            
            let duration = TimeInterval(UINavigationControllerHideShowBarDuration)
            
            UIView.animate(withDuration: duration, animations: {
                
                self.layoutScrollBar(withControllerViewSize: self.view.frame.size, visible: !hidden)
                
            }, completion: { _ in
                
                self.scrollBarHidden = hidden
            })
            
        } else {
            
            layoutScrollBar(withControllerViewSize: view.frame.size, visible: !hidden)
        }
    }
    
    
    
    // MARK: Zooming / Scroll Bar Appearance
    
    private func adjustScrollBar(forContentHeight contentHeight: CGFloat) {
        
        let scrollBarHeight = scrollBarView.frame.height
        
        let minCurHeight: CGFloat = 30
        let maxCurHeight: CGFloat = scrollBarHeight
        
        let ratio = scrollBarHeight / contentHeight
        var curHeight = maxCurHeight * ratio
        
        let alpha: CGFloat
        
        if ratio > 1 {
            alpha = 0
        } else if ratio < 0.8 {
            alpha = 1
        } else {
            alpha = 1 - (ratio - 0.8)/(1-0.8)
        }
        
        scrollBarView.cursor.backgroundColor = #colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1).withAlphaComponent(alpha)
        
        if curHeight > maxCurHeight {
            curHeight = maxCurHeight
        } else if curHeight < minCurHeight {
            curHeight = minCurHeight
        }
        
        scrollBarView.cursorHeight = curHeight
    }
    
    
    
    // MARK: Scrolling / Scroll Bar Cursor
    
    func cursorDidScroll(toPercent percent: Float) {
        
        viewer.scrollView.contentOffset.y = contentOffsetY(fromContentPercent: percent)
    }
    
    func viewerDidScroll(toContentOffset contentOffset: CGPoint) {
        
        let contentHeight = viewer.scrollView.contentSize.height
        adjustScrollBar(forContentHeight: contentHeight)
        
        scrollBarView.cursorPercent = contentPercent(fromContentOffsetY: contentOffset.y)
    }
    
    private func contentOffsetY(fromContentPercent percent: Float) -> CGFloat {
        
        let minOff: CGFloat = -topBarHeight
        let maxOff: CGFloat = viewer.scrollView.contentSize.height - viewer.scrollView.frame.height + bottomBarHeight
        let span = maxOff - minOff
        
        if percent >= 1 {
            return maxOff
        } else if percent <= 0 {
            return minOff
        }
        
        return (CGFloat(percent) * span) + minOff
    }
    
    private func contentPercent(fromContentOffsetY offsetY: CGFloat) -> Float {
        
        
        let minOff: CGFloat = -topBarHeight
        let maxOff: CGFloat = viewer.scrollView.contentSize.height - viewer.scrollView.frame.height + bottomBarHeight
        let span = maxOff - minOff
        
        let percent = Float((offsetY - minOff) / span)
        
        if percent >= 1 {
            return 1
        } else if percent <= 0 {
            return 0
        } else {
            return percent
        }
    }
    
    
    
    // MARK: Status Bar Visibility
    
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
    
    
    
    // MARK: Other Interactions

    @IBAction func sharePressed(_ sender: UIBarButtonItem) {
        presentOpenIn()
    }
    
    @IBAction func donePressed(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    func presentOpenIn() {
        
        if documentInteractionController == nil {
            documentInteractionController = UIDocumentInteractionController()
        }
        
        documentInteractionController?.url = URL(fileURLWithPath: filePath)
        documentInteractionController?.uti = "public.filename-extension"
        documentInteractionController?.presentOpenInMenu(from: view.bounds, in: view, animated: true)
    }

}
