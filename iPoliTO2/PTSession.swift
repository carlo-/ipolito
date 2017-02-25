//
//  PTSession.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 22/06/16.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import UIKit

enum PTSessionStatus {
    case unauthenticated
    case authenticated
    case unknown
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
    var status: PTSessionStatus = .unknown
    
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
    
    var isBusy: Bool { return (pendingRequests > 0) }
    
    var token: PTToken?
    
    lazy var registeredID: PTRegisteredID = PTRegisteredID.fromUUID()
    
    lazy var allRooms: [PTRoom] = [PTRoom].fromBundle()
    
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
                
                self.status = .unauthenticated
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
                result in
                
                OperationQueue.main.addOperation({
                    
                    self.pendingRequests -= 1
                    
                    switch result {
                        
                    case .success(let temporaryGrades):
                        self.temporaryGrades = temporaryGrades
                        self.delegate?.sessionDidRetrieveTemporaryGrades(temporaryGrades)
                        
                    case .failure(let error):
                        self.delegate?.sessionDidFailRetrievingTemporaryGradesWithError(error: error)
                    }
                })
            })
        })
    }
    
    func requestFreeRooms(forDate date: Date? = nil, completion: @escaping ((PTRequestResult<[PTFreeRoom]>) -> Void)) {
        
        pendingRequests += 1
        
        PTRequest.fetchFreeRooms(date: date ?? Date(), regID: registeredID, loadTestData: shouldLoadTestData, completion: {
            result in
            
            self.pendingRequests -= 1
            completion(result)
        })
    }
    
    func requestDownloadURL(forFile file: PTMFile, completion: @escaping ((PTRequestResult<URL>) -> Void)) {
        
        guard let token = self.token else {
            completion(.failure(.invalidToken))
            return
        }
        
        OperationQueue().addOperation({
            
            PTRequest.fetchLinkForFile(token: token, regID: self.registeredID, fileCode: file.identifier, completion: {
                result in
                
                OperationQueue.main.addOperation({
                    completion(result)
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
            var result: PTRequestResult<[PTLecture]> = .failure(.unknownError)
            
            
            // Try with the regular method (APIs only)
            PTRequest.fetchSchedule(date: date, token: token, regID: self.registeredID, loadTestData: self.shouldLoadTestData, completion: {
                _result in
                
                result = _result
                sem.signal()
            })
            sem.wait()
            
            
            // Try with the new method (APIs + xml)
            if result.isFailure {
                
                PTRequest.fetchScheduleNew(date: date, token: token, regID: self.registeredID, loadTestData: self.shouldLoadTestData, completion: {
                    _result in
                    
                    result = _result
                    sem.signal()
                })
                sem.wait()
            }
            
            
            OperationQueue.main.addOperation({
                
                self.pendingRequests -= 1
                
                switch result {
                    
                case .success(let schedule):
                    self.schedule = schedule
                    self.delegate?.sessionDidRetrieveSchedule(schedule: schedule)
                    
                case .failure(let error):
                    self.delegate?.sessionDidFailRetrievingScheduleWithError(error: error)
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
                result in
                
                OperationQueue.main.addOperation({
                    
                    self.pendingRequests -= 1
                    
                    switch result {
                        
                    case .success(let subjectData):
                        self.dataOfSubjects[subject] = subjectData
                        self.delegate?.sessionDidRetrieveSubjectData(data: subjectData, subject: subject)
                        
                    case .failure(let error):
                        self.dataOfSubjects[subject] = .invalid
                        self.delegate?.sessionDidFailRetrievingSubjectDataWithError(error: error, subject: subject)
                    }
                })
            })
            
        })
    }
    
    private func sessionStep1() {
        
        PTRequest.registerDevice(regID: registeredID, loadTestData: shouldLoadTestData, completion: { _ in
            
            PTRequest.performLogin(account: self.account!, regID: self.registeredID, loadTestData: self.shouldLoadTestData, completion: {
                result in
                
                switch result {
                    
                case .success(let token):
                    self.sessionStep2(token: token)
                    
                case .failure(let error):
                    
                    OperationQueue.main.addOperation({
                        self.isOpening = false
                        self.pendingRequests -= 1
                        self.delegate?.sessionDidFailOpeningWithError(error: error)
                    })
                }
            })
        })
    }
    
    private func sessionStep2(token: PTToken) {
        
        PTRequest.fetchBasicInfo(token: token, regID: registeredID, loadTestData: shouldLoadTestData, completion: {
            result in
            
            switch result {
                
            case .success(let basicInfo):
                
                OperationQueue.main.addOperation({
                    
                    self.studentInfo = basicInfo.studentInfo
                    self.subjects = basicInfo.subjects
                    self.passedExams = basicInfo.passedExams
                    self.token = token
                    self.status = .authenticated
                    
                    // Confirm token and account
                    PTKeychain.storeAccount(self.account!)
                    PTKeychain.storeValue(token.stringValue, ofType: .token)
                    
                    self.dateOpened = Date()
                    self.isOpening = false
                    self.pendingRequests -= 1
                    self.delegate?.sessionDidFinishOpening()
                })
                
            case .failure(_):
                self.status = .unauthenticated
                self.sessionStep1()
            }
        })
    }
    
    private func storedToken() -> PTToken? {
        
        if let stringToken = PTKeychain.retrieveValue(ofType: .token) {
            return PTToken(stringToken)
        } else {
            return nil
        }
    }
    
    private func forgetSessionData() {
        
        PTKeychain.removeAllValues()
        PTDownloadManager.clearAll()
        
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults().removePersistentDomain(forName: bundleIdentifier)
        }
        
        if let release = Bundle.main.releaseVersionNumber {
            UserDefaults().synchronize()
            UserDefaults().set(release, forKey: PTConstants.releaseVersionOfLastExecutionKey)
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
