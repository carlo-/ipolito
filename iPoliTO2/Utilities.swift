//
//  Utilities.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/06/16.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

public prefix func ~ (key: String) -> String {
    return NSLocalizedString(key, comment: "No Comment")
}

extension UIColor {
    struct iPoliTO {
        static let darkGray = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        private init() {}
    }
}

extension String {
    func trimmingWhitespaceAndNewlines() -> String {
        return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    mutating func trimWhitespaceAndNewlines() {
        self = self.trimmingWhitespaceAndNewlines()
    }
    var htmlToAttributedString: NSAttributedString? {
        guard let data = data(using: String.Encoding.utf8) else { return nil }
        do {
            return try NSAttributedString(data: data, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute: String.Encoding.utf8.rawValue], documentAttributes: nil)
        } catch let error as NSError {
            print(error.localizedDescription)
            return  nil
        }
    }
    var htmlToString: String {
        return htmlToAttributedString?.string ?? ""
    }
}

extension TimeZone {
    static let Turin = TimeZone(identifier: "Europe/Rome")!
}

extension UIImage {
    struct iPoliTO {
        static func icon(forFileWithExtension ext: String?) -> UIImage {
            
            guard let ext = ext else {
                return UIImage(named: "docType_generic")!
            }
            
            let len = ext.characters.count
            if len == 0 || len > 4 {
                return UIImage(named: "docType_generic")!
            }
            
            let knownExts = ["7z","aac","ai","avi",
                             "cvs","dmg","doc","epub",
                             "exe","flv","gif","html",
                             "jpg","mov","pdf","png",
                             "ppt","psd","rar","tif",
                             "txt","wav","zip"]
            
            if knownExts.contains(ext) {
                return UIImage(named: "docType_\(ext)")!
            } else if ext == "jpeg" {
                return UIImage(named: "docType_jpg")!
            } else if ext == "tiff" {
                return UIImage(named: "docType_tif")!
            } else {
                return UIImage(named: "docType_generic")!
            }
        }
        private init() {}
    }
}

/// Mon = 0, Tue = 1, ...
func italianWeekday(fromDate date: Date) -> Int {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone.Turin
    let weekday = cal.component(.weekday, from: date) - 2
    return (weekday >= 0 ? weekday : 6)
}

func PTLoadingTitleView(withTitle title: String) -> UIView {
    
    let loadingLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 20))
    loadingLabel.text = title
    loadingLabel.font = UIFont.boldSystemFont(ofSize: 16.0)
    loadingLabel.textColor = UIColor.black
    loadingLabel.sizeToFit()
    
    let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
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
    titleLabel.textColor = UIColor.black
    titleLabel.sizeToFit()
    
    let subtitleLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 12))
    subtitleLabel.text = subtitle
    subtitleLabel.font = UIFont.systemFont(ofSize: 10.0)
    subtitleLabel.textAlignment = .center
    subtitleLabel.textColor = UIColor.black
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
