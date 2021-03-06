//
//  ApiClient.swift
//  Maplify
//
//  Created by Sergey on 2/26/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import Alamofire
import Tailor

typealias successClosure = (response: AnyObject!) -> ()
typealias failureClosure = (statusCode: Int, errors: [ApiError]!, localDescription: String!, messages: [String]!) -> ()
typealias progressClosure = (Int64, Int64, Int64) -> ()

class ApiClient {
    static let sharedClient = ApiClient()
    
    // MARK: - request management
    private func request(config: RequestConfig, manager: ModelManager!, encoding: ParameterEncoding, success: successClosure!, failure: failureClosure!) {
        if ReachabilityNetwork.isConnectedToNetwork() {
            if (config.data != nil) {
                self.multipartRequest(config, manager: manager, success: success, failure: failure)
            } else {
                self.baseRequest(config, manager: manager, encoding: encoding, success: success, failure: failure)
            }
        } else {
            failure?(statusCode: 0, errors: nil, localDescription: nil, messages: [NSLocalizedString("Alert.CheckConnectionNetwork", comment: String())])
        }
    }
    
    private func baseRequest(config: RequestConfig, manager: ModelManager!, encoding: ParameterEncoding, success: successClosure!, failure: failureClosure!) {
        let headers = SessionHelper.sharedHelper.sessionData() as! [String: String]
        Alamofire.request(config.type, config.uri.byAddingHost(), parameters: config.params, encoding: encoding, headers: headers)
            .response {[weak self] request, response, data, error  in
                if response != nil {
                    self?.manageResponse(response!, data: data!, manager: manager, acceptCodes: config.acceptCodes, error: error, success: success, failure: failure)
                }
        }
    }
    
    private func multipartRequest(config: RequestConfig, manager: ModelManager!, success: successClosure!, failure: failureClosure!) {
        let headers = SessionHelper.sharedHelper.sessionData() as! [String: String]
                
        Alamofire.upload(config.type, config.uri.byAddingHost(), headers: headers,
            multipartFormData: { (multipartFormData) -> () in
                let data = config.data[0].value as! NSData
                let name = config.data[0].key
                let fileName = config.params["fileName"]
                let mimeType = config.params["mimeType"]
                multipartFormData.appendBodyPart(data: data, name: name, fileName: fileName as! String, mimeType: mimeType as! String)
                
                for (key, value) in config.params {
                    multipartFormData.appendBodyPart(data: value.dataUsingEncoding(NSUTF8StringEncoding)!, name: key)
                }
            },
            encodingCompletion: { (multipartFormDataEncodingResult) -> () in
                switch multipartFormDataEncodingResult {
                case .Success(let upload, _, _):
                    upload.progress { bytesWritten, totalBytesWritten, totalBytesExpectedToWrite in
                        dispatch_async(dispatch_get_main_queue()) {
                            config.progress?(bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
                        }
                    }
                    upload.response(completionHandler: { [weak self] (request, response, data, error) -> () in
                        self?.manageResponse(response!, data: data!, manager:  manager, acceptCodes: config.acceptCodes, error: error, success: success, failure: failure)
                    })
                case .Failure(let encodingError):
                    print(encodingError)
                }
            }
        )
    }
    
    private func manageResponse(response: NSHTTPURLResponse!, data: NSData!, manager: ModelManager!, acceptCodes: [Int]!, error: NSError!, success: successClosure!, failure: failureClosure!) {
        
        let headersDictionary = (response as NSHTTPURLResponse).allHeaderFields
        if headersDictionary["Access-Token"] != nil {
            SessionHelper.sharedHelper.setSessionData(headersDictionary)
        }
        
        var payload = data?.jsonDictionary()
        
        if payload == nil {
            let str = String(data: data, encoding: NSUTF8StringEncoding)
            let htmlDict = ["html": str!] as NSDictionary
            payload = ["data": htmlDict]
        }
        
        let statusCode = (response as NSHTTPURLResponse).statusCode
        if acceptCodes.contains(statusCode) {
            if let dataDictionary = (payload as! [String : AnyObject])["data"] {
                dispatch_async(dispatch_get_main_queue()) {
                    success?(response: manager?.manageResponse(dataDictionary as! [String : AnyObject]))
                }
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    success?(response: nil)
                }
            }
        } else {
            if statusCode == Network.failureStatusCode500 {
                self.manageInternalServerError(statusCode, failure: failure)
            } else if statusCode == Network.failureStatusCode403 {
                self.manageUnauthorizedError(payload, statusCode: statusCode, error: error, failure: failure)
            } else {
                self.manageError(payload, statusCode: statusCode, error: error, failure: failure)
            }
        }
    }
    
