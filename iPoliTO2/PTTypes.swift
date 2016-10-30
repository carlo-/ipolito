//
//  PTTypes.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 21/06/16.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import Foundation

public enum PTGrade {
    case honors
    case passed
    case numerical(Int)
    
    var shortDescription: String {
        get {
            switch self {
            case .passed:
                return ~"ls.ptGrade.passed.short"
            case .honors:
                return "30L"
            case .numerical(let val):
                return String(val)
            }
        }
    }
}

public struct PTTemporaryGrade {
    
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

public struct PTExam {
    
    let name: String
    let date: Date
    let credits: Int
    let grade: PTGrade
}

public struct PTMessage {
    
    let date: Date
    let rawHtml: String
    
    var plainBody: String {
        return rawHtml.htmlToString
    }
    
    var attributedBody: NSAttributedString? {
        return rawHtml.htmlToAttributedString
    }
    
    var cleanBody: String {
        let clean = plainBody.trimmingWhitespaceAndNewlines()
        
        // Solves a bug that broke text views when trying to display a special char
        let char: Character = "\u{0C}"
        return clean.replacingOccurrences(of: String(char), with: "")
    }
    
    static let readMessagesKey = "readMessages"
    
    func setRead(_ read: Bool) {
        
        let ud = UserDefaults()
        ud.synchronize()
        
        var hashes: [Int] = (ud.array(forKey: PTMessage.readMessagesKey) as? [Int]) ?? []
        
        let hash = self.hashValue
        
        if read && !hashes.contains(hash) {
            
            hashes.append(hash)
            
        } else if !read, let index = hashes.index(of: hash) {
            
            hashes.remove(at: index)
        } else {
            
            return
        }
        
        ud.set(hashes, forKey: PTMessage.readMessagesKey)
    }
    
    var isRead: Bool {
        
        let ud = UserDefaults()
        ud.synchronize()
        
        guard let hashes = ud.array(forKey: PTMessage.readMessagesKey) as? [Int] else {
            return false
        }
        
        return hashes.contains(hashValue)
    }
    
    var hashValue: Int {
        return (rawHtml + date.hashValue.description).hashValue
    }
}

public struct PTLecturer {
    let firstName: String
    let lastName: String
    
    /// Numerical digits of the lecturerID, excluding the initial letter
    let numericalID: String?
    
    var fullName: String {
        return firstName + " " + lastName
    }
}

public struct PTSubject: Hashable {
    
    let name: String
    let incarico: String
    let inserimento: String
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
    }
}

public func ==(lhs: PTSubject, rhs: PTSubject) -> Bool {
    let concatA = "\(lhs.name)\(lhs.incarico)\(lhs.inserimento)"
    let concatB = "\(rhs.name)\(rhs.incarico)\(rhs.inserimento)"
    return concatA == concatB
}

public struct PTSubjectGuide {
    struct Entry {
        let title, body: String
    }
    let entries: [Entry]
}

public enum PTTerm {
    case first
    case second
    case both
    
    init?(fromString string: String) {
        switch string {
        case "1-1":
            self = .first
        case "2-2":
            self = .second
        case "1-2", "2-1":
            self = .both
        default:
            return nil
        }
    }
    
    var localizedDescription: String {
        
        switch self {
        case .first:
            return ~"ls.ptTerm.first"
        case .second:
            return ~"ls.ptTerm.second"
        case .both:
            return ~"ls.ptTerm.both"
        }
    }
}

public struct PTSubjectInfo {
    let year: String
    let lecturer: PTLecturer
    let term: PTTerm?
}

public struct PTSubjectData {
    
    let subject: PTSubject
    
    var lecturers: [PTLecturer]
    var messages: [PTMessage]
    var documents: [PTMElement]
    var guide: PTSubjectGuide?
    var info: PTSubjectInfo?
    
    private(set) var isValid: Bool = true
    
