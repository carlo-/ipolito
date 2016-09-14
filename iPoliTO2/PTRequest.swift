//
//  PTRequests.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 22/06/16.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import Foundation

public enum PTRequestError {
    case JSONSerializationFailed
    case UnknownStatusCode
    case UnknownError
    case InvalidCredentials
    case InvalidRequestType
    case InvalidToken
    case InvalidInputJSON
    case MissingParameters
    case CannotResolveURL
    case ServerUnreachable
    case TimedOut
    case NotConnectedToInternet
}

private enum PTRequestParameter: String {
    case SessionToken =     "token"
    case RegisteredID =     "regID"
    case FileCode =         "code"
    case Incarico =         "incarico"
    case Inserimento =      "cod_ins"
    case RefDate =          "data_rif"
    case Matricola =        "username"
    case Password =         "password"
    case RoomType =         "local_type"
    case Day =              "giorno"
    case Time =             "ora"
    case BooksPerPage =     "numrec"
    case DeviceUUID =       "uuid"
    case DevicePlatform =   "device_platform"
    case DeviceVersion =    "device_version"
    case DeviceModel =      "device_model"
    case DeviceManufacturer="device_manufacturer"
}

private enum PTRequestAPI: String {
    case Schedule =         "https://app.didattica.polito.it/orari_lezioni.php"
    case StudentInfo =      "https://app.didattica.polito.it/studente.php"
    case FileLink =         "https://app.didattica.polito.it/download.php"
    case SubjectData =      "https://app.didattica.polito.it/materia_dettaglio.php"
    case ExamSessions =     "https://app.didattica.polito.it/appelli.php"
    case Rooms =            "https://app.didattica.polito.it/sedi.php"
    case FreeRooms =        "https://app.didattica.polito.it/aule_libere.php"
    case Library =          "https://app.didattica.polito.it/biblioteca.php"
    case Login =            "https://app.didattica.polito.it/login.php"
    case Logout =           "https://app.didattica.polito.it/logout.php"
    case RegisterDevice =   "https://app.didattica.polito.it/register.php"
    case TemporaryGrades =  "https://app.didattica.polito.it/valutazioni.php"
}

private func performTestRequest(withRawParams rawParams: [PTRequestParameter: String], api: PTRequestAPI, completion: (_ container: AnyObject?, _ error: PTRequestError?) -> Void) {
    
    let apiTestKey: String? = {
        
        switch api {
        case .FileLink, .ExamSessions, .Rooms, .Library:
            return nil
        case .Schedule:
            return "schedule"
        case .StudentInfo:
            return "studentInfo"
        case .SubjectData:
            
            if let incarico = rawParams[.Incarico],
               let inserim = rawParams[.Inserimento] {
                return "subjectData."+incarico+inserim
            } else {
                return nil
            }
        
        case .FreeRooms:
            return "freeRooms"
        case .TemporaryGrades:
            return "temporaryGrades"
        case .Login:
            return "login"
        case .Logout:
            return "logout"
        case .RegisterDevice:
            return "register"
        }
    }()
    
    guard apiTestKey != nil else {
        // Error! Bad parameters or not a testable key
        completion(nil, .InvalidRequestType)
        return
    }
    
    guard let jsonURL = Bundle.main.url(forResource: "TestData", withExtension: "json") else {
        // Error! No test data found
        completion(nil, .JSONSerializationFailed)
        return
    }
    
    let data: Data
    do {
        data = try Data(contentsOf: jsonURL)
    } catch _ {
        // Error! No test data found
        completion(nil, .JSONSerializationFailed)
        return
    }
    
    if let testContainer = PTParser.rawContainerFromJSON(data) {
        
        if let apiRawContainer = testContainer.value(forKeyPath: apiTestKey!) {
            
            // TODO: Implement network delays and errors
            
            completion(apiRawContainer as AnyObject?, nil)
        } else {
            // Error! Bad parameters or not a testable key
            completion(nil, .InvalidRequestType)
            return
        }
    } else {
        
        // Error! JSON serialization failed
        completion(nil, .InvalidRequestType)
        return
    }
}

