//
//  DiscoverItemManager.swift
//  Maplify
//
//  Created by Evgeniy Antonoff on 4/12/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import RealmSwift

class DiscoverItemManager: ModelManager {
    
    override func manageResponse(response: [String : AnyObject]) -> AnyObject! {
        return response
    }
    
    class func saveDiscoverListItems(discoverItems: [String: AnyObject], pageNumber: Int, itemsCountInPage: Int) {
        let list: NSArray = discoverItems["discovered"] as! NSArray
        var currentPosition = (pageNumber - 1) * itemsCountInPage
        
        for item in list {
            let discoverItem = DiscoverItem()
            if item["type"] as! String == String(StoryPoint) {
                let dict = item as! [String: AnyObject]
                let storyPoint = StoryPoint(dict)
                discoverItem.type = DiscoverItemType.StoryPoint.rawValue
                StoryPointManager.saveStoryPoint(storyPoint)
                discoverItem.storyPoint = storyPoint
            } else if item["type"] as! String == String(Story) {
                let dict = item as! [String: AnyObject]
                let story = Story(dict)
                discoverItem.type = DiscoverItemType.Story.rawValue
                StoryManager.saveStory(story)
                discoverItem.story = story
            }
            
            discoverItem.nearMePosition = currentPosition
            discoverItem.id = currentPosition
            DiscoverItemManager.saveItem(discoverItem)
            
            currentPosition += 1
        }
    }
    
    class func find(DiscoverItemId: Int) -> DiscoverItem! {
        let realm = try! Realm()
        return realm.objectForPrimaryKey(DiscoverItem.self, key: DiscoverItemId)
    }
    
    class func saveItem(item: DiscoverItem) {
        let realm = try! Realm()
        
        try! realm.write {
            realm.add(item, update: true)
        }
    }
}
