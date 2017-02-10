//
//  PTSession.swift
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
    func sessionDidBeginOpening()
    func sessionDidFinishOpening()
    func sessionDidFailOpeningWithError(error: PTRequestError)
    
    func sessionDidBeginClosing()
    func sessionDidFinishClosing()
    func sessionDidFailClosingWithError(error: PTRequestError)
    
    func sessionDidBeginRetrievingSchedule()
    func sessionDidRetrieveSchedule(schedule: [PTLecture])
    func sessionDidFailRetrievingScheduleWithError(error: PTRequestError)
    
    func sessionDidBeginRetrievingTemporaryGrades()
    func sessionDidRetrieveTemporaryGrades(_ temporaryGrades: [PTTemporaryGrade])
    func sessionDidFailRetrievingTemporaryGradesWithError(error: PTRequestError)
    
    func sessionDidBeginRetrievingSubjectData(subject: PTSubject)
    func sessionDidRetrieveSubjectData(data: PTSubjectData, subject: PTSubject)
    func sessionDidFailRetrievingSubjectDataWithError(error: PTRequestError, subject: PTSubject)
}

extension PTSessionDelegate {
    func sessionDidBeginOpening() {}
    func sessionDidFinishOpening() {}
    func sessionDidFailOpeningWithError(error: PTRequestError) {}
    
    func sessionDidBeginClosing() {}
    func sessionDidFinishClosing() {}
    func sessionDidFailClosingWithError(error: PTRequestError) {}
    
    func sessionDidBeginRetrievingSchedule() {}
    func sessionDidRetrieveSchedule(schedule: [PTLecture]) {}
    func sessionDidFailRetrievingScheduleWithError(error: PTRequestError) {}
    
    func sessionDidBeginRetrievingTemporaryGrades() {}
    func sessionDidRetrieveTemporaryGrades(_ temporaryGrades: [PTTemporaryGrade]) {}
    func sessionDidFailRetrievingTemporaryGradesWithError(error: PTRequestError) {}
    
    func sessionDidBeginRetrievingSubjectData(subject: PTSubject) {}
    func sessionDidRetrieveSubjectData(data: PTSubjectData, subject: PTSubject) {}
    func sessionDidFailRetrievingSubjectDataWithError(error: PTRequestError, subject: PTSubject) {}
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
    
    private(set) var dateOpened: Date?
    
    private(set) var isOpening: Bool = false
    private(set) var isClosing: Bool = false
    
    private(set) var pendingRequests: UInt = 0
    
    var isBusy: Bool {
        return (pendingRequests > 0)
    }
    
    var token: String?
    
    lazy var registeredID: String = {
        
        guard let uuid = UIDevice.current.identifierForVendor?.uuidString else {
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
            
            return PTParser.roomsFromRawContainer(dict) ?? []
        } else {
            return []
        }
    }()
    
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
        
        isOpening = true
        pendingRequests += 1
        self.delegate?.sessionDidBeginOpening()
        
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
        
        isClosing = true
        pendingRequests += 1
        self.delegate?.sessionDidBeginClosing()
        
        // We don't really care about telling the server (given the way PoliTO's APIs work)
        // We simply delete everything and go on
        
        self.forgetSessionData()
        
        self.dateOpened = nil
        self.isClosing = false
        pendingRequests -= 1
        self.delegate?.sessionDidFinishClosing()
        return
        
        // In case we decide to tell the server:
        
