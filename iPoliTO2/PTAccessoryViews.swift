//
//  PTAccessoryViews.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 13/09/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

class PTSimpleTableBackgroundView: UIView {
    
    private let label: UILabel
    
    init(frame: CGRect, title: String) {
        
        label = UILabel()
        
        super.init(frame: frame)
        
        backgroundColor = UIColor.clear
        
        label.font = UIFont.systemFont(ofSize: 15.0)
        label.textColor = UIColor.lightGray
        label.text = title
        label.sizeToFit()
        
        addSubview(label)
    }
    
    private override init(frame: CGRect) {
        label = UILabel()
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        label.center = CGPoint(x: frame.width/2.0, y: frame.height/2.0)
    }
    
}

class PTLoadingTableBackgroundView: UIView {
    
    private let stack: UIStackView
    
    init(frame: CGRect, title: String?) {
        
        stack = UIStackView()
        
        super.init(frame: frame)
        
        backgroundColor = UIColor.clear
        
        
        let stackSpacing: CGFloat = 10
        
        stack.axis = .horizontal
        stack.spacing = stackSpacing
        
        
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 20))
        
        label.font = UIFont.systemFont(ofSize: 15.0)
        label.textColor = UIColor.lightGray
        label.text = title
        label.sizeToFit()
        
        
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        indicator.color = UIColor.lightGray
        indicator.startAnimating()
        
        
        let stackWidth = label.frame.width + indicator.frame.width + stackSpacing
        
        stack.frame = CGRect(x: 0, y: 0, width: stackWidth, height: 20)
        
        stack.addArrangedSubview(indicator)
        stack.addArrangedSubview(label)
        
        addSubview(stack)
    }
    
    convenience override init(frame: CGRect) {
        
        self.init(frame: frame, title: ~"ls.generic.status.loading")
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        stack.center = CGPoint(x: frame.width/2.0, y: frame.height/2.0)
    }
}

func PTLoadingTitleView(withTitle title: String) -> UIView {
    
    let loadingLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 20))
    loadingLabel.text = title
    loadingLabel.font = UIFont.boldSystemFont(ofSize: 16.0)
    loadingLabel.textColor = UIColor.iPoliTO.darkGray
    loadingLabel.sizeToFit()
    
    let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    indicator.color = UIColor.iPoliTO.darkGray
    indicator.startAnimating()
    
    let stack = UIStackView(arrangedSubviews: [indicator, loadingLabel])
    stack.axis = .horizontal
    stack.distribution = .fillProportionally
    stack.spacing = 10.0
    
    let stackWidth = loadingLabel.frame.width+stack.spacing+indicator.frame.width
    
    stack.frame = CGRect(x: 0, y: 0, width: stackWidth, height: 20)
    
    return stack
}

func PTDualTitleView(withTitle title: String, subtitle: String) -> UIView {
    
    let titleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 20))
    titleLabel.text = title
    titleLabel.font = UIFont.boldSystemFont(ofSize: 16.0)
    titleLabel.textAlignment = .center
    titleLabel.textColor = UIColor.iPoliTO.darkGray
    titleLabel.sizeToFit()
    
    let subtitleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 12))
    subtitleLabel.text = subtitle
    subtitleLabel.font = UIFont.systemFont(ofSize: 10.0)
    subtitleLabel.textAlignment = .center
    subtitleLabel.textColor = UIColor.iPoliTO.darkGray
    subtitleLabel.sizeToFit()
    
    let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
    stack.axis = .vertical
    
    let stackWidth: CGFloat = {
        if titleLabel.frame.width > subtitleLabel.frame.width {
            return titleLabel.frame.width
        } else {
            return subtitleLabel.frame.width
        }
    }()
    
    stack.frame = CGRect(x: 0, y: 0, width: stackWidth, height: 32)
    
    return stack
}