private func performRequest(withRawParams rawParams: [PTRequestParameter: String], api: PTRequestAPI, loadTestData: Bool = false, timeout: TimeInterval = 10, completion: @escaping (_ container: AnyObject?, _ error: PTRequestError?) -> Void) {
    
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
                
                var myError: PTRequestError? {
                    
                    if let statusCode = PTParser.statusCodeFromRawContainer(container) {
                        
                        switch statusCode {
                        case -3:
                            return .InvalidCredentials
                        case -6:
                            return .MissingParameters
                        case -10:
                            return .InvalidRequestType
                        case -13:
                            return .CannotResolveURL
                        case -33:
                            return .InvalidInputJSON
                        case 0:
                            return nil
                        default:
                            return .UnknownStatusCode
                        }
                    } else { return .UnknownError }
                }
                
                completion(container, myError)
                return
                
            } else {
                
                completion(nil, .JSONSerializationFailed)
                return
            }
            
        } else {
            
            var myError: PTRequestError {
                switch (error as! NSError).code {
                case NSURLErrorTimedOut:
                    return .TimedOut
                case NSURLErrorNotConnectedToInternet:
                    return .NotConnectedToInternet
                case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed:
                    return .ServerUnreachable
                default:
                    return .UnknownError
                }
            }
            
            completion(nil, myError)
            return
        }
    })
    
    task.resume()
    
}

class PTRequest: NSObject {
    
    class func fetchStudentInfo(token: String!, regID: String!, loadTestData: Bool = false, completion: @escaping (_ studentInfo: PTStudentInfo?, _ subjects: [PTSubject]?, _ passedExams: [PTExam]?, _ error: PTRequestError?) -> Void) {
        
        let params: [PTRequestParameter: String] = [.RegisteredID: regID,
                                                    .SessionToken: token]
        
        performRequest(withRawParams: params, api: .StudentInfo, loadTestData: loadTestData, completion: {
            (container: AnyObject?, error: PTRequestError?) in
            
            if error == nil && container != nil {
                
                let stInfo = PTParser.studentInfoFromRawContainer(container!)
                let subjects = PTParser.subjectsFromRawContainer(container!)
                let passedExams = PTParser.passedExamsFromRawContainer(container!)
                
                completion(stInfo, subjects, passedExams, nil)
                
            } else {
                
                completion(nil, nil, nil, error)
            }
        })
        
    }
    
    class func performLogin(account: PTAccount!, regID: String!, loadTestData: Bool = false, completion: @escaping (_ token: String?, _ studentInfo: PTStudentInfo?, _ error: PTRequestError?) -> Void) {
        
        let params: [PTRequestParameter: String] = [.RegisteredID: regID,
                                                    .Matricola: account.studentID,
                                                    .Password: account.password]
        performRequest(withRawParams: params, api: .Login, loadTestData: loadTestData, completion: {
            (container: AnyObject?, error: PTRequestError?) in
            
            if error == nil && container != nil {
                
                let token = PTParser.sessionTokenFromRawContainer(container!)
                let stInfo = PTParser.studentInfoFromRawContainer(container!)
                completion(token, stInfo, nil)
                
            } else {
                
                completion(nil, nil, error)
            }
        })
        
    }
    
    class func performLogout(token: String!, regID: String!, loadTestData: Bool = false, completion: @escaping (_ error: PTRequestError?) -> Void) {
        
        let params: [PTRequestParameter: String] = [.RegisteredID: regID,
                                                    .SessionToken: token]
        
        performRequest(withRawParams: params, api: .Logout, loadTestData: loadTestData, completion: {
            (container: AnyObject?, error: PTRequestError?) in
            
            completion(error)
        })
        
    }
    
    class func registerDevice(uuid: UUID!, loadTestData: Bool = false, completion: @escaping (_ error: PTRequestError?) -> Void) {
        
        let params: [PTRequestParameter: String] = [.RegisteredID: uuid.uuidString,
                                                    .DeviceUUID: uuid.uuidString,
                                                    .DevicePlatform: "iOS",
                                                    .DeviceVersion: ProcessInfo().operatingSystemVersionString,
                                                    .DeviceModel: deviceModel(),
                                                    .DeviceManufacturer: "Apple"]
        
        performRequest(withRawParams: params, api: .RegisterDevice, loadTestData: loadTestData, completion: {
            (container: AnyObject?, error: PTRequestError?) in
            
            completion(error)
        })
        
    }
    
    class func fetchSubjectData(subject: PTSubject!, token: String!, regID: String!, loadTestData: Bool = false, completion: @escaping (_ subjectData: PTSubjectData?, _ error: PTRequestError?) -> Void) {
        
