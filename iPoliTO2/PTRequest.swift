//
//  PTRequests.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 22/06/16.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import Foundation

enum PTRequestResult<T> {
    case success(T)
    case failure(PTRequestError)
    
    var isFailure: Bool {
        if case .failure(_) = self {
            return true
        } else {
            return false
        }
    }
    
    var isSuccess: Bool {
        return !isFailure
    }
}

public enum PTRequestError {
    case jsonSerializationFailed
    case unknownError
    case invalidCredentials
    case invalidRequestType
    case invalidToken
    case invalidInputJSON
    case missingParameters
    case cannotResolveURL
    case serverUnreachable
    case timedOut
    case notConnectedToInternet
    
    var localizedDescription: String {
        
        switch (self) {
        case .invalidCredentials:
            return ~"ls.generic.ptRequestError.invalidCredentials"
        case .notConnectedToInternet:
            return ~"ls.generic.ptRequestError.notConnectedToInternet"
        case .serverUnreachable:
            return ~"ls.generic.ptRequestError.serverUnreachable"
        case .timedOut:
            return ~"ls.generic.ptRequestError.timedOut"
        default:
            return ~"ls.generic.ptRequestError.unknown"
        }
    }
    
    init?(fromResponseCode code: Int) {
        
        switch code {
        case -3:
            self = .invalidCredentials
        case -6:
            self = .missingParameters
        case -10:
            self = .invalidRequestType
        case -13:
            self = .cannotResolveURL
        case -33:
            self = .invalidInputJSON
        case 0:
            return nil
        default:
            self = .unknownError
        }
    }
    
    init(fromNSURLErrorCode code: Int) {
        
        switch code {
        case NSURLErrorTimedOut:
            self = .timedOut
        case NSURLErrorNotConnectedToInternet:
            self = .notConnectedToInternet
        case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed:
            self = .serverUnreachable
        default:
            self = .unknownError
        }
    }
}

private enum PTRequestParameter: String {
    case sessionToken =     "token"
    case registeredID =     "regID"
    case fileCode =         "code"
    case incarico =         "incarico"
    case inserimento =      "cod_ins"
    case refDate =          "data_rif"
    case matricola =        "username"
    case password =         "password"
    case roomType =         "local_type"
    case day =              "giorno"
    case time =             "ora"
    case booksPerPage =     "numrec"
    case deviceUUID =       "uuid"
    case devicePlatform =   "device_platform"
    case deviceVersion =    "device_version"
    case deviceModel =      "device_model"
    case deviceManufacturer="device_manufacturer"
}

private enum PTRequestAPI: String {
    case schedule =         "https://app.didattica.polito.it/orari_lezioni.php"
    case studentInfo =      "https://app.didattica.polito.it/studente.php"
    case fileLink =         "https://app.didattica.polito.it/download.php"
    case subjectData =      "https://app.didattica.polito.it/materia_dettaglio.php"
    case examSessions =     "https://app.didattica.polito.it/appelli.php"
    case rooms =            "https://app.didattica.polito.it/sedi.php"
    case freeRooms =        "https://app.didattica.polito.it/aule_libere.php"
    case library =          "https://app.didattica.polito.it/biblioteca.php"
    case login =            "https://app.didattica.polito.it/login.php"
    case logout =           "https://app.didattica.polito.it/logout.php"
    case registerDevice =   "https://app.didattica.polito.it/register.php"
    case temporaryGrades =  "https://app.didattica.polito.it/valutazioni.php"
}