        /*
        guard let token = self.token else {
            isClosing = false
            self.delegate?.sessionDidFailClosingWithError(error: .InvalidToken)
            return
        }
        
        OperationQueue().addOperation({
         
            PTRequest.performLogout(token: token, regID: self.registeredID, loadTestData: self.shouldLoadTestData, completion: {
                (error: PTRequestError?) in
                
                OperationQueue.main.addOperation({
                
                    if error != nil {
                        
                        self.isClosing = false
                        self.pendingRequests -= 1
                        self.delegate?.sessionDidFailClosingWithError(error: error!)
                    } else {
                        
                        self.forgetSessionData()
                        
                        self.dateOpened = nil
                        self.isClosing = false
                        self.pendingRequests -= 1
                        self.delegate?.sessionDidFinishClosing()
                    }
                })
            })
        })
         */
    }
    
    func requestTemporaryGrades() {
        
        pendingRequests += 1
        self.delegate?.sessionDidBeginRetrievingTemporaryGrades()
        
        guard let token = self.token else {
            pendingRequests -= 1
            self.delegate?.sessionDidFailRetrievingScheduleWithError(error: .invalidToken)
            return
        }
        
        OperationQueue().addOperation({
            
            PTRequest.fetchTemporaryGrades(token: token, regID: self.registeredID, loadTestData: self.shouldLoadTestData, completion: {
                (temporaryGrades, error) in
                
                OperationQueue.main.addOperation({
                    
                    if let error = error {
                        
                        self.pendingRequests -= 1
                        self.delegate?.sessionDidFailRetrievingTemporaryGradesWithError(error: error)
                        
                    } else {
                        
                        self.temporaryGrades = temporaryGrades
                        
                        self.pendingRequests -= 1
                        
                        if temporaryGrades != nil {
                            self.delegate?.sessionDidRetrieveTemporaryGrades(temporaryGrades!)
                        } else {
                            self.delegate?.sessionDidFailRetrievingTemporaryGradesWithError(error: .jsonSerializationFailed)
                        }
                        
                        
                    }
                    
                })
            })
            
        })
    }
    
    func requestFreeRooms(forDate date: Date? = nil, completion: @escaping (([PTFreeRoom]?, PTRequestError?) -> Void)) {
        
        pendingRequests += 1
        PTRequest.fetchFreeRooms(date: date ?? Date(), regID: registeredID, loadTestData: shouldLoadTestData, completion: {
            (freeRooms: [PTFreeRoom]?, error: PTRequestError?) in
            
            self.pendingRequests -= 1
            completion(freeRooms, error)
        })
    }
    
    func requestDownloadURL(forFile file: PTMFile, completion: @escaping ((URL?) -> Void)) {
        
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
        
        pendingRequests += 1
        self.delegate?.sessionDidBeginRetrievingSchedule()
        
        guard let token = self.token else {
            pendingRequests -= 1
            self.delegate?.sessionDidFailRetrievingScheduleWithError(error: .invalidToken)
            return
        }
        
        OperationQueue().addOperation({
            
            let sem = DispatchSemaphore(value: 0)
            var _schedule: [PTLecture]? = nil
            var _error: PTRequestError? = nil
            
            
            // Try with the regular method (APIs only)
            PTRequest.fetchSchedule(date: date, token: token, regID: self.registeredID, loadTestData: self.shouldLoadTestData, completion: {
                (schedule: [PTLecture]?, error: PTRequestError?) in
                
                _schedule = schedule; _error = error
                sem.signal()
            })
            sem.wait()
            
            
            // Try with the new method (APIs + xml)
            if _schedule == nil {
                _error = nil
                
                PTRequest.fetchScheduleNew(date: date, token: token, regID: self.registeredID, loadTestData: self.shouldLoadTestData, completion: {
                    (schedule: [PTLecture]?, error: PTRequestError?) in
                    
                    _schedule = schedule; _error = error
                    sem.signal()
                })
                sem.wait()
            }
            
            
            OperationQueue.main.addOperation({
                
                if _error != nil {
                    
                    self.pendingRequests -= 1
                    self.delegate?.sessionDidFailRetrievingScheduleWithError(error: _error!)
                    
                } else {
                    
                    self.schedule = _schedule
                    self.pendingRequests -= 1
                    
                    if _schedule != nil {
                        self.delegate?.sessionDidRetrieveSchedule(schedule: _schedule!)
                    } else {
                        self.delegate?.sessionDidFailRetrievingScheduleWithError(error: .jsonSerializationFailed)
                    }
                    
                }
            })
        })
    }
    
    func requestDataForSubjects(subjects: [PTSubject]) {
        
        for subject in subjects {
            requestDataForSubject(subject)
        }
    }
    
    
    
    
    
    func requestDataForSubject(_ subject: PTSubject) {
        
        pendingRequests += 1
        self.delegate?.sessionDidBeginRetrievingSubjectData(subject: subject)
        
        guard let token = self.token else {
            
            pendingRequests -= 1
            self.delegate?.sessionDidFailRetrievingSubjectDataWithError(error: .invalidToken, subject: subject)
            return
        }
        
        OperationQueue().addOperation({
            
            PTRequest.fetchSubjectData(subject: subject, token: token, regID: self.registeredID, loadTestData: self.shouldLoadTestData, completion: {
                (subjectData: PTSubjectData?, error: PTRequestError?) in
                
                OperationQueue.main.addOperation({
                    
                    self.dataOfSubjects[subject] = subjectData ?? PTSubjectData.invalid
                    
                    self.pendingRequests -= 1
                    
                    if error != nil {
                        
                        self.delegate?.sessionDidFailRetrievingSubjectDataWithError(error: error!, subject: subject)
                        
                    } else {
                        
                        if subjectData != nil {
                            self.delegate?.sessionDidRetrieveSubjectData(data: subjectData!, subject: subject)
                        } else {
                            self.delegate?.sessionDidFailRetrievingSubjectDataWithError(error: .jsonSerializationFailed, subject: subject)
                        }
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
                        self.isOpening = false
                        self.pendingRequests -= 1
                        self.delegate?.sessionDidFailOpeningWithError(error: error!)
                    })
                    
                } else if token == nil {
                    
                    OperationQueue.main.addOperation({
                        self.isOpening = false
                        self.pendingRequests -= 1
                        self.delegate?.sessionDidFailOpeningWithError(error: .unknownError)
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
                    
                    self.dateOpened = Date()
                    self.isOpening = false
                    self.pendingRequests -= 1
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
        PTDownloadManager.clearAll()
        
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults().removePersistentDomain(forName: bundleIdentifier)
        }
        
        if let release = Bundle.main.releaseVersionNumber {
            UserDefaults().synchronize()
            UserDefaults().set(release, forKey: kReleaseVersionOfLastExecutionKey)
        }
        
        PTSession.reset()
    }
}

extension PTSession {
    
    func lastUpdateTitleView(title: String) -> UIView? {
        
        guard let lastUpdateDate = self.dateOpened else { return nil; }
        
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.Turin
        formatter.dateFormat = "HH:mm"
        
        let subtitle = ~"ls.generic.status.lastUpdate"+" "+formatter.string(from: lastUpdateDate)
        
        return PTDualTitleView(withTitle: title, subtitle: subtitle)
    }
}
