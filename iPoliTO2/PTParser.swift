//
//  PTParser.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 22/06/16.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import Foundation

private func rawRoomsFromRawContainer(_ container:AnyObject) -> AnyObject? {
    return container.value(forKeyPath: "data.site") as AnyObject?
}

private func rawPassedExamsFromRawContainer(_ container:AnyObject) -> AnyObject? {
    return container.value(forKeyPath: "data.libretto") as AnyObject?
}

private func rawCaricoDidatticoFromRawContainer(_ container:AnyObject) -> AnyObject? {
    return container.value(forKeyPath: "data.carico_didattico") as AnyObject?
}

private func rawMessagesFromRawContainer(_ container:AnyObject) -> AnyObject? {
    return container.value(forKeyPath: "data.avvisi") as AnyObject?
}

private func rawDocumentsFromRawContainer(_ container:AnyObject) -> AnyObject? {
    return container.value(forKeyPath: "data.materiale") as AnyObject?
}

private func rawScheduleFromRawContainer(_ container:AnyObject) -> AnyObject? {
    return container.value(forKeyPath: "data.orari") as AnyObject?
}

private func rawFileLinkFromRawContainer(_ container:AnyObject) -> AnyObject? {
    return container.value(forKeyPath: "data.url") as AnyObject?
}

private func rawTemporaryGradesFromRawContainer(_ container:AnyObject) -> AnyObject? {
    return container.value(forKeyPath: "data.valutazioni_provvisorie") as AnyObject?
}

private func rawFreeRoomsFromRawContainer(_ container:AnyObject) -> [NSDictionary]? {
    
    if let dict = container.value(forKeyPath: "data.aule_libere") as? [String: [NSDictionary]] {
        
        var freeRooms:[NSDictionary] = []
        
        for (_, someRooms) in dict {
            freeRooms.append(contentsOf: someRooms)
        }
        
        return freeRooms
        
    } else {
        
        return nil
    }
}

private func parsedPTMElementsFromRawFolder(_ rawFolder: [[String: AnyObject]]!) -> [PTMElement] {
    
    
    var elements: [PTMElement] = []
    
    for rawElem in rawFolder {
        
        guard let rawType = rawElem["tipo"] as? String,
        let identifier = rawElem["code"] as? String,
        let identifierOfParent = rawElem["parent_code"] as? String,
        let description = rawElem["descrizione"] as? String
        else { continue }
        
        if rawType.lowercased() == "dir" {
            
            guard let rawChildren = rawElem["files"] as? [[String: AnyObject]]
            else { continue }
            
            let folder = PTMFolder(dateFetched: Date.init(),
                                   description: description,
                                   identifier: identifier,
                                   identifierOfParent: identifierOfParent,
                                   children: parsedPTMElementsFromRawFolder(rawChildren))
            
            elements.append(folder)
            
        } else if rawType.lowercased() == "file" {
            
            guard let name = rawElem["nomefile"] as? String
            else { continue }
            
            let size:Int?
            if let obj = rawElem["size_kb"]?.description {
                size = Int(obj)
            } else { size = nil }
            
            
            var date: Date? = nil
            
            if let rawDate = rawElem["data_ins"] as? String {
                
                let formatter = DateFormatter()
                formatter.timeZone = TimeZone.Turin //(name: "Europe/Rome")
                formatter.isLenient = true
                formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
                    
                date = formatter.date(from: rawDate)
            }
            
            
            let file = PTMFile(dateFetched: Date.init(),
                               description: description,
                               identifier: identifier,
                               identifierOfParent: identifierOfParent,
                               date: date,
                               contentType: rawElem["cont_type"] as? String,
                               name: name,
                               size: size)
            
            elements.append(file)
        }
        
    }
    
    return elements
    
}


class PTParser: NSObject {
    
    class func rawContainerFromJSON(_ data:Data?) -> AnyObject? {
        
