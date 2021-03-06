//
//  CurrentUser.swift
//  Maplify
//
//  Created by Sergey on 3/25/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import RealmSwift
import Realm

class CurrentUser: User {
    required init() {
        super.init()
    }
    
    required init(realm: RLMRealm, schema: RLMObjectSchema) {
        super.init(realm: realm, schema: schema)
    }
    
    convenience required init(_ map: [String : AnyObject]) {
        self.init()
    }
    
    required init(value: AnyObject, schema: RLMSchema) {
        fatalError("init(value:schema:) has not been implemented")
    }
}