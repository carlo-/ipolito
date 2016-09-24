//
//  CRTimePicker.swift
//
//  Created by Carlo Rapisarda on 07/08/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

protocol CRTimePickerDelegate {
    func timePickerDidPickDate(picker: CRTimePicker, date: Date)
    func timePickerDidScroll(picker: CRTimePicker, onDate date: Date)
}
extension CRTimePickerDelegate {
    func timePickerDidPickDate(picker: CRTimePicker, date: Date) {}
    func timePickerDidScroll(picker: CRTimePicker, onDate date: Date) {}
}

class CRTimePicker: UIView, UIScrollViewDelegate {
    
    private var subtitleLabel: UILabel?
    private var scrollView: CRTimePickerScrollView?
    private var initialDate: Date?
    var delegate: CRTimePickerDelegate?
    override var tintColor: UIColor! {
        didSet {
            scrollView?.tintColor = tintColor
            subtitleLabel?.textColor = tintColor
            // draw(frame)
        }
    }
    
    convenience init(frame: CGRect, date: Date? = nil) {
        
        self.init(frame: frame)
        self.initialDate = date
    }
    
    class AccessoryView: UIToolbar {
        
        init(frame: CGRect, tintColor: UIColor) {
            super.init(frame: frame)
            backgroundColor = UIColor.clear
            isUserInteractionEnabled = false
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func draw(_ rect: CGRect) {
            
            // Arrow pointing down
            
            let polygonWidth: CGFloat = 14
            let polygonHeight: CGFloat = 7
            
            let polygonFrame = CGRect(x: (rect.width - polygonWidth) / 2.0, y: 0, width: polygonWidth, height: polygonHeight)
            
            let polygonPath = UIBezierPath()
            polygonPath.move(to: CGPoint(x: polygonFrame.origin.x, y: polygonFrame.origin.y)) // Left corner
            polygonPath.addLine(to: CGPoint(x: polygonFrame.origin.x + polygonFrame.width, y: polygonFrame.origin.y)) // Right corner
            polygonPath.addLine(to: CGPoint(x: polygonFrame.origin.x + polygonFrame.width/2.0, y: polygonFrame.origin.y+polygonFrame.height)) // Tip
            polygonPath.close()
            
            tintColor.setFill()
            polygonPath.fill()
            
            
            /*
            // Separator
            
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint.zero)
            linePath.addLine(to: CGPoint(x: rect.width, y: 0))
            
            linePath.lineWidth = 1
            
            /*UIColor.black()*/ tintColor.setStroke()
            linePath.stroke()
             */
        }
    }
    
    override func draw(_ rect: CGRect) {
        
        // Background
        
        let background = UIToolbar(frame: rect)
        addSubview(background)
        
        
        
        // Scroll View
        
        let scrollViewFrame = CGRect(x: 0, y: 11, width: rect.width, height: 50)
        
        scrollView = CRTimePickerScrollView(frame: scrollViewFrame, date: initialDate)
        scrollView?.delegate = self
        scrollView?.tintColor = tintColor
        addSubview(scrollView!)
        
        
        
        // Subtitle
        
        subtitleLabel = UILabel(frame: CGRect(x: 0, y: scrollViewFrame.origin.y+scrollViewFrame.height, width: rect.width, height: 20))
        guard let subtitleLabel = subtitleLabel else { return }
        
        subtitleLabel.textColor = tintColor // UIColor.white()
        subtitleLabel.text = ~"ls.timePicker.subtitle"+" XXXXX"
        
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.sizeToFit()
        
        subtitleLabel.center = CGPoint(x: rect.width/2, y: subtitleLabel.center.y)
        
        addSubview(subtitleLabel)
        
        
        
        // Accessory View
        
        addSubview(AccessoryView(frame: rect, tintColor: tintColor))
        
        
        
        updateSubtitleLabel()
    }
    
    func currentSelection() -> Date {
        
        guard let scrollView = scrollView else {
            return Date()
        }
        
        let portionWidth = scrollView.contentSize.width/3
        let intervalWidth = portionWidth/48
        let relativePosX = Int(scrollView.contentOffset.x + scrollView.frame.width/2) % Int(portionWidth)
        
        var decimal = Float(relativePosX - Int(intervalWidth)/2) / Float(intervalWidth*2)
        if decimal < 0 {
            decimal += 24
        }
        
        let hour = Int(decimal)
        let minute = Int((decimal - Float(hour)) * 60.0)
        
        var cal = Calendar(identifier: Calendar.Identifier.gregorian)
        cal.timeZone = TimeZone.Turin
        
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }
    
