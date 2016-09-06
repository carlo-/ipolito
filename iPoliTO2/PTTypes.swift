//
//  PTTypes.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 21/06/16.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import Foundation

protocol PTFetchedItem {
    var dateFetched: Date! { get set }
}

public enum PTGrade {
    case Honors
    case Passed
    case Numerical(Int)
    
    var shortDescription: String {
        get {
            switch self {
            case .Passed:
                return ~"pass"
            case .Honors:
                return ~"30L"
            case .Numerical(let val):
                return String(val)
            }
        }
    }
}

public struct PTTemporaryGrade: PTFetchedItem {
    var dateFetched: Date!
    
    let subjectName: String
    let absent: Bool
    
    /// Codice Inserimento
    let subjectCode: String
    
    let date: Date
    let failed: Bool
    let state: String
    let grade: PTGrade?
    let message: String?
    
    /// Matricola Docente
    let lecturerID: String
}

public struct PTExam: PTFetchedItem {
    var dateFetched: Date!
    
    let name: String
    let date: Date
    let credits: Int
    let grade: PTGrade
    
    /*
    var gradeShortDescription: String {
        
        switch grade {
        case .Passed:
            return ~"pass"
        case .Honors:
            return ~"30L"
        default:
            return String(grade)
        }
    }
    */
}

public struct PTMessage: PTFetchedItem {
    var dateFetched: Date!
    
    let date: Date!
    let rawHtml: String!
    
    var plainBody: String {
        return rawHtml.htmlToString
    }
    
    var attributedBody: NSAttributedString? {
        return rawHtml.htmlToAttributedString
    }
    
    var cleanBody: String {
        return plainBody.trimmingWhitespaceAndNewlines()
    }
}

public struct PTLecturer {
    let firstName: String!
    let lastName: String!
    
    var fullName: String {
        return firstName + " " + lastName
    }
}

public struct PTSubject: PTFetchedItem, Hashable {
    var dateFetched: Date!
    
    let name: String
    let incarico: String
    let inserimento: String
    let initials: String
    let credits: Int
    
    public var hashValue: Int {
        let concat = "\(name)\(incarico)\(inserimento)"
        return concat.hashValue
    }
    
    init(name: String, incarico: String, inserimento: String, credits: Int) {
        self.name = name
        self.incarico = incarico
        self.inserimento = inserimento
        self.credits = credits
        self.dateFetched = Date()
        self.initials = PTSubject.initialsFromName(name)
    }
    
    static func initialsFromName(_ subjectName: String) -> String {
        var str = ""
        let comps = subjectName.components(separatedBy: " ")
        for sub in comps {
            
            let sub_up = sub.uppercased()
            if sub_up == "I" || sub_up == "II" || sub_up == "III" || sub_up == "IV" || sub_up == "V" {
                str.append(" "+sub_up)
                continue
            }
            
            if sub.characters.count < 4 { continue }
            str.append(sub.characters.first!)
        }
        return str.uppercased()
    }
    
    static func abbreviationFromName(_ subjectName: String) -> String {
        
        var strComps: [String] = []
        let comps = subjectName.components(separatedBy: " ")
        for sub in comps {
            
            let sub_up = sub.uppercased()
            if sub_up == "I" || sub_up == "II" || sub_up == "III" || sub_up == "IV" || sub_up == "V" {
                strComps.append(sub_up)
                continue
            }
            
            if sub.characters.count < 4 { continue }
            strComps.append(abbreviateWord(sub, maxLength: 5).capitalized)
        }
        return strComps.joined(separator: " ")
    }
    
    private static func abbreviateWord(_ word: String, maxLength: Int = 3) -> String {
        
        let wordLen = word.characters.count
        
        if maxLength >= wordLen {
            return word
        }
        if maxLength <= 0 {
            return ""
        }
        if maxLength == 1 {
            return String(word.characters.first ?? Character(""))
        }
        
        var res = ""
        let chars = Array(word.characters)
        
        for i in 0..<(maxLength-1) {
            
            res.append(chars[i])
        }
        
        res.append(".")
        
        return res
    }
}

public func ==(lhs: PTSubject, rhs: PTSubject) -> Bool {
    let concatA = "\(lhs.name)\(lhs.incarico)\(lhs.inserimento)"
    let concatB = "\(rhs.name)\(rhs.incarico)\(rhs.inserimento)"
    return concatA == concatB
}

public struct PTSubjectData: PTFetchedItem {
    var dateFetched: Date!
    
    let subject: PTSubject!
    
    var lecturers: [PTLecturer]! = []
    var messages: [PTMessage]! = []
    var documents: [PTMElement]! = []
    
    init(dateFetched: Date, subject: PTSubject, lecturers: [PTLecturer], messages: [PTMessage], documents: [PTMElement]) {
        self.dateFetched = dateFetched
        self.subject = subject
        self.lecturers = lecturers
        self.messages = messages
        self.documents = documents
    }
    
    var numberOfFiles: Int {
        return self.flatDocuments.flatMap({ $0 as? PTMFile }).count
    }
    