    private func manageError(payload: AnyObject!, statusCode: Int , error: NSError!, failure: failureClosure!) {
        var errors: [ApiError]! = nil
        var messages: [String]! = nil
        
        if let dataDictionary = (payload as! [String : AnyObject])["error"] {
            let details = dataDictionary["details"] as! [String: AnyObject]
            messages = dataDictionary["error_messages"] as! [String]
            errors = ApiError.parseErrors(details, messages: messages)
        }
        dispatch_async(dispatch_get_main_queue()) {
            failure?(statusCode: statusCode, errors: errors, localDescription: error?.localizedDescription, messages: messages)
        }
    }
    
    private func manageUnauthorizedError(payload: AnyObject!, statusCode: Int , error: NSError!, failure: failureClosure!) {
        let window = ((UIApplication.sharedApplication().delegate?.window)!)! as UIWindow
        let navigationController = window.rootViewController as! NavigationViewController
        if navigationController.navigationType == .Main {
            self.cancelAllRequests()
            NSNotificationCenter.defaultCenter().postNotificationName(kNotificationNameSignOut, object: nil)
        } else {
            self.manageError(payload, statusCode: statusCode, error: error, failure: failure)
        }
    }
    
    private func manageInternalServerError(statusCode: Int, failure: failureClosure!) {
        dispatch_async(dispatch_get_main_queue()) {
            failure?(statusCode: statusCode, errors: nil, localDescription: nil, messages: [NSLocalizedString("Error.InternalServerError", comment: String())])
        }
    }
    
