//
//  CRRoundedCell.swift
//
//  Created by Carlo Rapisarda on 28/06/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

class CRRoundedCell: UITableViewCell {
    
    typealias CRRoundedCellSelectionHandler = ((_ cell: CRRoundedCell, _ indexPath: IndexPath) -> Void)
    
    static let defaultHorizontalMarginsWidth: CGFloat = 18.0
    static let defaultVerticalMarginsHeight: CGFloat = 10.0
    
    var horizontalMarginsWidth: CGFloat = defaultHorizontalMarginsWidth
    var verticalMarginsHeight: CGFloat = defaultVerticalMarginsHeight
    
    var cornerRadius: CGFloat = 14.0 {
        didSet {
            self.roundedView?.layer.cornerRadius = cornerRadius
        }
    }
    
    var selectionHandler: CRRoundedCellSelectionHandler? {
        didSet {
            self.roundedView?.selectionHandler = selectionHandler
        }
    }
    
    var indexPath: IndexPath?
    var roundedView: CRRoundedCellContentView?
    var childView: UIView? {
        didSet {
            if let subviews = self.roundedView?.subviews {
                for v in subviews {
                    v.removeFromSuperview()
                }
            }
            if childView != nil {
                self.roundedView?.addSubview(childView!)
            }
        }
    }
    var isExpanded: Bool = false
    
    
    convenience init(indexPath: IndexPath, childView: UIView? = nil) {
        
        self.init()
        
        self.indexPath = indexPath
        self.childView = childView
        
        selectionStyle = .none
        backgroundColor = UIColor.clear
        contentView.backgroundColor = UIColor.clear
        
        
        roundedView = CRRoundedCellContentView(cell: self)
        roundedView?.layer.cornerRadius = self.cornerRadius
        
//        contentView.layer.shadowColor = UIColor.black.cgColor
//        contentView.layer.shadowOffset = CGSize(width: 3, height: 3)
//        contentView.layer.shadowOpacity = 0.3
//        contentView.layer.shadowRadius = 4.0
//        
//        contentView.layer.rasterizationScale = 2
//        contentView.layer.shouldRasterize = true
//
        self.roundedView?.layer.borderWidth = 0.5
        self.roundedView?.layer.borderColor = UIColor(red:0.47, green:0.47, blue:0.47, alpha:0.5).cgColor

        
        contentView.addSubview(self.roundedView!)
    }
    
    func cellWasSelected() {
        
        guard let indexPath = indexPath else { return }
        self.selectionHandler?(self, indexPath)
    }
    
    override func draw(_ rect: CGRect) {
        
        super.draw(rect)
        
        let clippedRect = CGRect(x: rect.origin.x + self.horizontalMarginsWidth/2.0,
                                 y: rect.origin.y + self.verticalMarginsHeight/2.0,
                                 width: rect.size.width - self.horizontalMarginsWidth,
                                 height: rect.size.height - self.verticalMarginsHeight)
        
        self.roundedView?.frame = clippedRect
        
        if let childView = self.childView {
            childView.frame = CGRect(origin: childView.frame.origin,
                                     size: CGSize(width: clippedRect.width, height: childView.frame.height))
        }
        
    }
    
    
    
    class CRRoundedCellContentView: UIView {
        
        var cell: CRRoundedCell?
        
        // private var scaleAnimator: UIViewPropertyAnimator?
        private var forceDidChange = false
        private let defaultColor: UIColor = #colorLiteral(red: 0.8866936139, green: 0.8949507475, blue: 0.8806994207, alpha: 1)
        private var shouldBroadcastSelection = true
        var selectionHandler: CRRoundedCellSelectionHandler?
        
        convenience init(cell: CRRoundedCell) {
            self.init()
            
            self.isMultipleTouchEnabled = false
            self.backgroundColor = self.defaultColor
            self.layer.masksToBounds = true
            
            self.cell = cell
        }
        
        func broadcastSelectionIfNeeded() {
            if shouldBroadcastSelection {
                
                guard let cell = self.cell,
                      let handler = self.selectionHandler else { return }
                guard let indexPath = cell.indexPath else { return }
                
                handler(cell, indexPath)
            }
        }
        
        /*
        func configureAnimator(reversed: Bool = false) -> UIViewPropertyAnimator {
            
            let anim = UIViewPropertyAnimator(duration: 0.10, curve: .easeInOut, animations: {
                
                let factor: CGFloat = (reversed ? 1 : 0.8)
                self.transform = CGAffineTransform(scaleX: factor, y: factor)
            })
            
            anim.addCompletion({ (position) in
                
                self.finalAnim()
            })
            
            return anim
        }
        
        func finalAnim() {
            
             let newAnim = UIViewPropertyAnimator(duration: 0.10, curve: .easeInOut, animations: {
                self.transform = CGAffineTransform(scaleX: 1, y: 1)
             })
            
            
            newAnim.addCompletion({ (pos2) in
                self.broadcastSelectionIfNeeded()
            })
            
            newAnim.startAnimation()
        }
        */
 
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            // print("touchesBegan")
            
            self.forceDidChange = false
            self.shouldBroadcastSelection = true
            
            // self.scaleAnimator = configureAnimator()
        }
        
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            // print("touchesCancelled")
            
            self.shouldBroadcastSelection = false
            
            // self.scaleAnimator?.stopAnimation(true)
            // finalAnim()
        }
        
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            // print("touchesEnded")
            
            // Delete the following two lines if animation is used
            broadcastSelectionIfNeeded()
            return;
            
            /*
            if self.forceDidChange {
                
                self.scaleAnimator?.stopAnimation(true)
                
                finalAnim()
                
            } else {
                
                self.scaleAnimator?.startAnimation()
            }
            */
        }
        
        /*
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            print("touchesMoved")
            
            guard let force = touches.first?.force else { return }
            
            if force > 2.0 {
                forceDidChange = true
            }
            
            self.scaleAnimator?.fractionComplete = force/6.66667
        }
        */
    }
    
}
