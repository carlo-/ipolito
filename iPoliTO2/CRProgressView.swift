//
//  CRProgressView.swift
//
//  Created by Carlo Rapisarda on 04/03/2017.
//  Copyright © 2017 crapisarda. All rights reserved.
//

import UIKit

class CRProgressView: UIView {
    
    @IBInspectable
    var lineWidth: CGFloat = 2.0 {
        didSet { draw(frame) }
    }
    
    @IBInspectable
    var negative: Bool = false {
        didSet { draw(frame) }
    }
    
    @IBInspectable
    var progress: Double = 0.0 {
        didSet {
            progress = max(min(progress, 1.0), 0.0)
            draw(frame)
        }
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        layer.sublayers?.removeAll()
        
        backgroundColor = .clear
        
        let outerRadius = rect.width/2
        let centralRadius = outerRadius - (lineWidth/2)
        let sliceRadius = centralRadius/2
        
        let center = CGPoint(x: rect.width/2, y: rect.height/2)
        
        
        let circlePath = UIBezierPath(arcCenter: center,
                                      radius: centralRadius,
                                      startAngle: CGFloat(0),
                                      endAngle: CGFloat(M_PI * 2),
                                      clockwise: true)
        
        let circleShape = CAShapeLayer()
        circleShape.path = circlePath.cgPath
        
        circleShape.fillColor = UIColor.clear.cgColor
        circleShape.strokeColor = tintColor.cgColor
        circleShape.lineWidth = lineWidth
        
        layer.addSublayer(circleShape)
        
        
        let slicePath = UIBezierPath(arcCenter: center,
                                     radius: sliceRadius,
                                     startAngle: CGFloat(-M_PI_2),
                                     endAngle: CGFloat(-(M_PI * 5/2) + (M_PI * 1.99999 * progress)),
                                     clockwise: !negative)
        
        let sliceShape = CAShapeLayer()
        sliceShape.path = slicePath.cgPath
        
        sliceShape.fillColor = UIColor.clear.cgColor
        sliceShape.strokeColor = tintColor.cgColor
        sliceShape.lineWidth = centralRadius
        
        layer.addSublayer(sliceShape)
    }
}
