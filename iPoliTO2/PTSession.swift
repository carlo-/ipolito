//
//  PTSessionManager.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 22/06/16.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

enum PTSessionStatus {
    case Unauthenticated
    case Authenticated
    case Unknown
}

protocol PTSessionDelegate {
    func sessionDidFinishOpening()
    func sessionDidFailOpeningWithError(error: PTRequestError)
    
    func sessionDidFinishClosing()
    func sessionDidFailClosingWithError(error: PTRequestError)
    
    func managerDidRetrieveSchedule(schedule: [PTLecture]?)
    func managerDidFailRetrievingScheduleWithError(error: PTRequestError)
    
    func managerDidRetrieveTemporaryGrades(_ temporaryGrades: [PTTemporaryGrade]?)
    func managerDidFailRetrievingTemporaryGradesWithError(error: PTRequestError)
    
    func managerDidRetrieveSubjectData(data: PTSubjectData?, subject: PTSubject)
    func managerDidFailRetrievingSubjectDataWithError(error: PTRequestError, subject: PTSubject)
}

extension PTSessionDelegate {
    func sessionDidFinishOpening() {}
    func sessionDidFailOpeningWithError(error: PTRequestError) {}
    
    func sessionDidFinishClosing() {}
    func sessionDidFailClosingWithError(error: PTRequestError) {}
    
    func managerDidRetrieveSchedule(schedule: [PTLecture]?) {}
    func managerDidFailRetrievingScheduleWithError(error: PTRequestError) {}
    
    func managerDidRetrieveTemporaryGrades(_ temporaryGrades: [PTTemporaryGrade]?) {}
    func managerDidFailRetrievingTemporaryGradesWithError(error: PTRequestError) {}
    
    func managerDidRetrieveSubjectData(data: PTSubjectData?, subject: PTSubject) {}
    func managerDidFailRetrievingSubjectDataWithError(error: PTRequestError, subject: PTSubject) {}
}

class PTSession: NSObject {
    
    var account: PTAccount?
    var delegate: PTSessionDelegate?
    var status: PTSessionStatus = .Unknown
    
    var studentInfo: PTStudentInfo?
    var subjects: [PTSubject]?
    var passedExams: [PTExam]?
    var schedule: [PTLecture]?
    var temporaryGrades: [PTTemporaryGrade]?
    var dataOfSubjects: [PTSubject: PTSubjectData] = [:]
    var shouldLoadTestData: Bool = false
    
    var token: String?
    
    lazy var registeredID: String = {
        
        guard let uuid = UIDevice.current.identifierForVendor?.uuidString else {
            // FIX/ME: What to do in this case?
            // This should never happen to us, but just in case, returning an empty string
            // should result in a 'bad request' response from the server, and the
            // app will present an 'unknown error' alert to the user.
            return ""
        }
        
        return uuid
    }()
    
    lazy var allRooms: [PTRoom] = {
        
        if let plistPath = Bundle.main.path(forResource: "Rooms", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: plistPath) {
            
            return PTParser.roomsFromRawContainer(dict)
        } else {
            return []
        }
    }()
    
    // static let shared = PTSession()
    
    private static var privateShared: PTSession?
    
    static var shared: PTSession {
        
        if let sharedInstance = privateShared {
            return sharedInstance
        } else {
            privateShared = PTSession()
            return privateShared!
        }
    }
    
    class func reset() {
        privateShared = nil
    }
    
    private override init() {
        super.init()
    }
    
    init(account: PTAccount, delegate: PTSessionDelegate) {
        self.account = account
        self.delegate = delegate
    }
    
    func open() {
        
        OperationQueue().addOperation({
            
            if let storedToken = self.storedToken() {
                
                self.sessionStep2(token: storedToken)
                
            } else {
                
                self.status = .Unauthenticated
                self.sessionStep1()
            }
        })
    }
    
    func close() {
        
        guard let token = self.token else {
            self.delegate?.sessionDidFailClosingWithError(error: .InvalidToken)
            return
        }
        
        OperationQueue().addOperation({
            
            PTRequest.performLogout(token: token, regID: self.registeredID, loadTestData: self.shouldLoadTestData, completion: {
                (error: PTRequestError?) in
                
                OperationQueue.main.addOperation({
                
                    if error != nil {
                        self.delegate?.sessionDidFailClosingWithError(error: error!)
                    } else {
                        
                        self.forgetSessionData()
                        self.delegate?.sessionDidFinishClosing()
                    }
                    
                })
            })
        })
    }
    
    func requestTemporaryGrades() {
        
        guard let token = self.token else {
            self.delegate?.managerDidFailRetrievingScheduleWithError(error: .InvalidToken)
            return
        }
        
        OperationQueue().addOperation({
            
            PTRequest.fetchTemporaryGrades(token: token, regID: self.registeredID, loadTestData: self.shouldLoadTestData, completion: {
                (temporaryGrades, error) in
                
                OperationQueue.main.addOperation({
                    
                    if let error = error {
                        
                        self.delegate?.managerDidFailRetrievingTemporaryGradesWithError(error: error)
                        
                    } else {
                        
                        self.temporaryGrades = temporaryGrades
                        self.delegate?.managerDidRetrieveTemporaryGrades(temporaryGrades)
                    }
                    
                })
            })
            
        })
    }
    
