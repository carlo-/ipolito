//
//  PTTypes.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 21/06/16.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit
import AVFoundation



// MARK: - PTVideolecture

struct PTVideolecture {
    
    static let udKey = "watchedVideolectures"
    static let durationKey = "duration"
    static let positionKey = "position"
    
    let title: String
    let thumbnailURL: URL
    let videoURL: URL
    let identifier: String
    let date: Date
    
    var lastPositionPlayed: CMTime {
        
        let watchedVids = (UserDefaults().value(forKey: PTVideolecture.udKey) as? [String: Any]) ?? [:]
        let dict = (watchedVids[identifier] as? [String: Any]) ?? [:]
        
        let seconds: Double = (dict[PTVideolecture.positionKey] as? Double) ?? 0.0
        
        return CMTime(seconds: seconds, preferredTimescale: 1)
    }
    
    var duration: CMTime? {
        
        let watchedVids = (UserDefaults().value(forKey: PTVideolecture.udKey) as? [String: Any]) ?? [:]
        let dict = (watchedVids[identifier] as? [String: Any]) ?? [:]
        
        if let seconds = dict[PTVideolecture.durationKey] as? Double {
            return CMTime(seconds: seconds, preferredTimescale: 1)
        } else {
            return nil
        }
    }
    
    func rememberDuration(_ duration: CMTime) {
        
        var watchedVids = UserDefaults().dictionary(forKey: PTVideolecture.udKey) ?? [:]
        var dict = (watchedVids[identifier] as? [String: Any]) ?? [:]
        
        dict[PTVideolecture.durationKey] = duration.seconds
        
        watchedVids[identifier] = dict
        UserDefaults().set(watchedVids, forKey: PTVideolecture.udKey)
    }
    
    func rememberPosition(_ position: CMTime) {
        
        var watchedVids = UserDefaults().dictionary(forKey: PTVideolecture.udKey) ?? [:]
        var dict = (watchedVids[identifier] as? [String: Any]) ?? [:]
        
        dict[PTVideolecture.positionKey] = position.seconds
        
        watchedVids[identifier] = dict
        UserDefaults().set(watchedVids, forKey: PTVideolecture.udKey)
    }
}



// MARK: - PTToken & PTRegisteredID

struct PTToken {
    let stringValue: String
    init(_ token: String) {
        self.stringValue = token
    }
}

struct PTRegisteredID {
    
    let stringValue: String
    
    var isValid: Bool {
        return !stringValue.isEmpty
    }
    
    init(string: String) {
        self.stringValue = string
    }
    
    static func fromUUID() -> PTRegisteredID {
        let uuid = UIDevice.current.identifierForVendor?.uuidString ?? ""
        return PTRegisteredID(string: uuid)
    }
}



// MARK: - PTGrade, PTTemporaryGrade, PTExam

enum PTGrade: Equatable {
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
    
    var rawValue: Int {
        switch self {
        case .passed:
            return 0
        case .honors:
            return 31
        case .numerical(let val):
            return val
        }
    }
}

func ==(lhs: PTGrade, rhs: PTGrade) -> Bool {
    
    switch (lhs, rhs) {
    case (.passed, .passed):
        return true
    case (.honors, .honors):
        return true
    case (.numerical(let lhs_n), .numerical(let rhs_n)):
        return lhs_n == rhs_n
    default:
        return false
    }
}

struct PTTemporaryGrade {
    
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

struct PTExam {
    
    let name: String
    let date: Date
    let credits: Int
    let grade: PTGrade
}



// MARK: - PTMessage

struct PTMessage {
    
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
    
    private static let readMessagesKey = "readMessages"
    
    func setRead(_ read: Bool) {
        
        let ud = UserDefaults()
        let hash = self.hashValue
        
        var hashes: [Int] = (ud.array(forKey: PTMessage.readMessagesKey) as? [Int]) ?? []
        
        if read && !hashes.contains(hash) {
            
            hashes.append(hash)
            
        } else if !read, let index = hashes.index(of: hash) {
            
            hashes.remove(at: index)
            
        } else { return; }
        
        ud.set(hashes, forKey: PTMessage.readMessagesKey)
    }
    
    var isRead: Bool {
        
        let hashes: [Int] = (UserDefaults().array(forKey: PTMessage.readMessagesKey) as? [Int]) ?? []
        
        return hashes.contains(hashValue)
    }
    
