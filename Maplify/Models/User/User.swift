//
//  User.swift
//  Maplify
//
//  Created by Sergey on 3/2/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import Tailor
import RealmSwift

class User: Model {
    dynamic var uid = ""
    dynamic var provider = ""
    dynamic var email = ""
    dynamic var profile: Profile! = nil
    dynamic var followed: Bool = false
    dynamic var follower: Bool = false
    
    convenience required init(_ map: [String : AnyObject]) {
        self.init()
        
        self.id <- map.property("id")
        self.created_at <- map.property("created_at")
        self.updated_at <- map.property("updated_at")
        self.email <- map.property("email")
        self.provider <- map.property("provider")
        self.uid <- map.property("uid")
        self.profile <- map.relationOrNil("profile")
        self.followed <- map.property("followed")
        self.follower <- map.property("follower")
    }
    
    override class func primaryKey() -> String {
        return "id"
    }
}