        let params: [PTRequestParameter: String] = [.RegisteredID: regID,
                                                    .SessionToken: token,
                                                    .Incarico: subject.incarico,
                                                    .Inserimento: subject.inserimento]
        
        performRequest(withRawParams: params, api: .SubjectData, loadTestData: loadTestData, completion: {
            (container: AnyObject?, error: PTRequestError?) in
            
            if error == nil && container != nil {
                
                let subjectData: PTSubjectData
                
                if let messages = PTParser.messagesFromRawContainer(container!),
                   let documents = PTParser.documentsFromRawContainer(container!) {
                    
                    subjectData = PTSubjectData(dateFetched: Date.init(),
                                                subject: subject,
                                                lecturers: [],
                                                messages: messages,
                                                documents: documents)
                } else {
                    subjectData = PTSubjectData.invalid
                }
                
                completion(subjectData, nil)
                
            } else {
                
                completion(nil, error)
            }
        })
    }
    
    class func fetchTemporaryGrades(token: String, regID: String, loadTestData: Bool = false, completion: @escaping (_ temporaryGrades: [PTTemporaryGrade]?, _ error: PTRequestError?) -> Void) {
        
        let params: [PTRequestParameter: String] = [.RegisteredID: regID,
                                                    .SessionToken: token]
        
        performRequest(withRawParams: params, api: .TemporaryGrades, loadTestData: loadTestData, completion: {
            (container: AnyObject?, error: PTRequestError?) in
            
            if error == nil && container != nil {
                
                let tempGrades = PTParser.temporaryGradesFromRawContainer(container)
                completion(tempGrades, nil)
                
            } else {
                completion(nil, error)
            }
        })
        
    }
    
    class func fetchLinkForFile(token: String!, regID: String!, fileCode: String!, completion: @escaping (_ link: URL?, _ error: PTRequestError?) -> Void) {
        
        let params: [PTRequestParameter: String] = [.RegisteredID: regID,
                                                    .SessionToken: token,
                                                    .FileCode: fileCode]
        
        performRequest(withRawParams: params, api: .FileLink, completion: {
            (container: AnyObject?, error: PTRequestError?) in
            
            if error == nil && container != nil {
                
                let link = PTParser.fileLinkFromRawContainer(container!)
                completion(link, nil)
                
            } else {
                
                completion(nil, error)
            }
        })
        
    }
    
    class func fetchSchedule(date: Date = Date.init(), token: String, regID: String, loadTestData: Bool = false, completion: @escaping (_ schedule: [PTLecture]?, _ error: PTRequestError?) -> Void) {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.isLenient = false
        dateFormatter.timeZone = TimeZone.Turin //(name: "Europe/Rome")
        
        let dateStr = dateFormatter.string(from: date)
        
        let params: [PTRequestParameter: String] = [.RegisteredID: regID,
                                                    .SessionToken: token,
                                                    .RefDate: dateStr]
        
        performRequest(withRawParams: params, api: .Schedule, loadTestData: loadTestData, completion: {
            (container: AnyObject?, error: PTRequestError?) in
            
            if error == nil && container != nil {
                
                let schedule = PTParser.scheduleFromRawContainer(container!)
                completion(schedule, nil)
                
            } else {
                
                completion(nil, error)
            }
            
        })
        
    }
    
    class func fetchFreeRooms(date: Date = Date.init(), regID: String, loadTestData: Bool = false, completion: @escaping (_ freeRooms: [PTFreeRoom]?, _ error: PTRequestError?) -> Void) {
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone.Turin // (name: "Europe/Rome")
        
        dateFormatter.dateFormat = "dd/MM/yyyy"
        let dayStr = dateFormatter.string(from: date)
        
        dateFormatter.dateFormat = "HH:mm:ss"
        let timeStr = dateFormatter.string(from: date)
        
        let params: [PTRequestParameter: String] = [.RegisteredID: regID, .Day: dayStr, .Time: timeStr]
        
        performRequest(withRawParams: params, api: .FreeRooms, loadTestData: loadTestData, completion: {
            (container: AnyObject?, error: PTRequestError?) in
            
            if error == nil && container != nil {
                
                let names = PTParser.namesOfFreeRoomsFromRawContainer(container!)
                completion(names, nil)
                
            } else {
                
                completion(nil, error)
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
        
        // Note: comma in the guard statement used to be a 'where' before Xcode 8 b6
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