private func performTestRequest(withRawParams rawParams: [PTRequestParameter: String], api: PTRequestAPI, completion: @escaping (PTRequestResult<AnyObject>) -> Void) {
    
    let apiTestKey: String? = {
        
        switch api {
        case .fileLink, .examSessions, .rooms, .library:
            return nil
        case .schedule:
            return "schedule"
        case .studentInfo:
            return "studentInfo"
        case .subjectData:
            
            if let incarico = rawParams[.incarico],
               let inserim = rawParams[.inserimento] {
                return "subjectData."+incarico+inserim
            } else {
                return nil
            }
        
        case .freeRooms:
            return "freeRooms"
        case .temporaryGrades:
            return "temporaryGrades"
        case .login:
            return "login"
        case .logout:
            return "logout"
        case .registerDevice:
            return "register"
        }
    }()
    
    guard apiTestKey != nil else {
        // Error! Bad parameters or not a testable key
        completion(.failure(.invalidRequestType))
        return
    }
    
    guard let jsonURL = Bundle.main.url(forResource: "DemoData", withExtension: "json") else {
        // Error! No test data found
        completion(.failure(.jsonSerializationFailed))
        return
    }
    
    let data: Data
    do {
        data = try Data(contentsOf: jsonURL)
    } catch _ {
        // Error! No test data found
        completion(.failure(.jsonSerializationFailed))
        return
    }
    
    OperationQueue().addOperation {
        
        let randDelay = Double(arc4random()%2000)/1000.0
        Thread.sleep(forTimeInterval: randDelay)
        
        if let testContainer = PTParser.rawContainerFromJSON(data) {
            
            if let apiRawContainer = testContainer.value(forKeyPath: apiTestKey!) as AnyObject? {
                
                completion(.success(apiRawContainer))
            } else {
                // Error! Bad parameters or not a testable key
                completion(.failure(.invalidRequestType))
            }
            
        } else {
            
            // Error! JSON serialization failed
            completion(.failure(.invalidRequestType))
        }
    }
}

private func performRequest(withRawParams rawParams: [PTRequestParameter: String], api: PTRequestAPI, loadTestData: Bool = false, timeout: TimeInterval = 10, completion: @escaping (PTRequestResult<AnyObject>) -> Void) {
    
    if loadTestData {
        performTestRequest(withRawParams: rawParams, api: api, completion: completion)
        return
    }
    
    let url = URL(string: api.rawValue)!
    
    var urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
    
    urlRequest.httpMethod = "POST"
    urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    
    let bodyParams = bodyParametersFromRawDictionary(rawParams)
    
    
    let encodedParams = urlEncodedStringFromDictionary(bodyParams)
    
    urlRequest.httpBody = encodedParams.data(using: String.Encoding.utf8)
    
    let config = URLSessionConfiguration.default
    
    let urlSession = URLSession(configuration: config)
    
    let task = urlSession.dataTask(with: urlRequest, completionHandler: {
        (data, response, error) in
        
        if error == nil {
            
            if let container = PTParser.rawContainerFromJSON(data) {
                
                // print(container)
                
                let ptError: PTRequestError?
                
                if let statusCode = PTParser.statusCodeFromRawContainer(container) {
                    ptError = PTRequestError(fromResponseCode: statusCode)
                } else {
                    ptError = .unknownError
                }
                
                if ptError == nil {
                    completion(.success(container))
                } else {
                    completion(.failure(ptError!))
                }
                
            } else {
                completion(.failure(.jsonSerializationFailed))
            }
            
        } else {
            
            let ptError: PTRequestError
            if let error = error as? NSError {
                ptError = PTRequestError(fromNSURLErrorCode: error.code)
            } else {
                ptError = .unknownError
            }
            
            completion(.failure(ptError))
        }
    })
    
    task.resume()
}

class PTRequest {
    
    class func fetchBasicInfo(token: PTToken, regID: PTRegisteredID, loadTestData: Bool = false, completion: @escaping (PTRequestResult<PTBasicInfo>) -> Void) {
        
        let params: [PTRequestParameter: String] = [.registeredID: regID.stringValue,
                                                    .sessionToken: token.stringValue]
        
        performRequest(withRawParams: params, api: .studentInfo, loadTestData: loadTestData, completion: {
            result in
            
            switch result {
            case .success(let container):
                
                let stInfo = PTParser.studentInfoFromRawContainer(container)
                let subjects = PTParser.subjectsFromRawContainer(container)
                let passedExams = PTParser.passedExamsFromRawContainer(container)
                
                let info = PTBasicInfo(studentInfo: stInfo, subjects: subjects, passedExams: passedExams)
                completion(.success(info))
                
            case .failure(let error):
                
                completion(.failure(error))
            }
        })
    }
    
    class func performLogin(account: PTAccount, regID: PTRegisteredID, loadTestData: Bool = false, completion: @escaping (PTRequestResult<PTToken>) -> Void) {
        