    /*
    lazy var latestChanges: [(Any, Date)] = {
        
        let flatFiles = self.flatDocuments.flatMap({ $0 as? PTMFile })
        
        var changes: [(Any, Date)] = []
        
        for file in flatFiles {
            
            guard let date = file.date else { continue }
            
            if date.timeIntervalSinceNow > -3600*24*7 {
                changes.append((file, date))
            }
        }
        
        for mex in self.messages {
            
            if mex.date.timeIntervalSinceNow > -3600*24*7 {
                changes.append((mex, mex.date))
            }
        }
        
        return changes
    }()
    
    lazy var latestChangesString: String = {
        
        // TO/DO: Rewrite and get ready for localization
        
        let ordered = self.latestChanges.sorted(by: {
            (changeA, changeB) in
            return changeA.1.compare(changeB.1) == ComparisonResult.orderedAscending
        })
        
        var str = ""
        var nmex = 0
        var nfiles = 0
        
        for (item, _) in ordered {
            
            if item is PTMFile {
                
                if (nfiles >= 4) {continue}
                
                let file = item as! PTMFile
                
                str.append("• File \"\(file.name)\" was added.\n")
                
                nfiles += 1
                
            } else if item is PTMessage {
                // let mex = item as! PTMessage
                nmex += 1
            }
        }
        
        if nmex == 0 && nfiles == 0 {
            return "• Nothing new in the past 7 days."
        }
        
        let plural = (nmex == 1 ? "" : "s")
        let nfilesStr = (nmex == 0 ? "No" : "\(nmex)")
        
        return str+"• "+nfilesStr+" new message"+plural+" published."
    }()
    */
 
    var flatDocuments: [PTMElement] {
        var flatArray: [PTMElement] = []
        for elem in self.documents {
            flatArray += self.flatDocuments(forTreeWithRoot: elem)
        }
        return flatArray
    }
    
    private func flatDocuments(forTreeWithRoot root: PTMElement) -> [PTMElement] {
        
        var flatArray: [PTMElement] = [root]
        
        if let folder = root as? PTMFolder {
            
            let children = folder.children
            
            for child in children {
                flatArray += flatDocuments(forTreeWithRoot: child)
            }
        }
        
        return flatArray
    }
}

func simpleDeviceLanguage() -> String? {
    if let preferredLanguage = Locale.preferredLanguages.first {
        return preferredLanguage.components(separatedBy: "-").first
    } else {
        return nil
    }
}

public enum PTLocale {
    case Italian, English
    
    static func preferred() -> PTLocale {
        
        let devLang = simpleDeviceLanguage()
        
        if devLang == "it" {
            return .Italian
        } else {
            return .English
        }
    }
}


public struct PTLecture: PTFetchedItem {
    var dateFetched: Date!
    
    let subjectName: String
    let lecturerName: String?
    let roomName: String?
    let detail: String?
    
    let courseIdentifier: String?
    let lectureIdentifier: String?
    
    let cohort: (from: String, to: String)?
    
    let date: Date
    let length: TimeInterval
    
    var cohortDesctiption: String? {
        if let cohort = cohort {
            return cohort.from + " - " + cohort.to
        } else {
            return nil
        }
    }
    
    /*
    var subtitle: String {
        
        var descr = ""
        
        if roomName != nil {
            descr.append("\(~"Room"): \(roomName)\n")
        }
        
        if lecturerName != nil {
            descr.append("\(lecturerName!.capitalized)\n")
        }
        
        if cohort != nil && courseIdentifier != nil {
            descr.append("\(cohort!.from) - \(cohort!.to) - \(courseIdentifier!)\n")
        }
        
        if detail != nil {
            descr.append("\(detail)\n")
        }
        
        while descr.hasSuffix("\n") {
            descr = String(descr.characters.dropLast())
        }
        
        return descr
    }
    */
}

public typealias PTFreeRoom = String

public struct PTRoom: Hashable {
    
    let name:  [PTLocale: String]
    let floor: [PTLocale: String]
    
    var latitude: Double
    var longitude: Double
    
    var localizedName: String {
        return name[PTLocale.preferred()]!
    }
    
    var localizedFloor: String {
        return floor[PTLocale.preferred()]!
    }
    
    public var hashValue: Int {
        let concat = "\(name[.Italian])\(latitude)\(longitude)"
        return concat.hashValue
    }
}
public func ==(lhs: PTRoom, rhs: PTRoom) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

protocol PTMElement: PTFetchedItem {
    var description: String { get }
    var identifier: String { get }
    var identifierOfParent: String { get }
}

public struct PTMFile: PTMElement {
    var dateFetched: Date!
    
    let description: String
    let identifier: String
    let identifierOfParent: String
    
    let date: Date?
    let contentType: String?
    let name: String
    
    let size: Int?
    
    var `extension`: String? {
    
        if name.contains(".") {
            return name.components(separatedBy: ".").last
        } else {
            return nil
        }
    }
    
}

public struct PTMFolder: PTMElement {
    var dateFetched: Date!
    
    let description: String
    let identifier: String
    let identifierOfParent: String
    
    var children: [PTMElement] = []
    
    var isEmpty: Bool { return children.isEmpty }
}


// PTStudentInfo + PTAccount substitute PTStudent!

public struct PTStudentInfo: PTFetchedItem {
    var dateFetched: Date!
    
    let firstName: String?
    let lastName: String?
    
    var fullName: String? {
        
        if firstName != nil && lastName != nil {
            return firstName! + " " + lastName!
        } else {
            return nil
        }
    }
    
    let weightedAverage: Double?
    let cleanWeightedAverage: Double?
    let graduationMark: Double?
    let cleanGraduationMark: Double?
    
    let obtainedCredits: UInt?
    
    let academicMajor: String?
}

public struct PTAccount {
    let matricola, password: String
    
    /// Returns the numerical digits of the matricola
    func cleanMatricola() -> String {
        
        let digits = NSCharacterSet.decimalDigits
        
        var clean = ""
        
        for char in matricola.unicodeScalars {
            
            if digits.contains(char) {
                
                // FIXME: Append char instead of its description
                // (not possible with the latest Swift version for some reason)
                clean.append(char.description)
            }
        }
        
        return clean
    }
}

public func ==(lhs: PTAccount, rhs: PTAccount) -> Bool {
    return lhs.cleanMatricola() == rhs.cleanMatricola() &&
           lhs.password == rhs.password
}