        if data == nil {
            return nil
        } else {
            
            let container: AnyObject?
            
            do {
                container = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as AnyObject?
            } catch _ {
                container = nil
            }
            
            return container
        }
        
    }
    
    
    class func sessionTokenFromRawContainer(_ container:AnyObject) -> String? {
        return container.value(forKeyPath: "data.login.token") as? String
    }
    
    
    class func statusCodeFromRawContainer(_ container: AnyObject) -> Int? {
        
        if let rawValue = container.value(forKeyPath: "esito.generale.stato") as AnyObject? {
            
            return Int(rawValue.description)
        } else {
            
            return nil
        }
    }
    
    
    class func namesOfFreeRoomsFromRawContainer(_ container: AnyObject) -> [String] {
        
        if let rawFreeRooms = rawFreeRoomsFromRawContainer(container) {
            
            var freeRooms: [String] = []
            
            for rawFreeRoom in rawFreeRooms {
                
                if let name = rawFreeRoom["nome_aula"] as? String {
                    
                    freeRooms.append(name)
                }
            }
            
            return freeRooms
            
        } else {
            return []
        }
    }
    
    
    class func subjectsFromRawContainer(_ container: AnyObject!) -> [PTSubject] {
        
        if let rawCarico = rawCaricoDidatticoFromRawContainer(container) as? [[String: AnyObject]] {
            
            var subjects: [PTSubject] = []
            
            for rawSubject in rawCarico {
                
                guard let name = rawSubject["nome_ins_1"] as? String,
                let incarico = rawSubject["id_inc_1"]?.description,
                let inserimento = rawSubject["cod_ins"]?.description,
                let creditsStr = rawSubject["n_cfe"]?.description
                else { continue }
                
                let credits = (creditsStr as NSString).integerValue
                
                subjects.append(PTSubject(name: name, incarico: incarico, inserimento: inserimento, credits: credits))
            }
            
            return subjects
            
        } else {
            return []
        }
    }
    
    
    class func passedExamsFromRawContainer(_ container: AnyObject!) -> [PTExam] {
        
        if let rawExams = rawPassedExamsFromRawContainer(container) as? [[String: AnyObject]] {
            
            var exams: [PTExam] = []
            
            for rawExam in rawExams {
                
                guard let subjectName = rawExam["nome_ins"] as? String,
                    let rawDate = rawExam["d_esame"] as? String,
                    let rawCredits = rawExam["n_cfe"]?.description,
                    let rawGrade = rawExam["desc_voto"] as? String
                    else { continue }
                
                let formatter = DateFormatter()
                formatter.timeZone = TimeZone.Turin // (name: "Europe/Rome")
                formatter.isLenient = true
                formatter.dateFormat = "dd/MM/yyyy"
                
                guard let date = formatter.date(from: rawDate),
                    let credits = Int(rawCredits)
                    else { continue }
                
                let grade:PTGrade
                if rawGrade.lowercased().contains("sup") {
                    grade = .Passed
                } else if rawGrade.lowercased().contains("l") {
                    grade = .Honors
                } else {
                    grade = .Numerical(Int(rawGrade)!)
                }
                
                let exam = PTExam(dateFetched: Date.init(),
                                  name: subjectName, date: date, credits: credits, grade: grade)
                
                exams.append(exam)
            }
            
            return exams
            
        } else {
            return []
        }
    }
    
    
    class func temporaryGradesFromRawContainer(_ container: AnyObject!) -> [PTTemporaryGrade] {
        