    var hashValue: Int {
        return (rawHtml + date.hashValue.description).hashValue
    }
}



// MARK: - PTSubject

struct PTSubject: Hashable {
    
    let name: String
    let incarico: String
    let inserimento: String
    let credits: Int
    
    var hashValue: Int {
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

func ==(lhs: PTSubject, rhs: PTSubject) -> Bool {
    let concatA = "\(lhs.name)\(lhs.incarico)\(lhs.inserimento)"
    let concatB = "\(rhs.name)\(rhs.incarico)\(rhs.inserimento)"
    return concatA == concatB
}



// MARK: - PTTerm

enum PTTerm {
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



// MARK: - PTSubjectData

struct PTSubjectData {
    
    struct Lecturer {
        let firstName: String
        let lastName: String
        
        /// Numerical digits of the lecturerID, excluding the initial letter
        let numericalID: String?
        
        var fullName: String {
            return firstName + " " + lastName
        }
    }
    
    struct Info {
        let year: String
        let lecturer: PTSubjectData.Lecturer
        let term: PTTerm?
    }
    
    struct Guide {
        struct Entry {
            let title, body: String
        }
        let entries: [Entry]
    }
    
    let subject: PTSubject
    
    var messages: [PTMessage]
    var documents: [PTMElement]
    var guide: PTSubjectData.Guide?
    var info: PTSubjectData.Info?
    var videolectures: [PTVideolecture]?
    
    
    private(set) var isValid: Bool = true
    
    init(subject: PTSubject, messages: [PTMessage], documents: [PTMElement], guide: PTSubjectData.Guide?, info: PTSubjectData.Info?, videolectures: [PTVideolecture]?) {
        self.subject = subject
        self.messages = messages
        self.documents = documents
        self.guide = guide
        self.info = info
        self.videolectures = videolectures
    }
    
    var numberOfUnreadMessages: Int {
        return messages.filter({ !($0.isRead) }).count
    }
    
    var numberOfFiles: Int {
        return flatFiles.count
    }
    
    static var invalid: PTSubjectData {
        
        let subject = PTSubject(name: "", incarico: "", inserimento: "", credits: 0)
        var data = PTSubjectData(subject: subject, messages: [], documents: [], guide: nil, info: nil, videolectures: nil)
        data.isValid = false
        return data
    }
    
    var flatDocuments: [PTMElement] {
        return PTMFolder(rawFolderWithChildren: documents).descendantElements
    }
    
    var flatFiles: [PTMFile] {
        return PTMFolder(rawFolderWithChildren: documents).descendantFiles
    }
}



// MARK: - PTLecture

struct PTLecture: Hashable {
    
    let subjectName: String
    let lecturerName: String?
    let roomName: String?
    let eventType: String?
    
    let courseIdentifier: String?
    let lectureIdentifier: String?
    
    let eventDescription: String?
    
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
    
    var hashValue: Int {
        let concat = "\(date.hashValue)\(length)\(subjectName)\(roomName ?? "")\(lectureIdentifier ?? "")\(eventType ?? "")\(eventDescription ?? "")"
        return concat.hashValue
    }
}

func ==(lhs: PTLecture, rhs: PTLecture) -> Bool {
    return lhs.hashValue == rhs.hashValue
}



// MARK: - PTFreeRoom & PTRoom

typealias PTFreeRoom = String

struct PTRoom: Hashable {
    
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
    
    var hashValue: Int {
        let concat = "\(name[.Italian])\(latitude)\(longitude)"
        return concat.hashValue
    }
}

func ==(lhs: PTRoom, rhs: PTRoom) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

extension Sequence where Iterator.Element == PTRoom {
    
    static func fromBundle() -> [PTRoom] {
        
        if let plistPath = Bundle.main.path(forResource: "Rooms", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: plistPath) {
            
            return PTParser.roomsFromRawContainer(dict) ?? []
        } else {
            return []
        }
    }
}



// MARK: - PTMElement & descendants

class PTMElement {
    let description: String
    let identifier: String
    let identifierOfParent: String
    weak var parent: PTMElement?
    
    init(description: String, identifier: String, identifierOfParent: String) {
        self.description = description
        self.identifier = identifier
        self.identifierOfParent = identifierOfParent
    }
    
    var ancestors: [PTMElement] {
        
        guard let p = parent else { return [] }
        return [p] + p.ancestors
    }
    
    var path: String {
        
        let revAncestors = ancestors.reversed()

        let names = revAncestors.map({ $0.description })
        
        if names.isEmpty {
            return "/"
        } else {
            return "/" + names.joined(separator: "/") + "/"
        }
    }
}

class PTMFile: PTMElement {
    
    let date: Date?
    let contentType: String?
    let name: String
    let size: Int?
    
    init(description: String, identifier: String, identifierOfParent: String, date: Date? = nil, contentType: String? = nil, name: String, size: Int? = nil) {
        
        self.date = date
        self.contentType = contentType
        self.name = name
        self.size = size
        
        super.init(description: description, identifier: identifier, identifierOfParent: identifierOfParent)
    }
    
    var `extension`: String? {
    
        if name.contains(".") {
            return name.components(separatedBy: ".").last
        } else {
            return nil
        }
    }
    
    var formattedSize: String? {
        
        guard let size = size else { return nil; }
        let sizeKB = Double(size)
        
        var unit: String = ""
        var val: Double = 0.0
        
        switch size {
        case 0..<1100:
            val = sizeKB
            unit = "KB"
        case 1100..<1100000:
            val = sizeKB / 1000.0
            unit = "MB"
        default:
            val = sizeKB / (1000.0 * 1000.0)
            unit = "GB"
        }
        
        let formatter = NumberFormatter()
        formatter.allowsFloats = true
        formatter.formattingContext = .standalone
        formatter.groupingSeparator = ""
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.minimumIntegerDigits = 1
        formatter.numberStyle = .decimal
        
        if let formattedVal = formatter.string(from: NSNumber(floatLiteral: val)) {
            return formattedVal + unit
        } else {
            return nil
        }
    }
}

class PTMFolder: PTMElement {
    
    private var _descendantElements: [PTMElement]?
    private var _descendantFiles: [PTMFile]?
    
    var children: [PTMElement] = [] {
        didSet {
            _descendantElements = nil
            _descendantFiles = nil
        }
    }
    
    init(description: String, identifier: String, identifierOfParent: String, children: [PTMElement]) {
        self.children = children
        super.init(description: description, identifier: identifier, identifierOfParent: identifierOfParent)
    }
    
    fileprivate init(rawFolderWithChildren children: [PTMElement]) {
        self.children = children
        super.init(description: "", identifier: "", identifierOfParent: "")
    }
    
    var isEmpty: Bool { return children.isEmpty }
    
    var descendantElements: [PTMElement] {
        
        if _descendantElements != nil {
            return _descendantElements!
        }
        
        var flatArray: [PTMElement] = []
        
        for element in children {
            
            flatArray.append(element)
            
            if let folder = element as? PTMFolder {
                
                flatArray += folder.descendantElements
            }
        }
        
        _descendantElements = flatArray
        return flatArray
    }
    
    var descendantFiles: [PTMFile] {
        
        if _descendantFiles != nil {
            return _descendantFiles!
        }
        
        var flatArray: [PTMFile] = []
        
        for element in children {
            
            if let file = element as? PTMFile {
                flatArray.append(file)
            } else if let folder = element as? PTMFolder {
                flatArray += folder.descendantFiles
            }
        }
        
        _descendantFiles = flatArray
        return flatArray
    }
}



// MARK: - PTStudentInfo

struct PTStudentInfo {
    
    var firstName: String?
    var lastName: String?
    
    var fullName: String? {
        
        if firstName != nil && lastName != nil {
            return firstName! + " " + lastName!
        } else {
            return nil
        }
    }
    
    var weightedAverage: Double?
    var cleanWeightedAverage: Double?
    var graduationMark: Double?
    var cleanGraduationMark: Double?
    
    var obtainedCredits: UInt?
    
    /// Total credits of the program
    var totalCredits: UInt?
    
    var academicMajor: String?
}



// MARK: - PTAccount

struct PTAccount {
    
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

func ==(lhs: PTAccount, rhs: PTAccount) -> Bool {
    return lhs.numericalID == rhs.numericalID &&
           lhs.password == rhs.password
}



// MARK: - Others

enum PTLocale {
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

struct PTBasicInfo {
    let studentInfo: PTStudentInfo?
    let subjects: [PTSubject]?
    let passedExams: [PTExam]?
}
