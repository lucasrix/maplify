//
//  CaptureDataFetchingExtension.swift
//  Maplify
//
//  Created by Evgeniy Antonoff on 6/1/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

let kCaptureStorypointsFetchLimit: Int = 180

extension CaptureViewController {
    
    // MARK: - database
    func loadLocalAllStoryPonts() {
        self.currentStoryPoints = StoryPointManager.allStoryPoints(kCaptureStorypointsFetchLimit)
    }
    
    func loadLocalCurrentStoryPont(storyPointId: Int) {
        self.currentStoryPoints.removeAll()
        let storyPoint = StoryPointManager.find(storyPointId)
        if storyPoint != nil {
            self.currentStoryPoints.append(StoryPointManager.find(storyPointId))
        }
    }
    
    func loadLocalCurrentStory(storyId: Int) {
        self.currentStoryPoints.removeAll()
        self.currentStory = StoryManager.find(storyId)
        if self.currentStory?.storyPoints.count == 0 {
            self.popController()
        }
        if self.currentStory != nil {
            self.currentStoryPoints.appendContentsOf(Converter.listToArray(self.currentStory.storyPoints, type: StoryPoint.self))
        }
    }
    
    // MARK: - remote
    func loadRemoteAllStoryPonts(completion: ((success: Bool) -> ())!) {
        ApiClient.sharedClient.getAllStoryPoints({ (response) in
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                StoryPointManager.saveStoryPoints(response as! [StoryPoint])
                
                dispatch_async(dispatch_get_main_queue(), {
                    completion(success: true)
                })
            })
        }, failure:  { [weak self] (statusCode, errors, localDescription, messages) in
            self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
            completion(success: false)
        })
    }
    
    func loadRemoteStoryPont(storyPointId: Int, completion: ((success: Bool) -> ())!) {
        ApiClient.sharedClient.getStoryPoint(storyPointId, success: { (response) in
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                StoryPointManager.saveStoryPoint(response as! StoryPoint)
                
                dispatch_async(dispatch_get_main_queue(), {
                    completion(success: true)
                })
            })
        }, failure: { [weak self] (statusCode, errors, localDescription, messages) in
            self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
            completion(success: false)
        })
    }
    
    func loadRemoteStory(storyId: Int, completion: ((success: Bool) -> ())!) {
        ApiClient.sharedClient.getStory(storyId, success: { (response) in
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                StoryManager.saveStory(response as! Story)
                
                dispatch_async(dispatch_get_main_queue(), {
                    completion(success: true)
                })
            })
        }, failure: { [weak self] (statusCode, errors, localDescription, messages) in
            self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
            completion(success: false)
        })
    }
}
