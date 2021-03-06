//
//  Location.swift
//  Maplify
//
//  Created by Antonoff Evgeniy on 3/22/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import Tailor

class Location: Model {
    dynamic var latitude: Double = 0
    dynamic var longitude: Double = 0
    dynamic var city = String()
    dynamic var address = String()
    
    convenience required init(_ map: [String : AnyObject]) {
        self.init()
        
        self.id <- map.property("id")
        self.latitude <- map.property("latitude")
        self.longitude <- map.property("longitude")
        self.city <- map.property("city")
        self.address <- map.property("address")
    }
}