    func requestFreeRooms(forDate date: Date? = nil, completion: (([PTFreeRoom]?) -> Void)) {
        
        PTRequest.fetchFreeRooms(date: date ?? Date(), regID: registeredID, loadTestData: shouldLoadTestData, completion: {
            (freeRooms: [PTFreeRoom]?, error: PTRequestError?) in
            
            if error == nil {
                completion(freeRooms)
            } else {
                completion(nil)
            }
            
        })
    }
    
    func requestDownloadURL(forFile file: PTMFile, completion: ((URL?) -> Void)) {
        
        guard let token = self.token else {
            completion(nil)
            return
        }
        
        let code = file.identifier
        
        OperationQueue().addOperation({
            
            PTRequest.fetchLinkForFile(token: token, regID: self.registeredID, fileCode: code, completion: {
                (url, error) in
                
                OperationQueue.main.addOperation({
                    
                    if error == nil {
                        completion(url)
                    } else {
                        completion(nil)
                    }
                })
            })
        })
    }
    
    func requestSchedule(date: Date = Date.init()) {
        
        guard let token = self.token else {
            self.delegate?.managerDidFailRetrievingScheduleWithError(error: .InvalidToken)
            return
        }
        
        OperationQueue().addOperation({
            
            PTRequest.fetchSchedule(date: date, token: token, regID: self.registeredID, loadTestData: self.shouldLoadTestData, completion: {
                (schedule: [PTLecture]?, error: PTRequestError?) in
                
                OperationQueue.main.addOperation({
                
                    if error != nil {
                        
                        self.delegate?.managerDidFailRetrievingScheduleWithError(error: error!)
                        
                    } else {
                        
                        self.schedule = schedule
                        self.delegate?.managerDidRetrieveSchedule(schedule: schedule)
                    }
                })
            })
            
        })
    }
    
    func requestDataForSubjects(subjects: [PTSubject]) {
        
        for subject in subjects {
            requestDataForSubject(subject)
        }
    }
    
    
    
    
    
    private func requestDataForSubject(_ subject: PTSubject) {
        
        guard let token = self.token else {
            self.delegate?.managerDidFailRetrievingSubjectDataWithError(error: .InvalidToken, subject: subject)
            return
        }
        
        OperationQueue().addOperation({
            
            PTRequest.fetchSubjectData(subject: subject, token: token, regID: self.registeredID, loadTestData: self.shouldLoadTestData, completion: {
                (subjectData: PTSubjectData?, error: PTRequestError?) in
                
                OperationQueue.main.addOperation({
                    
                    if error != nil {
                        
                        self.delegate?.managerDidFailRetrievingSubjectDataWithError(error: error!, subject: subject)
                        
                    } else {
                        
                        if subjectData != nil {
                            self.dataOfSubjects[subject] = subjectData!
                        }
                        
                        self.delegate?.managerDidRetrieveSubjectData(data: subjectData, subject: subject)
                    }
                })
            })
            
        })
    }
    
    private func sessionStep1() {
        
        let uuid: UUID = UUID(uuidString: registeredID)!
        
        PTRequest.registerDevice(uuid: uuid, loadTestData: shouldLoadTestData, completion: {
            (error: PTRequestError?) in
            
            PTRequest.performLogin(account: self.account, regID: self.registeredID, loadTestData: self.shouldLoadTestData, completion: {
                (token: String?, studentInfo: PTStudentInfo?, error: PTRequestError?) in
                
                if error != nil {
                    
                    OperationQueue.main.addOperation({
                        self.delegate?.sessionDidFailOpeningWithError(error: error!)
                    })
                    
                } else if token == nil {
                    
                    OperationQueue.main.addOperation({
                        self.delegate?.sessionDidFailOpeningWithError(error: .UnknownError)
                    })
                    
                } else {
                    
                    self.sessionStep2(token: token!)
                }
            })
        })
    }
    
    private func sessionStep2(token: String) {
        
        PTRequest.fetchStudentInfo(token: token, regID: registeredID, loadTestData: shouldLoadTestData, completion: {
            (studentInfo: PTStudentInfo?, subjects: [PTSubject]?, passedExams: [PTExam]?, error: PTRequestError?) in
            
            if error != nil {
                
                self.status = .Unauthenticated
                self.sessionStep1()
                
            } else {
                
                OperationQueue.main.addOperation({
                
                    self.studentInfo = studentInfo
                    self.subjects = subjects
                    self.passedExams = passedExams
                    self.token = token
                    self.status = .Authenticated
                    
                    // Confirm token and account
                    PTKeychain.storeAccount(self.account!)
                    PTKeychain.storeValue(token, ofType: .token)
                    
                    self.delegate?.sessionDidFinishOpening()
                })
            }
        })
    }
    
    private func storedToken() -> String? {
        
        return PTKeychain.retrieveValue(ofType: .token)
    }
    
    private func forgetSessionData() {
        
        PTKeychain.removeAllValues()
        PTDownloadManager.clearDownloadsFolder()
        
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults().removePersistentDomain(forName: bundleIdentifier)
        }
        
        PTSession.reset()
    }
}
