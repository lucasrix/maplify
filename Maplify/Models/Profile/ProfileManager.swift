//
//  ProfileManager.swift
//  Maplify
//
//  Created by Sergey on 3/18/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import Tailor
import RealmSwift

class ProfileManager: ModelManager {
    override func manageResponse(response: [String : AnyObject]) -> AnyObject! {
        let dictionary = (response["profile"] != nil) ? (response["profile"] as! [String : AnyObject]) : response
        return Profile(dictionary)
    }
    
    class func saveProfile(profile: Profile) {
        let realm = try! Realm()
        
        try! realm.write {
            realm.add(profile, update: true)
        }
    }
}