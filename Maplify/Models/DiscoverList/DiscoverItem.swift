//
//  DiscoverItem.swift
//  Maplify
//
//  Created by Evgeniy Antonoff on 4/13/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import RealmSwift
import Tailor

public enum DiscoverItemType : String {
    case StoryPoint = "StoryPoint"
    case Story = "Story"
}

class DiscoverItem: Model {
    dynamic var type = String()
    dynamic var storyPoint: StoryPoint? = nil
    dynamic var story: Story? = nil
    dynamic var nearMePosition: Int = 0
    dynamic var allOverTheWorldPosition: Int = 0
    dynamic var choosenPlacePosition: Int = 0
    
    convenience required init(_ map: [String : AnyObject]) {
        self.init()
    }
    
    override class func primaryKey() -> String {
        return "id"
    }
}

extension DiscoverItem {
    func nextId() -> Int {
        let realm = try! Realm()
        var nextId: Int = 1
        let objects = realm.objects(DiscoverItem).sorted("id")
        if objects.count > 0 {
            let lastId: Int = objects.last!.id
            nextId = lastId + 1
        }
        return nextId
    }
}