    private func updateSubtitleLabel() {
        
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.Turin
        formatter.locale = Locale(identifier: "it-IT")
        
        let selection = currentSelection()
        subtitleLabel?.text = ~"ls.timePicker.subtitle"+" "+formatter.string(from: selection)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        // Patch (since scrollViewDidEndScrollingAnimation is not called as it should)
        // See: http://stackoverflow.com/questions/993280/how-to-detect-when-a-uiscrollview-has-finished-scrolling
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        perform(#selector(scrollViewDidEndScrollingAnimation), with: scrollView, afterDelay: 0.1)
        
        updateSubtitleLabel()
        
        delegate?.timePickerDidScroll(picker: self, onDate: currentSelection())
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        
        // Patch (see scrollViewDidScroll)
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        
        delegate?.timePickerDidPickDate(picker: self, date: currentSelection())
    }
}

private class CRTimePickerScrollView: UIScrollView {
    
    private let pickerContentL: CRTimePickerContentView
    private let pickerContentC: CRTimePickerContentView
    private let pickerContentR: CRTimePickerContentView
    
    override var tintColor: UIColor! {
        didSet {
            pickerContentL.tintColor = tintColor
            pickerContentC.tintColor = tintColor
            pickerContentR.tintColor = tintColor
        }
    }
    
    init(frame: CGRect, date: Date? = nil) {
        
        pickerContentL = CRTimePickerContentView()
        pickerContentC = CRTimePickerContentView()
        pickerContentR = CRTimePickerContentView()
        
        super.init(frame: frame)
        
        
        let portionWidth: CGFloat = 3000
        
        contentSize = CGSize(width: portionWidth*3, height: frame.height)
        backgroundColor = UIColor.clear
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        
        pickerContentL.frame = CGRect(x: 0,              y: 0, width: portionWidth, height: frame.height)
        pickerContentC.frame = CGRect(x: portionWidth,   y: 0, width: portionWidth, height: frame.height)
        pickerContentR.frame = CGRect(x: portionWidth*2, y: 0, width: portionWidth, height: frame.height)
        
        pickerContentL.backgroundColor = UIColor.clear
        pickerContentC.backgroundColor = UIColor.clear
        pickerContentR.backgroundColor = UIColor.clear
        
        addSubview(pickerContentL)
        addSubview(pickerContentC)
        addSubview(pickerContentR)
        
        contentOffset = CGPoint(x: horizontalOffset(forDate: date ?? Date()), y: contentOffset.y)
    }
    
    private func horizontalOffset(forDate date: Date) -> CGFloat {
        
        var cal = Calendar(identifier: Calendar.Identifier.gregorian)
        cal.timeZone = TimeZone.Turin
        
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        
        let decimal = Float(hour)+Float(minute)/60.0
        
        let portionWidth = contentSize.width/3
        let intervalWidth = portionWidth/48
        
        var partialRes = intervalWidth * 2 * CGFloat(decimal)
        partialRes += portionWidth
        partialRes += intervalWidth/2
        partialRes -= frame.width/2
        
        return partialRes
    }
    
    private func recenterIfNecessary() {
        
        let portionWidth = contentSize.width/3
        
        if contentOffset.x < portionWidth {
            
            // We are in the left portion
            
            contentOffset = CGPoint(x: contentOffset.x + portionWidth, y: contentOffset.y)
            
        } else if contentOffset.x > portionWidth*2 {
            
            // We are in the right portion
            
            contentOffset = CGPoint(x: contentOffset.x - portionWidth, y: contentOffset.y)
        }
        
        // Else we are in the central portion
    }
    
    private override func layoutSubviews() {
        super.layoutSubviews()
        
        recenterIfNecessary()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class CRTimePickerContentView: UIView {
    
    private override func draw(_ rect: CGRect) {
        
        let intervalWidth = rect.width/48
        
        for i in 0..<48 {
            
            let xpos = intervalWidth * (0.5 + CGFloat(i))
            
            let hour = i/2
            let minute = i%2 == 0 ? 0 : 30
            let timeLabelWidth = intervalWidth-16
            
            
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone.Turin
            
            let date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
            
            
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone.Turin
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "it-IT")
            
            let timeStr = formatter.string(from: date)
            
            
            let timeLabel = UILabel(frame: CGRect(x: 0, y: 0, width: timeLabelWidth, height: 20))
            timeLabel.text = timeStr
            timeLabel.textColor = tintColor
            timeLabel.adjustsFontSizeToFitWidth = true
            timeLabel.center = CGPoint(x: xpos, y: rect.height/2)
            
            addSubview(timeLabel)
            
            
            let separator = UIBezierPath()
            separator.move(to: CGPoint(x: xpos, y: 0))
            separator.addLine(to: CGPoint(x: xpos, y: (rect.height-timeLabel.frame.height)/2 - 5))
            separator.lineWidth = 1
            
            tintColor.setStroke()
            separator.stroke()
        }
    }
}




