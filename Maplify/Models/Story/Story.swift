//
//  Story.swift
//  Maplify
//
//  Created by Antonoff Evgeniy on 3/21/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import RealmSwift 
import Tailor

class Story: Model {
    dynamic var user: User! = nil
    dynamic var title = ""
    dynamic var storyDescription = ""
    dynamic var discoverable: Bool = false
    var storyPoints = List<StoryPoint>()
    
    convenience required init(_ map: [String : AnyObject]) {
        self.init()
        
        self.id <- map.property("id")
        self.user <- map.relation("user")
        self.title <- map.property("name")
        self.storyDescription <- map.property("description")
        self.discoverable <- map.property("discoverable")
        self.storyPoints <- Converter.arrayToList(map.relations("story_points"), type: StoryPoint.self)
    }
    
    override class func primaryKey() -> String {
        return "id"
    }
}