        if let rawGrades = rawTemporaryGradesFromRawContainer(container) as? [[String: AnyObject]] {
            
            var grades: [PTTemporaryGrade] = []
            
            for rawGrade in rawGrades {
                
                guard let absentRawStr = rawGrade["ASSENTE"]?.description,
                    let codeRawStr = rawGrade["COD_INS"]?.description,
                    let dateRawStr = rawGrade["DATA_ESAME"]?.description,
                    let failedRawStr = rawGrade["FALLITO"]?.description,
                    let lecturerIDRawStr = rawGrade["MAT_DOCENTE"]?.description,
                    let nameRawStr = rawGrade["NOME_INS"]?.description,
                    let stateRawStr = rawGrade["STATO"]?.description
                    else { continue }
                
                let messageRawStr = rawGrade["T_MESSAGGIO"]?.description
                
                
                let formatter = DateFormatter()
                formatter.timeZone = TimeZone.Turin //(name: "Europe/Rome")
                formatter.isLenient = true
                formatter.dateFormat = "dd-MM-yyyy"
                
                guard let date = formatter.date(from: dateRawStr)
                else { continue }
                
                let grade:PTGrade?
                
                if let gradeRawStr = rawGrade["VOTO_ESAME"]?.description {
                    
                    if gradeRawStr.lowercased().contains("sup") {
                        grade = .Passed
                    } else if gradeRawStr.lowercased().contains("l") {
                        grade = .Honors
                    } else {
                        grade = .Numerical((gradeRawStr as NSString).integerValue)
                    }
                } else { grade = nil }
                
                
                let tempGrade = PTTemporaryGrade(dateFetched: Date(),
                                             subjectName: nameRawStr,
                                             absent: (absentRawStr.uppercased() != "N"),
                                             subjectCode: codeRawStr,
                                             date: date,
                                             failed: (failedRawStr.uppercased() != "N"),
                                             state: stateRawStr,
                                             grade: grade,
                                             message: messageRawStr,
                                             lecturerID: lecturerIDRawStr)
                
                grades.append(tempGrade)
            }
            
            return grades
            
        } else {
            return []
        }
    }
    
    class func fileLinkFromRawContainer(_ container: AnyObject!) -> URL? {
        
        if let rawLink = rawFileLinkFromRawContainer(container) as? String {
            
            return URL(string: rawLink.appending("&download=yes"))
        } else {
            
            return nil
        }
    }
    
    class func documentsFromRawContainer(_ container: AnyObject!) -> [PTMElement] {
        
        if let rawDocuments = rawDocumentsFromRawContainer(container) as? [[String: AnyObject]] {
            return parsedPTMElementsFromRawFolder(rawDocuments)
        } else {
            return []
        }
    }
    
    
    class func messagesFromRawContainer(_ container: AnyObject!) -> [PTMessage] {
        
        if let rawMessages = rawMessagesFromRawContainer(container) as? [[String: AnyObject]] {
            
            var messages: [PTMessage] = []
            
            for rawMessage in rawMessages {
                
                guard let dateStr = rawMessage["data_inizio"] as? String,
                      let rawHTML = rawMessage["info"] as? String
                else { continue }
                
                let formatter = DateFormatter()
                formatter.timeZone = TimeZone.Turin //(name: "Europe/Rome")
                formatter.isLenient = true
                formatter.dateFormat = "dd/MM/yyyy"
                
                guard let date = formatter.date(from: dateStr)
                else { continue }
                
                let mex = PTMessage(dateFetched: Date.init(),
                                    date: date, rawHtml: rawHTML)
                
                messages.append(mex)
            }
            
            return messages
            
        } else {
            return []
        }
    }
    
    
    class func roomsFromRawContainer(_ container:AnyObject) -> [PTRoom] {
        
        if let rawRooms = rawRoomsFromRawContainer(container) as? [[String: AnyObject]] {
        
            var rooms: [PTRoom] = []
            
            for rawRoom in rawRooms {
                
                guard let latObj = rawRoom["lat"],
                let lonObj = rawRoom["lon"],
                let roomName_it = rawRoom["rm_name"] as? String,
                let roomName_en = rawRoom["rm_name_en"] as? String,
                let floor_it = rawRoom["nome_piano"] as? String,
                let floor_en = rawRoom["nome_piano_en"] as? String
                else { continue }
                
                let lat = Double(latObj.description)!
                let lon = Double(lonObj.description)!
                
                let room = PTRoom(name:  [.Italian: roomName_it, .English: roomName_en],
                                  floor: [.Italian: floor_it, .English: floor_en],
                                  latitude: lat, longitude: lon)
                
                rooms.append(room)
            }
            
            return rooms
            
        } else {
            return []
        }
    }
    
    
    class func scheduleFromRawContainer(_ container:AnyObject) -> [PTLecture] {
        
