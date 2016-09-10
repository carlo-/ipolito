//
//  PTKeychain.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 07/09/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

import Foundation

enum PTKeychainValueType: String {
    case password = "password"
    case token = "token"
    case username = "username"
}

fileprivate typealias PTKeychainDictionary = [String: String]

class PTKeychain: NSObject {
    
    /// Stores a PTAccount in the keychain
    class func storeAccount(_ account: PTAccount) {
        
        storeValue(account.studentID, ofType: .username)
        storeValue(account.password, ofType: .password)
    }
    
    /// Returns the stored account if available
    class func retrieveAccount() -> PTAccount? {
        
        if let studentID = retrieveValue(ofType: .username),
           let password = retrieveValue(ofType: .password) {
            
            return PTAccount(rawStudentID: studentID, password: password)
        }
        
        return nil
    }
    
    /// Stores a value of PTKeychainValueType in the keychain
    class func storeValue(_ value: String, ofType type: PTKeychainValueType) {
        
        var secureDict = getSecureDictionary()
        secureDict[type.rawValue] = value
        setSecureDictionary(secureDict)
    }
    
    /// Returns the value of PTKeychainValueType if available
    class func retrieveValue(ofType type: PTKeychainValueType) -> String? {
        
        let secureDict = getSecureDictionary()
        return secureDict[type.rawValue]
    }
    
    /// Stores an empty dictionary in the keychain, overwriting any existing secure data
    class func removeAllValues() {
        setSecureDictionary([:])
    }
    
    
    private class func getSecureDictionary() -> PTKeychainDictionary {
        
        let str = KeychainWrapper().myObject(forKey: kSecValueData) as? String
        if let data = str?.data(using: .utf8) {
            
            do {
                let decoded = try JSONSerialization.jsonObject(with: data, options: []) as? PTKeychainDictionary
                return decoded ?? [:]
            } catch _ {}
        }
        
        return [:]
    }
    
    private class func setSecureDictionary(_ dict: PTKeychainDictionary) {
        
        do {
            let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
            if let str = String(data: data, encoding: .utf8) {
                
                let wrapper = KeychainWrapper()
                wrapper.mySetObject(str, forKey: kSecValueData)
                wrapper.writeToKeychain()
            }
        } catch _ {}
    }
}
