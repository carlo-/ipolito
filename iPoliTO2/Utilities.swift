//
//  Utilities.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 30/06/16.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

extension DateFormatter {
    
    func relativeDateString(from date: Date) -> String? {
        
        let _doesRelativeDateFormatting = doesRelativeDateFormatting
        let _timeStyle = timeStyle
        let _dateStyle = dateStyle
        
        timeStyle = .none
        dateStyle = .long
        
        doesRelativeDateFormatting = false
        let absForm = string(from: date)
        
        doesRelativeDateFormatting = true
        let relForm = string(from: date)
        
        doesRelativeDateFormatting = _doesRelativeDateFormatting
        timeStyle = _timeStyle
        dateStyle = _dateStyle
        
        if absForm.uppercased() == relForm.uppercased() {
            return nil
        } else {
            return relForm
        }
    }
}

public prefix func ~ (key: String) -> String {
    return NSLocalizedString(key, comment: "No Comment")
}

func delay(_ delay:Double, closure:@escaping ()->()) {
    let when = DispatchTime.now() + delay
    DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
}

extension NSString {
    
    var unsignedValue: UInt {
        return UInt(integerValue)
    }
}

extension Sequence where Iterator.Element == (key: String, value: AnyObject) {
    
    func descriptiveCopy() -> [String: NSString?] {
        
        var newDict: [String: NSString] = [:]
        
        for (key, val) in self {
            newDict[key] = val.description as NSString?
        }
        
        return newDict
    }
}

enum PTViewControllerStatus {
    case offline
    case fetching
    case logginIn
    case error
    case ready
    case loggedOut
}

extension Bundle {
    
    var releaseVersionNumber: String? {
        return self.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return self.infoDictionary?["CFBundleVersion"] as? String
    }
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

func simpleDeviceLanguage() -> String? {
    if let preferredLanguage = Locale.preferredLanguages.first {
        return preferredLanguage.components(separatedBy: "-").first
    } else {
        return nil
    }
}

/// Mon = 0, Tue = 1, ...
func italianWeekday(fromDate date: Date) -> Int {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone.Turin
    let weekday = cal.component(.weekday, from: date) - 2
    return (weekday >= 0 ? weekday : 6)
}
