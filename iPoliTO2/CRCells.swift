//
//  CRCells.swift
//
//  Created by Carlo Rapisarda on 28/06/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

public class CRTableViewCell: UITableViewCell {
    
    public var cornerRadius: CGFloat {
        get { return roundedView.layer.cornerRadius }
        set { roundedView.layer.cornerRadius = newValue }
    }
    public var borderWidth: CGFloat {
        get { return roundedView.layer.borderWidth }
        set { roundedView.layer.borderWidth = newValue }
    }
    public var borderColor: CGColor? {
        get { return roundedView.layer.borderColor }
        set { roundedView.layer.borderColor = newValue }
    }
    public var shadowOpacity: Float {
        get { return contentView.layer.shadowOpacity }
        set { contentView.layer.shadowOpacity = newValue }
    }
    public var shadowRadius: CGFloat {
        get { return contentView.layer.shadowRadius }
        set { contentView.layer.shadowRadius = newValue }
    }
    public var shadowOffset: CGSize {
        get { return contentView.layer.shadowOffset }
        set { contentView.layer.shadowOffset = newValue }
    }
    public var shadowPath: CGPath? {
        get { return contentView.layer.shadowPath }
        set { contentView.layer.shadowPath = newValue }
    }
    public var shadowColor: CGColor? {
        get { return contentView.layer.shadowColor }
        set { contentView.layer.shadowColor = newValue }
    }
    public var horizontalMarginsWidth: CGFloat = 18.0
    public var verticalMarginsHeight: CGFloat = 10.0
    
    private var roundedView: UIView = UIView()
    
    public var childView: UIView? {
        didSet {
            let s = roundedView.subviews
            for v in s { v.removeFromSuperview() }
            
            childView?.translatesAutoresizingMaskIntoConstraints = true
            
            if childView != nil {
                childView!.frame = roundedView.bounds
                roundedView.addSubview(childView!)
            }
        }
    }
    
    override public func draw(_ rect: CGRect) {
        
        if !(contentView.subviews.contains(roundedView)) {
            contentView.addSubview(roundedView)
        }
        
        layer.masksToBounds = false
        
        contentView.layer.masksToBounds = false
        contentView.layer.contentsScale = UIScreen.main.scale
        contentView.layer.rasterizationScale = UIScreen.main.scale
        contentView.layer.shouldRasterize = true
        
        roundedView.layer.masksToBounds = true
        
        let clippedRect = CGRect(x: rect.origin.x + horizontalMarginsWidth/2.0,
                                 y: rect.origin.y + verticalMarginsHeight/2.0,
                                 width: rect.size.width - horizontalMarginsWidth,
                                 height: rect.size.height - verticalMarginsHeight)
        
        roundedView.frame = clippedRect
        childView?.frame = roundedView.bounds
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        backgroundColor = UIColor.clear
        contentView.backgroundColor = UIColor.clear
        roundedView.backgroundColor = UIColor.clear
    }
}

public class CRCollectionViewCell: UICollectionViewCell {
    
    public var cornerRadius: CGFloat {
        get { return roundedView.layer.cornerRadius }
        set { roundedView.layer.cornerRadius = newValue }
    }
    public var borderWidth: CGFloat {
        get { return roundedView.layer.borderWidth }
        set { roundedView.layer.borderWidth = newValue }
    }
    public var borderColor: CGColor? {
        get { return roundedView.layer.borderColor }
        set { roundedView.layer.borderColor = newValue }
    }
    public var shadowOpacity: Float {
        get { return contentView.layer.shadowOpacity }
        set { contentView.layer.shadowOpacity = newValue }
    }
    public var shadowRadius: CGFloat {
        get { return contentView.layer.shadowRadius }
        set { contentView.layer.shadowRadius = newValue }
    }
    public var shadowOffset: CGSize {
        get { return contentView.layer.shadowOffset }
        set { contentView.layer.shadowOffset = newValue }
    }
    public var shadowPath: CGPath? {
        get { return contentView.layer.shadowPath }
        set { contentView.layer.shadowPath = newValue }
    }
    public var shadowColor: CGColor? {
        get { return contentView.layer.shadowColor }
        set { contentView.layer.shadowColor = newValue }
    }
    
    private var roundedView: UIView = UIView()
    
    public var childView: UIView? {
        didSet {
            let s = roundedView.subviews
            for v in s { v.removeFromSuperview() }
            
            childView?.translatesAutoresizingMaskIntoConstraints = true
            
            if childView != nil {
                childView!.frame = roundedView.frame
                roundedView.addSubview(childView!)
            }
        }
    }
    
    override public func draw(_ rect: CGRect) {
        
        if !(contentView.subviews.contains(roundedView)) {
            contentView.addSubview(roundedView)
        }
        
        layer.masksToBounds = false
        
        contentView.layer.masksToBounds = false
        contentView.layer.contentsScale = UIScreen.main.scale
        contentView.layer.rasterizationScale = UIScreen.main.scale
        contentView.layer.shouldRasterize = true
        
        roundedView.layer.masksToBounds = true
        roundedView.frame = rect
        
        childView?.frame = rect
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        backgroundColor = UIColor.clear
        contentView.backgroundColor = UIColor.clear
        roundedView.backgroundColor = UIColor.clear
    }
}