        if let rawSchedule = rawScheduleFromRawContainer(container) as? [[String: AnyObject]] {
            
            var schedule: [PTLecture] = []
            
            for rawLecture in rawSchedule {
                
                guard let begDateString = rawLecture["ORA_INIZIO"] as? String,
                      let endDateString = rawLecture["ORA_FINE"]   as? String,
                      let subjectName =   rawLecture["TITOLO_MATERIA"] as? String
                else { continue }
                
                let formatter = DateFormatter()
                formatter.timeZone = TimeZone.Turin // (name: "Europe/Rome")
                formatter.isLenient = true
                formatter.dateFormat = "dd/MM/yyyy HH.mm.ss"
                
                guard let begDate = formatter.date(from: begDateString),
                      let endDate = formatter.date(from: endDateString)
                else { continue }
                
                let cohort: (String, String)?
                if let cohortFrom = rawLecture["ALFA_INI"] as? String,
                   let cohortTo = rawLecture["ALFA_FIN"] as? String {
                    cohort = (cohortFrom, cohortTo)
                } else {
                    cohort = nil
                }
                
                let lecture = PTLecture(dateFetched: Date.init(),
                                                 subjectName:       subjectName,
                                                 lecturerName:      rawLecture["NOMINATIVO_AULA"]    as? String,
                                                 roomName:          rawLecture["AULA"]              as? String,
                                                 detail:            rawLecture["TIPOLOGIA_EVENTO"]  as? String,
                                                 courseIdentifier:  rawLecture["NUMCOR"]            as? String,
                                                 lectureIdentifier: rawLecture["ID_EVENTO"]         as? String,
                                                 cohort:            cohort,
                                                 date:              begDate,
                                                 length:            endDate.timeIntervalSince(begDate))
                
                schedule.append(lecture)
            }
            
            return schedule
            
        } else {
            return []
        }
    }
    
    
    class func studentInfoFromRawContainer(_ container:AnyObject) -> PTStudentInfo {
        
        let firstName:String?
        if let obj = container.value(forKeyPath: "data.anagrafica.nome") as? String {
            firstName = obj.capitalized
        } else { firstName = nil }
        
        let lastName:String?
        if let obj = container.value(forKeyPath: "data.anagrafica.cognome") as? String {
            lastName = obj.capitalized
        } else { lastName = nil }
        
        var weightedAverage:Double?
        if let obj = (container.value(forKeyPath: "data.anagrafica.media_complessiva") as AnyObject?)?.description {
            weightedAverage = Double(obj)!/100.0
        } else { weightedAverage = nil }
        
        let cleanWeightedAverage:Double?
        if let obj = (container.value(forKeyPath: "data.anagrafica.media_depu_30") as AnyObject?)?.description {
            cleanWeightedAverage = Double(obj)
        } else { cleanWeightedAverage = nil }
        
        let graduationMark:Double?
        if let obj = (container.value(forKeyPath: "data.anagrafica.media_compl_110") as AnyObject?)?.description {
            graduationMark = Double(obj)
        } else { graduationMark = nil }
        
        let cleanGraduationMark:Double?
        if let obj = (container.value(forKeyPath: "data.anagrafica.media_depu_110") as AnyObject?)?.description {
            cleanGraduationMark = Double(obj)
        } else { cleanGraduationMark = nil }
        
        let obtainedCredits:UInt?
        if let obj = (container.value(forKeyPath: "data.anagrafica.crediti_tot_sostenuti") as AnyObject?)?.description {
            obtainedCredits = UInt(obj)
        } else { obtainedCredits = nil }
        
        let academicMajor:String?
        if let obj = container.value(forKeyPath: "data.anagrafica.nome_corso_laurea") as? String {
            academicMajor = obj.capitalized
        } else { academicMajor = nil }
        
        return PTStudentInfo(dateFetched: Date.init(),
                             firstName: firstName,
                                 lastName: lastName,
                                 weightedAverage: weightedAverage,
                                 cleanWeightedAverage: cleanWeightedAverage,
                                 graduationMark: graduationMark,
                                 cleanGraduationMark: cleanGraduationMark,
                                 obtainedCredits: obtainedCredits,
                                 academicMajor: academicMajor)
    }

}
