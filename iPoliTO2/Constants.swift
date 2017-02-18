//
//  Constants.swift
//  iPoliTO2
//
//  Created by Carlo Rapisarda on 22/08/2016.
//  Copyright © 2016 crapisarda. All rights reserved.
//

struct PTConstants {
    
    static let demoAccount = PTAccount(rawStudentID: "s000000", password: "iPoliTO_demo")
    
    // MUST be set to false for production
    static let alwaysAskToLogin = false
    
    // MUST be set to false for production
    static let shouldForceDebugAccount = false
    
    static let debugAccount: PTAccount = demoAccount
    
    static let appStoreReviewLink = "http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=1069740093&pageNumber=0&sortOrdering=2&type=Purple+Software&mt=8"
    
    static let gitHubLink = "https://github.com/carlo-/ipolito"
    
    static let gitHubReadmeLink = "https://github.com/carlo-/ipolito/blob/master/README.md#ipolito"
    
    static let appStoreLink = "https://itunes.apple.com/us/app/ipolito-per-iphone/id1069740093?mt=8"
    
    static let feedbackEmail = "rapisarda.carlo@outlook.com"
    
    static let releaseVersionOfLastExecutionKey = "releaseVersionOfLastExecution"
}