    init(subject: PTSubject, lecturers: [PTLecturer], messages: [PTMessage], documents: [PTMElement], guide: PTSubjectGuide?, info: PTSubjectInfo?) {
        self.subject = subject
        self.lecturers = lecturers
        self.messages = messages
        self.documents = documents
        self.guide = guide
        self.info = info
    }
    
    var numberOfUnreadMessages: Int {
        
        var count = 0
        for mex in messages {
            if !mex.isRead { count += 1 }
        }
        return count
    }
    
    var numberOfFiles: Int {
        return flatFiles.count
    }
    
    static var invalid: PTSubjectData {
        
        let subject = PTSubject(name: "", incarico: "", inserimento: "", credits: 0)
        var data = PTSubjectData(subject: subject, lecturers: [], messages: [], documents: [], guide: nil, info: nil)
        data.isValid = false
        return data
    }
    
    var flatDocuments: [PTMElement] {
        
        let folder = PTMFolder(description: "", identifier: "", identifierOfParent: "", children: documents)
        return folder.descendantElements
    }
    
    var flatFiles: [PTMFile] {
        
        let folder = PTMFolder(description: "", identifier: "", identifierOfParent: "", children: documents)
        return folder.descendantFiles
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


public struct PTLecture: Hashable {
    
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
    
    public var hashValue: Int {
        let concat = "\(date.hashValue)\(length)\(subjectName)\(roomName ?? "")\(lectureIdentifier ?? "")\(detail ?? "")"
        return concat.hashValue
    }
}
public func ==(lhs: PTLecture, rhs: PTLecture) -> Bool {
    return lhs.hashValue == rhs.hashValue
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

protocol PTMElement {
    var description: String { get }
    var identifier: String { get }
    var identifierOfParent: String { get }
}

public struct PTMFile: PTMElement {
    
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
    
    let description: String
    let identifier: String
    let identifierOfParent: String
    
    var children: [PTMElement] = []
    
    var isEmpty: Bool { return children.isEmpty }
    
    var descendantElements: [PTMElement] {
        
        var flatArray: [PTMElement] = []
        
        for element in children {
            
            flatArray.append(element)
            
            if let folder = element as? PTMFolder {
                
                flatArray += folder.descendantElements
            }
        }
        
        return flatArray
    }
    
    var descendantFiles: [PTMFile] {
        
        var flatArray: [PTMFile] = []
        
        for element in children {
            
            if let file = element as? PTMFile {
                flatArray.append(file)
            } else if let folder = element as? PTMFolder {
                flatArray += folder.descendantFiles
            }
        }
        
        return flatArray
    }
}

public struct PTStudentInfo {
    
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
    
    /// Student identifier (matricola), including the initial 's'
    private(set) var studentID: String!
    
    /// Password of the student's account
    private(set) var password: String!
    
    /// Numerical digits of the studentID, excluding the initial 's'
    private(set) var numericalID: String!
    
    
    /// Default init for PTAccount
    ///
    /// - parameter rawStudentID: student identifier (matricola), dirty strings also acceptable
    /// - parameter password:     password of the student's account
    init(rawStudentID: String, password: String) {
        
        let numericalID = computeNumericalID(rawStudentID)
        
        self.numericalID = numericalID
        self.studentID = "s"+numericalID
        self.password = password
    }
    
    
    /// Returns the numerical digits of the studentID
    private func computeNumericalID(_ dirtyID: String) -> String {
        
        let digits = NSCharacterSet.decimalDigits
        
        var numID = ""
        
        for char in dirtyID.unicodeScalars {
            
            if digits.contains(char) {
                
                // append(c: Character) not available anymore for some reason
                numID += String(char)
            }
        }
        
        return numID
    }
}

public func ==(lhs: PTAccount, rhs: PTAccount) -> Bool {
    return lhs.numericalID == rhs.numericalID &&
           lhs.password == rhs.password
}