    private func cancelAllRequests() {
        if #available(iOS 9.0, *) {
            Alamofire.Manager.sharedInstance.session.getAllTasksWithCompletionHandler({ (tasks) in
                tasks.forEach { $0.cancel() }
            })
        } else {
            Alamofire.Manager.sharedInstance.session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
                dataTasks.forEach { $0.cancel() }
                uploadTasks.forEach { $0.cancel() }
                downloadTasks.forEach { $0.cancel() }
            }
        }
    }
    
    func postRequest(uri: String, params: [String: AnyObject]?, data: [String: AnyObject]!, manager: ModelManager, progress: progressClosure!, success: successClosure!, failure: failureClosure!) {
        let config = RequestConfig(type: .POST, uri: uri, params: params, acceptCodes: Network.successStatusCodes, data: data)
        self.request(config, manager: manager, encoding: .JSON, success: success, failure: failure)
    }
    
    func getRequest(uri: String, params: [String: AnyObject]?, manager: ModelManager, success: successClosure!, failure: failureClosure!) {
        let config = RequestConfig(type: .GET, uri: uri, params: params, acceptCodes: Network.successStatusCodes, data: nil)
        self.request(config, manager: manager, encoding: .URL, success: success, failure: failure)
    }
    
    func putRequest(uri: String, params: [String: AnyObject]?, data: [String: AnyObject]!, manager: ModelManager, success: successClosure!, failure: failureClosure!) {
        let config = RequestConfig(type: .PUT, uri: uri, params: params!, acceptCodes: Network.successStatusCodes, data: data)
        self.request(config, manager: manager, encoding: .JSON, success: success, failure: failure)
    }
    
    func patchRequest(uri: String, params: [String: AnyObject]?, data: [String: AnyObject]!, manager: ModelManager, success: successClosure!, failure: failureClosure!) {
        let config = RequestConfig(type: .PATCH, uri: uri, params: params!, acceptCodes: Network.successStatusCodes, data: data)
        self.request(config, manager: manager, encoding: .JSON, success: success, failure: failure)
    }
    
    func deleteRequest(uri: String, params: [String: AnyObject]?, manager: ModelManager!, success: successClosure!, failure: failureClosure!) {
        let config = RequestConfig(type: .DELETE, uri: uri, params: params, acceptCodes: Network.successStatusCodes, data: nil)
        self.request(config, manager: manager, encoding: .JSON, success: success, failure: failure)
    }
    
    // MARK: - user methods
    func signUp(user: User, password: String, passwordConfirmation: String, photo: NSData!, success: successClosure!, failure: failureClosure!) {
        let params = ["email": user.email, "password": password, "password_confirmation": passwordConfirmation, "mimeType": "image/png", "fileName": "photo.png"]
        var data: [String: AnyObject]! = nil
        if (photo != nil) {
            data = ["photo": photo]
        }
        self.postRequest("auth", params: params, data: data, manager: SessionManager(), progress: nil, success: success, failure: failure)
    }
    
    func signIn(email: String, password: String, success: successClosure!, failure: failureClosure!) {
        let params = ["email": email, "password": password]
        self.postRequest("auth/sign_in", params: params, data: nil, manager: SessionManager(), progress: nil, success: success, failure: failure)
    }
    
    func facebookAuth(token: String, success: successClosure!, failure: failureClosure!) {
        let params = ["facebook_access_token": token]
        self.postRequest("auth/provider_sessions", params:params , data: nil, manager: SessionManager(), progress: nil, success: success, failure: failure)
    }
    
    func getProfileInfo(profileId: Int, success: successClosure!, failure: failureClosure!) {
        self.getRequest("profiles/\(profileId)", params: nil, manager: ProfileManager(), success: success, failure: failure)
    }
    
    func getCurrentProfileInfo(success: successClosure!, failure: failureClosure!) {
        self.getRequest("profile", params: nil, manager: ProfileManager(), success: success, failure: failure)
    }
    
    func updateProfilePhoto(photo: NSData!, success: successClosure!, failure: failureClosure!) {
        let params = ["mimeType": "image/png", "fileName": "photo.png"]
        let data = ["photo": photo]
        self.patchRequest("profile", params: params, data: data, manager: ProfileManager(), success: success, failure: failure)
    }
    
    func updateProfile(profile: Profile, location: Location!, success: successClosure!, failure: failureClosure!) {
        var params: [String: AnyObject] = ["city": profile.city, "url": profile.url, "about": profile.about, "first_name": profile.firstName, "last_name": profile.lastName]
        if (location != nil) {
            let locationDict: [String: AnyObject] = ["latitude": location.latitude, "longitude": location.longitude, "address": location.address, "city": location.city]
            params["location"] = locationDict
        }
        self.patchRequest("profile", params: params, data: nil, manager: ProfileManager(), success: success, failure: failure)
    }
    
    func retrieveTermsOfUse(success: successClosure!, failure: failureClosure!) {
        self.getRequest("terms_of_service", params: nil, manager: WebContentManager(), success: success, failure: failure)
    }
    
    func retrievePrivacyPolicy(success: successClosure!, failure: failureClosure!) {
        self.getRequest("privacy_policy", params: nil, manager: WebContentManager(), success: success, failure: failure)
    }
    
    func retrieveAbout(success: successClosure!, failure: failureClosure!) {
        self.getRequest("about", params: nil, manager: WebContentManager(), success: success, failure: failure)
    }
    
    func createStoryPoint(params: [String: AnyObject], success: successClosure!, failure: failureClosure!) {
        self.postRequest("story_points", params: params, data: nil, manager: StoryPointManager(), progress: nil, success: success, failure: failure)
    }
    
    func updateStoryPoint(storyPointId: Int, params: [String: AnyObject], success: successClosure!, failure: failureClosure!) {
        self.patchRequest("story_points/\(storyPointId)", params: params, data: nil, manager: StoryPointManager(), success: success, failure: failure)
    }
    
    func deleteStoryPoint(storyPointId: Int, success: successClosure!, failure: failureClosure!) {
        self.deleteRequest("story_points/\(storyPointId)", params: nil, manager: StoryPointManager(), success: success, failure: failure)
    }
    
    func getStoryPoints(params: [String: AnyObject], success: successClosure!, failure: failureClosure!) {
        self.getRequest("user/story_points", params: params, manager: ArrayStoryPointManager(), success: success, failure: failure)
    }
    
    func getStoryPoint(storyPointId: Int, success: successClosure!, failure: failureClosure!) {
        self.getRequest("story_points/\(storyPointId)", params: nil, manager: StoryPointManager(), success: success, failure: failure)
    }
    
    func getAllStoryPoints(success: successClosure!, failure: failureClosure!) {
        let params: [String: AnyObject] = ["radius": kDiscoverSearchingRadius,
                                           "location[latitude]": 0,
                                           "location[longitude]": 0]
        self.getRequest("story_points", params: params, manager: ArrayStoryPointManager(), success: success, failure: failure)
    }
    
    func getUserStoryPoints(userId: Int, success: successClosure!, failure: failureClosure!) {
        let params: [String: AnyObject] = ["radius": kDiscoverSearchingRadius,
                                           "location[latitude]": 0,
                                           "location[longitude]": 0]
        self.getRequest("users/\(userId)/story_points", params: params, manager: ArrayStoryPointManager(), success: success, failure: failure)
    }
    
    func getUserStories(userId: Int, success: successClosure!, failure: failureClosure!) {
        self.getRequest("users/\(userId)/stories", params: nil, manager: ArrayStoryManager(), success: success, failure: failure)
    }
    
    func getCurrentUserStories(page: Int, success: successClosure!, failure: failureClosure!) {
        let params = ["page": page]
        self.getRequest("user/stories", params: params, manager: ArrayStoryManager(), success: success, failure: failure)
    }
    
    func getStoryPointStories(storyPointId: Int, success: successClosure!, failure: failureClosure!) {
        self.getRequest("story_points/\(storyPointId)/stories", params: nil, manager: ArrayStoryManager(), success: success, failure: failure)
    }
    
    func deleteStory(storyId: Int, success: successClosure!, failure: failureClosure!) {
        self.deleteRequest("stories/\(storyId)", params: nil, manager: StoryManager(), success: success, failure: failure)
    }
    
    func getStory(storyId: Int, success: successClosure!, failure: failureClosure!) {
        self.getRequest("stories/\(storyId)", params: nil, manager: StoryManager(), success: success, failure: failure)
    }

    func signOut(success: successClosure!, failure: failureClosure!) {
        self.deleteRequest("auth/sign_out", params: nil, manager: SessionManager(), success: success, failure: failure)
    }
    
    func postAttachment(file: NSData!, params: [String: AnyObject], success: successClosure!, failure: failureClosure!) {
        var data: [String: AnyObject]! = nil
        if (file != nil) {
            data = ["file": file]
        }
        self.postRequest("attachments", params: params, data: data, manager: AttachmentManager(), progress: nil, success: success, failure: failure)
    }
    
    func createStory(params: [String : AnyObject], success: successClosure!, failure: failureClosure!) {
        self.postRequest("stories", params: params, data: nil, manager: StoryManager(), progress: nil, success: success, failure: failure)
    }
    
    func updateUser(email: String, success: successClosure!, failure: failureClosure!) {
        let params = ["email": email]
        self.putRequest("user", params: params, data: nil, manager: SessionManager(), success: success, failure: failure)
    }

    func retrieveDiscoverList(page: Int, params: [String: AnyObject], success: successClosure!, failure: failureClosure!) {
        self.getRequest("discover", params: params, manager: DiscoverItemManager(), success: success, failure: failure)
    }
    
    func updateStory(storyId: Int, params: [String: AnyObject], success: successClosure!, failure: failureClosure!) {
        self.patchRequest("stories/\(storyId)", params: params, data: nil, manager: StoryManager(), success: success, failure: failure)
    }
    
    func resetPassword(email: String, redirectUrl: String, success: successClosure!, failure: failureClosure!) {
        let params = ["email": email, "redirect_url": redirectUrl]
        self.postRequest("auth/password", params: params, data: nil, manager: PasswordManager(), progress: nil, success: success, failure: failure)
    }

    func likeStoryPoint(storyPointId: Int, success: successClosure!, failure: failureClosure!) {
        self.postRequest("story_points/\(storyPointId)/like", params: nil, data: nil, manager: StoryPointManager(), progress: nil, success: success, failure: failure)
    }

    func unlikeStoryPoint(storyPointId: Int, success: successClosure!, failure: failureClosure!) {
        self.deleteRequest("story_points/\(storyPointId)/like", params: nil, manager: StoryPointManager(), success: success, failure: failure)
    }
    
    func likeStory(storyId: Int, success: successClosure!, failure: failureClosure!) {
        self.postRequest("stories/\(storyId)/like", params: nil, data: nil, manager: StoryManager(), progress: nil, success: success, failure: failure)
    }
    
    func unlikeStory(storyId: Int, success: successClosure!, failure: failureClosure!) {
        self.deleteRequest("stories/\(storyId)/like", params: nil, manager: StoryManager(), success: success, failure: failure)
    }
    
    func followStory(storyId: Int, success: successClosure!, failure: failureClosure!) {
        self.postRequest("stories/\(storyId)/following", params: nil, data: nil, manager: StoryManager(), progress: nil, success: success, failure: failure)
    }
    
    func unfollowStory(storyId: Int, success: successClosure!, failure: failureClosure!) {
        self.deleteRequest("stories/\(storyId)/following", params: nil, manager: StoryManager(), success: success, failure: failure)
    }
    
    func followUser(userId: Int, success: successClosure!, failure: failureClosure!) {
        self.postRequest("users/\(userId)/following", params: nil, data: nil, manager: SessionManager(), progress: nil, success: success, failure: failure)
    }
    
    func unfollowUser(userId: Int, success: successClosure!, failure: failureClosure!) {
        self.deleteRequest("users/\(userId)/following", params: nil, manager: SessionManager(), success: success, failure: failure)
    }

    func changePassword(password: String, confirmPassword: String, success: successClosure!, failure: failureClosure!) {
        let params = ["password": password, "password_confirmation": confirmPassword]
        self.patchRequest("auth/password", params: params, data: nil, manager: SessionManager(), success: success, failure: failure)
    }
    
    func retrieveFollowersList(success: successClosure!, failure: failureClosure!) {
        self.getRequest("user/followers", params: nil, manager: UserListManager(), success: success, failure: failure)
    }
    
    func retrieveFollowingsList(success: successClosure!, failure: failureClosure!) {
        self.getRequest("user/followed", params: nil, manager: UserListManager(), success: success, failure: failure)
    }
    
    func retrieveNotifications(makeRead: Bool, success: successClosure!, failure: failureClosure!) {
        let params = ["make_read": String(makeRead)]
        self.getRequest("notifications", params: params, manager: NotificationsManager(), success: success, failure: failure)
    }
    
    func reportStoryPoint(storyPointId: Int, reportKind: String, success: successClosure!, failure: failureClosure!) {
        let params = ["kind": reportKind]
        self.postRequest("story_points/\(storyPointId)/report", params: params, data: nil, manager: StoryPointManager(), progress: nil, success: success, failure: failure)
    }
    
    func reportStory(storyId: Int, reportKind: String, success: successClosure!, failure: failureClosure!) {
        let params = ["kind": reportKind]
        self.postRequest("stories/\(storyId)/report", params: params, data: nil, manager: StoryManager(), progress: nil, success: success, failure: failure)
    }
}

private extension String {
    func byAddingHost() -> String {
        return ConfigHepler.baseHostUrl() + "/api/v1/" + self
    }
}

private extension Dictionary {
    subscript(i: Int) -> (key: Key, value: Value) {
        get {
            return self[self.startIndex.advancedBy(i)]
        }
    }
}