        let params: [PTRequestParameter: String] = [.registeredID: regID.stringValue,
                                                    .matricola: account.studentID,
                                                    .password: account.password]
        performRequest(withRawParams: params, api: .login, loadTestData: loadTestData, completion: {
            result in
            
            switch result {
            case .success(let container):
                
                if let tokenStr = PTParser.sessionTokenFromRawContainer(container) {
                    completion(.success(PTToken(tokenStr)))
                } else {
                    completion(.failure(.jsonSerializationFailed))
                }
                
            case .failure(let error):
                
                completion(.failure(error))
            }
        })
    }
    
    class func performLogout(token: PTToken, regID: PTRegisteredID, loadTestData: Bool = false, completion: @escaping (PTRequestResult<Void>) -> Void) {
        
        let params: [PTRequestParameter: String] = [.registeredID: regID.stringValue,
                                                    .sessionToken: token.stringValue]
        
        performRequest(withRawParams: params, api: .logout, loadTestData: loadTestData, completion: {
            result in
            
            switch result {
            case .success(_):
                completion(.success())
                
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
    
    class func registerDevice(regID: PTRegisteredID, loadTestData: Bool = false, completion: @escaping (PTRequestResult<Void>) -> Void) {
        
        let params: [PTRequestParameter: String] = [.registeredID: regID.stringValue,
                                                    .deviceUUID: regID.stringValue,
                                                    .devicePlatform: "iOS",
                                                    .deviceVersion: ProcessInfo().operatingSystemVersionString,
                                                    .deviceModel: deviceModel(),
                                                    .deviceManufacturer: "Apple"]
        
        performRequest(withRawParams: params, api: .registerDevice, loadTestData: loadTestData, completion: {
            result in
            
            switch result {
            case .success(_):
                completion(.success())
                
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
    
    class func fetchSubjectData(subject: PTSubject, token: PTToken, regID: PTRegisteredID, loadTestData: Bool = false, completion: @escaping (PTRequestResult<PTSubjectData>) -> Void) {
        
        let params: [PTRequestParameter: String] = [.registeredID: regID.stringValue,
                                                    .sessionToken: token.stringValue,
                                                    .incarico: subject.incarico,
                                                    .inserimento: subject.inserimento]
        
        performRequest(withRawParams: params, api: .subjectData, loadTestData: loadTestData, completion: {
            result in
            
            switch result {
            case .success(let container):
                
                if let messages = PTParser.messagesFromRawContainer(container),
                   let documents = PTParser.documentsFromRawContainer(container) {
                    
                    let guide = PTParser.subjectGuideFromRawContainer(container)
                    let info = PTParser.subjectInfoFromRawContainer(container)
                    
                    let subjectData = PTSubjectData(subject: subject,
                                                    messages: messages,
                                                    documents: documents,
                                                    guide: guide,
                                                    info: info)
                    
                    completion(.success(subjectData))
                    
                } else {
                    completion(.failure(.jsonSerializationFailed))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
    
    class func fetchTemporaryGrades(token: PTToken, regID: PTRegisteredID, loadTestData: Bool = false, completion: @escaping (PTRequestResult<[PTTemporaryGrade]>) -> Void) {
        
        let params: [PTRequestParameter: String] = [.registeredID: regID.stringValue,
                                                    .sessionToken: token.stringValue]
        
        performRequest(withRawParams: params, api: .temporaryGrades, loadTestData: loadTestData, completion: {
            result in
            
            switch result {
            case .success(let container):
                
                if let tempGrades = PTParser.temporaryGradesFromRawContainer(container) {
                    completion(.success(tempGrades))
                } else {
                    completion(.failure(.jsonSerializationFailed))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
    
    class func fetchLinkForFile(token: PTToken, regID: PTRegisteredID, fileCode: String, completion: @escaping (PTRequestResult<URL>) -> Void) {
        
        let params: [PTRequestParameter: String] = [.registeredID: regID.stringValue,
                                                    .sessionToken: token.stringValue,
                                                    .fileCode: fileCode]
        
        performRequest(withRawParams: params, api: .fileLink, completion: {
            result in
            
            switch result {
            case .success(let container):
                
                if let link = PTParser.fileLinkFromRawContainer(container) {
                    completion(.success(link))
                } else {
                    completion(.failure(.jsonSerializationFailed))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
    
    class func fetchSchedule(date: Date = Date.init(), token: PTToken, regID: PTRegisteredID, loadTestData: Bool = false, completion: @escaping (PTRequestResult<[PTLecture]>) -> Void) {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.isLenient = false
        dateFormatter.timeZone = TimeZone.Turin
        
        let dateStr = dateFormatter.string(from: date)
        
        let params: [PTRequestParameter: String] = [.registeredID: regID.stringValue,
                                                    .sessionToken: token.stringValue,
                                                    .refDate: dateStr]
        
        performRequest(withRawParams: params, api: .schedule, loadTestData: loadTestData, completion: {
            result in
            
            switch result {
            case .success(let container):
                
                if let schedule = PTParser.scheduleFromRawContainer(container) {
                    completion(.success(schedule))
                } else {
                    completion(.failure(.jsonSerializationFailed))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
    
    class func fetchScheduleNew(date: Date = Date.init(), token: PTToken, regID: PTRegisteredID, loadTestData: Bool = false, completion: @escaping (PTRequestResult<[PTLecture]>) -> Void) {
        
        if loadTestData {
            fetchSchedule(date: date, token: token, regID: regID, loadTestData: true, completion: completion)
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.isLenient = false
        dateFormatter.timeZone = TimeZone.Turin
        
        let dateStr = dateFormatter.string(from: date)
        
        let params: [PTRequestParameter: String] = [.registeredID: regID.stringValue,
                                                    .sessionToken: token.stringValue,
                                                    .refDate: dateStr]
        
        var xmlURL: URL? = nil
        var errorFetchingURL: PTRequestError? = nil
        
        let sem = DispatchSemaphore(value: 0)
        
        performRequest(withRawParams: params, api: .schedule, loadTestData: loadTestData, completion: {
            result in
            
            switch result {
            case .success(let container):
                xmlURL = PTParser.scheduleURLFromRawContainer(container)
                
            case .failure(let error):
                errorFetchingURL = error
            }
            
            sem.signal()
        })
        sem.wait()
        
        if errorFetchingURL != nil {
            
            completion(.failure(errorFetchingURL!))
            
        } else {
            
            guard xmlURL != nil, let xmlString = try? String(contentsOf: xmlURL!, encoding: .utf8) else {
                completion(.failure(.unknownError))
                return;
            }
            
            if let schedule = PTParser.scheduleFromXmlString(xmlString) {
                completion(.success(schedule))
            } else {
                completion(.failure(.jsonSerializationFailed))
            }
        }
    }
    
    class func fetchFreeRooms(date: Date = Date.init(), regID: PTRegisteredID, loadTestData: Bool = false, completion: @escaping (PTRequestResult<[PTFreeRoom]>) -> Void) {
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.Turin
        
        dateFormatter.dateFormat = "dd/MM/yyyy"
        let dayStr = dateFormatter.string(from: date)
        
        dateFormatter.dateFormat = "HH:mm:ss"
        let timeStr = dateFormatter.string(from: date)
        
        let params: [PTRequestParameter: String] = [.registeredID: regID.stringValue, .day: dayStr, .time: timeStr]
        
        performRequest(withRawParams: params, api: .freeRooms, loadTestData: loadTestData, completion: {
            result in
            
            switch result {
            case .success(let container):
                
                if let names = PTParser.namesOfFreeRoomsFromRawContainer(container) {
                    completion(.success(names))
                } else {
                    completion(.failure(.jsonSerializationFailed))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }
}



// MARK: Utilities

private func deviceModel() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
        
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
    return identifier
}

private func bodyParametersFromRawDictionary(_ rawDict: [PTRequestParameter: String]) -> [String: String] {
    
    var strParams = "{"
    
    for (aKey, aVal) in rawDict {
        
        strParams.append("\"\(aKey.rawValue)\":\"\(aVal)\",")
    }
    
    if strParams.hasSuffix(",") {
        strParams = String(strParams.characters.dropLast())
    }
    
    strParams.append("}")
    
    return ["data": strParams]
}

private func urlEncodedStringFromDictionary(_ dict: [String: String]) -> String {
    
    var arr:[String] = []
    
    for (aKey, aVal) in dict {
        
        let cleanKey = aKey.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)
        let cleanVal = aVal.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)
        
        arr.append("\(cleanKey!)=\(cleanVal!)")
    }
    
    return arr.joined(separator: "&")
}
