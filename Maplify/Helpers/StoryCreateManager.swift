//
//  StoryCreateManager.swift
//  Maplify
//
//  Created by Evgeniy Antonoff on 7/14/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import Photos
import UIKit

protocol StoryCreateManagerDelegate {
    func creationStoryDidSuccess()
    func creationStoryDidFail(statusCode: Int, errors: [ApiError]!, localDescription: String!, messages: [String]!)
    func creationStoryPointDidStartCreating(draft: StoryPointDraft)
    func creationStoryPointDidSuccess(draft: StoryPointDraft)
    func creationStoryPointDidFail(draft: StoryPointDraft)
    func allOperationsCompleted(storyId: Int)
}

class StoryCreateManager: NSObject {
    static let sharedManager = StoryCreateManager()
    
    var imageManager = PHCachingImageManager()
    var delegate: StoryCreateManagerDelegate! = nil
    
    func postStory(storyName: String, storyDescription: String!, storyPointDrafts: [StoryPointDraft]) {
            var params: [String: AnyObject] = ["name": storyName, "discoverable": false]
            if storyDescription.characters.count > 0 {
                params["description"] = storyDescription
            }
            
            ApiClient.sharedClient.createStory(params, success: { [weak self] (response) in
                let story = response as! Story
                StoryManager.saveStory(story)
                self?.delegate?.creationStoryDidSuccess()
                self?.postStoryPoints(story.id, drafts: storyPointDrafts)
                
                }, failure: { [weak self] (statusCode, errors, localDescription, messages) in
                    self?.delegate?.creationStoryDidFail(statusCode, errors: errors, localDescription: localDescription, messages: messages)
            })
    }
    
    func postStoryPoints(storyId: Int, drafts: [StoryPointDraft]) {
        for draft in drafts {
            OperationQueueManager.sharedInstance.addOperation({ [weak self] (operation) in
                self?.fileDataForDraft(draft, operation: operation, completion: { (fileData, params, kind, operation) in
                    self?.remotePostAttachment(draft, fileData: fileData, params: params, kind: kind, operation: operation, storyId: storyId)
                })
            })
        }
        
        OperationQueueManager.sharedInstance.addOperation { (operation) in
            ApiClient.sharedClient.getStory(storyId, success: { [weak self] (response) in
                StoryManager.saveStory(response as! Story)
                operation.completeOperation()
                if OperationQueueManager.sharedInstance.queue.operationCount == 0 {
                    self?.delegate.allOperationsCompleted(storyId)
                }
                
                }, failure: { [weak self] (statusCode, errors, localDescription, messages) in
                    operation.completeOperation()
                    if OperationQueueManager.sharedInstance.queue.operationCount == 0 {
                        self?.delegate.allOperationsCompleted(storyId)
                    }
            })
        }
    }
    
    func remotePostAttachment(draft: StoryPointDraft, fileData: NSData, params: [String: AnyObject], kind: StoryPointKind, operation: NetworkOperation, storyId: Int) {
        ApiClient.sharedClient.postAttachment(fileData, params: params, success: { [weak self] (response) -> () in
            let attachmentID = (response as! Attachment).id
            self?.remotePostStoryPoint(draft, kind: kind, storyId: storyId, attachmentId: attachmentID, operation: operation)
            
        }) { [weak self] (statusCode, errors, localDescription, messages) -> () in
            self?.delegate?.creationStoryPointDidFail(draft)
            operation.completeOperation()
        }
    }
    
    func remotePostStoryPoint(draft: StoryPointDraft, kind: StoryPointKind, storyId: Int, attachmentId: Int, operation: NetworkOperation) {
        let locationDict: [String: AnyObject] = ["latitude":draft.coordinate.latitude, "longitude":draft.coordinate.longitude, "address": draft.address]
        let storyPointDict: [String: AnyObject] = ["kind":kind.rawValue,
                                                   "text":draft.storyPointdescription,
                                                   "location":locationDict,
                                                   "attachment_id":attachmentId,
                                                   "story_ids":[storyId]]
        
        ApiClient.sharedClient.createStoryPoint(storyPointDict, success: { [weak self] (response) in
            StoryPointManager.saveStoryPoint(response as! StoryPoint)
            self?.delegate.creationStoryPointDidSuccess(draft)
            operation.completeOperation()
            
            }) { [weak self] (statusCode, errors, localDescription, messages) in
                self?.delegate?.creationStoryPointDidFail(draft)
                operation.completeOperation()
        }
    }
    
    func fileDataForDraft(draft: StoryPointDraft, operation: NetworkOperation, completion: ((fileData: NSData, params: [String: AnyObject], kind: StoryPointKind, operation: NetworkOperation) -> ())!) {
        if draft.asset.mediaType == .Image {
            self.imageDataForDraft(draft, operation: operation, completion: completion)
        } else if draft.asset.mediaType == .Video {
            self.videoDataForDraft(draft, operation: operation, completion: completion)
        } else {
            self.delegate?.creationStoryPointDidFail(draft)
            operation.completeOperation()
        }
    }
    
    func imageDataForDraft(draft: StoryPointDraft, operation: NetworkOperation, completion: ((fileData: NSData, params: [String: AnyObject], kind: StoryPointKind, operation: NetworkOperation) -> ())!) {
        var fileData: NSData! = nil
        let imageWidth = UIScreen().screenWidth() * UIScreen().screenScale()
        let size = CGSizeMake(imageWidth, imageWidth)
        if let image = draft.image.cropToSquare()?.resize(size) {
            fileData = UIImagePNGRepresentation(image)
        }
        
        if fileData != nil {
            let params = ["mimeType": "image/png", "fileName": "photo.png"]
            let kind = StoryPointKind.Photo
            completion?(fileData: fileData!, params: params, kind: kind, operation: operation)
        } else {
            self.delegate?.creationStoryPointDidFail(draft)
            operation.completeOperation()
        }
    }
    
    func videoDataForDraft(draft: StoryPointDraft, operation: NetworkOperation, completion: ((fileData: NSData, params: [String: AnyObject], kind: StoryPointKind, operation: NetworkOperation) -> ())!) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            let options = PHVideoRequestOptions()
            options.networkAccessAllowed = true
            self.imageManager.requestAVAssetForVideo(draft.asset, options: options, resultHandler: { (avAsset, audioMix, info) -> () in
                
                let fileAsset = avAsset as? AVURLAsset
                let fileData = NSData(contentsOfURL: fileAsset!.URL)
                
                dispatch_async(dispatch_get_main_queue(), {
                    if fileData != nil {
                        let params = ["mimeType": "video/quicktime", "fileName": "video.mov"]
                        let kind = StoryPointKind.Video
                        completion?(fileData: fileData!, params: params, kind: kind, operation: operation)
                    } else {
                        self.delegate?.creationStoryPointDidFail(draft)
                        operation.completeOperation()
                    }
                })
            })
        })
    }
}