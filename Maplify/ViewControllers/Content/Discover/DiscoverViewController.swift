//
//  DiscoverViewController.swift
//  Maplify
//
//  Created by Sergey on 3/21/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import INTULocationManager
import RealmSwift
import INSPullToRefresh.UIScrollView_INSPullToRefresh
import Tailor

let kDiscoverItemsInPage = 25
let kDiscoverFirstPage = 1
let kDiscoverBarMinLimitOpacity: CGFloat = 0.2

enum RequestState: Int {
    case Ready
    case Loading
}

enum SearchLocationParameter: Int {
    case AllOverTheWorld
    case NearMe
    case ChoosenPlace
}

enum DiscoverItemSortParameter: String {
    case nearMe = "nearMePosition"
    case allOverTheWorld = "allOverTheWorldPosition"
    case choosenPlace = "choosenPlacePosition"
}

let kDiscoverNavigationBarShadowOpacity: Float = 0.8
let kDiscoverNavigationBarShadowRadius: CGFloat = 3
let kDiscoverSearchingRadius: CGFloat = 10000000

class DiscoverViewController: ViewController, CSBaseTableDataSourceDelegate, DiscoverStoryPointCellDelegate, DiscoverTableDataSourceDelegate, DiscoverStoryCellDelegate, ErrorHandlingProtocol, DiscoverChangeLocationDelegate, ProfileViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    
    var storyDataSource: DiscoverTableDataSource! = nil
    var storyActiveModel = CSActiveModel()
    var discoverShowProfileClosure: ((userId: Int) -> ())! = nil
    var canLoadMore: Bool = true
    var discoverItems = [DiscoverItem]()
    var page: Int = kDiscoverFirstPage
    var requestState: RequestState = RequestState.Ready
    
    var searchLocationParameter: SearchLocationParameter! = .NearMe
    var searchParamChoosenLocation: CLLocationCoordinate2D! = nil

    var userProfileId: Int = 0
    var supportUserProfile: Bool = false
    var stackSupport: Bool = false
    
    var profileView: ProfileView! = nil
    
    // MARK: - view controller life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupTitle()
        self.setupProfileViewIfNeeded()
        self.configureProfileViewIfNeeded()
        self.setupDataSource()
    }
    
    deinit {
        if self.tableView != nil {
            self.tableView.ins_removePullToRefresh()
            self.tableView.ins_endInfinityScroll()
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.setup()
        self.configureProfileViewIfNeeded()
    }
    
    // MARK: - setup
    func setup() {
        self.setupNavigationBar()
        self.setupNavigationBarButtonItems()
        self.setupTableView()
        self.loadItemsFromDB()
        self.loadRemoteData()
        self.setupNavigationBarColorWithContentOffsetIfNeeded(self.tableView.contentOffset)
    }
    
    func setupDataSource() {
        self.storyActiveModel = CSActiveModel()
        self.storyDataSource = DiscoverTableDataSource(tableView: self.tableView, activeModel: self.storyActiveModel, delegate: self)
        self.storyDataSource.scrollDelegate = self
        self.storyDataSource.profileView = self.profileView
    }
    
    func setupTitle() {
        self.title = NSLocalizedString("Controller.Capture.Title", comment: String())
    }
    
    func setupProfileViewIfNeeded() {
        if self.supportUserProfile {
            self.profileView = NSBundle.mainBundle().loadNibNamed(String(ProfileView), owner: nil, options: nil).last as! ProfileView
            self.profileView.delegate = self

            self.profileView.updateContentClosure = { [weak self] () in
                self?.tableView.reloadData()
            }
            
            self.profileView.didChangeImageClosure = { [weak self] (image) in
                self?.showProgressHUD()
                let photo = UIImagePNGRepresentation(image)
                ApiClient.sharedClient.updateProfilePhoto(photo,
                                                     success: { [weak self] (response) in
                                                        let profile = response as! Profile
                                                        let placeholderImage = UIImage(named: PlaceholderImages.discoverUserEmptyAva)
                                                        
                                                        ProfileManager.saveProfile(profile)
                                                        SessionManager.updateProfileForCurrrentUser(profile)
                                                        
                                                        self?.profileView.userImageView.sd_setImageWithURL(NSURL(string: profile.small_thumbnail), placeholderImage: placeholderImage, options: [.RefreshCached], completed: { (image, error, type, url) in
                                                            self?.hideProgressHUD()
                                                            self?.storyDataSource.reloadTable()
                                                        })
                                                    },
                                                     failure:  { [weak self] (statusCode, errors, localDescription, messages) in
                                                        self?.hideProgressHUD()
                                                        self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
                                                    })
            }
        }
    }
    
    func configureProfileViewIfNeeded() {
        if self.supportUserProfile {
            self.profileView.setupWithUser(self.userProfileId, parentViewController: self)
        }
    }
    
    func setupNavigationBar() {
        if self.supportUserProfile {
            self.navigationController?.setNavigationBarHidden(false, animated: false)
            self.navigationController?.navigationBar.layer.shadowOffset = CGSizeMake(0, kShadowYOffset)
            self.navigationController?.navigationBar.layer.shadowOpacity = 0
            self.title = NSLocalizedString("Controller.Profile.Title", comment: String())
        } else {
            // add shadow
            self.navigationController?.navigationBar.layer.shadowOpacity = kDiscoverNavigationBarShadowOpacity;
            self.navigationController?.navigationBar.layer.shadowOffset = CGSizeZero;
            self.navigationController?.navigationBar.layer.shadowRadius = kDiscoverNavigationBarShadowRadius;
            self.navigationController?.navigationBar.layer.masksToBounds = false;
        }
    }
    
    func setupNavigationBarButtonItems() {
        if self.supportUserProfile == false {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem.barButton(UIImage(named: ButtonImages.icoSearch)!, target: self, action: #selector(DiscoverViewController.searchButtonTapped))
        } else if (self.supportUserProfile) && self.userProfileId == (SessionManager.currentUser().id) {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem.barButton(UIImage(named: BarButtonImages.profileSettings)!, target: self, action: #selector(DiscoverViewController.settingsButtonTapped))
        }
    }
    
    func setupTableView() {
        self.setupPullToRefreshIfNeeded()
        self.setupInfinityScrollIfNeeded()

        self.tableView.contentInset = UIEdgeInsetsZero
        if self.supportUserProfile {
            self.tableView.backgroundColor = UIColor.darkerGreyBlue()
        }
    }
    
    func setupPullToRefreshIfNeeded() {
        if self.supportUserProfile == false {
            self.tableView.ins_addPullToRefreshWithHeight(NavigationBar.defaultHeight) { [weak self] (scrollView) in
                self?.page = kDiscoverFirstPage
                self?.loadRemoteData()
            }
            
            let pullToRefresh = INSDefaultPullToRefresh(frame: Frame.pullToRefreshFrame, backImage: nil, frontImage: nil)
            self.tableView.ins_pullToRefreshBackgroundView.preserveContentInset = false
            self.tableView.ins_pullToRefreshBackgroundView.delegate = pullToRefresh
            self.tableView.ins_pullToRefreshBackgroundView.addSubview(pullToRefresh)
        }
    }
    
    func setupInfinityScrollIfNeeded() {
        if self.supportUserProfile == false {
            self.tableView.ins_setInfinityScrollEnabled(true)
            self.tableView.ins_addInfinityScrollWithHeight(NavigationBar.defaultHeight) { [weak self] (scrollView) in
                if self?.requestState == RequestState.Ready {
                    self?.page += 1
                    self?.loadRemoteData()
                }
            }
            
            let indicator = INSDefaultInfiniteIndicator(frame: Frame.pullToRefreshFrame)
            self.tableView.ins_infiniteScrollBackgroundView.preserveContentInset = false
            self.tableView.ins_infiniteScrollBackgroundView.addSubview(indicator)
            indicator.startAnimating()
        }
    }
    
    // MARK: - navigation bar
    override func backButtonHidden() -> Bool {
        return !self.supportUserProfile
    }
    
    override func backTapped() {
        if self.stackSupport == false {
            self.navigationController?.setNavigationBarHidden(true, animated: false)
        }
        super.backTapped()
    }
    
    override func navigationBarIsTranlucent() -> Bool {
        return self.supportUserProfile
    }
    
    override func navigationBarColor() -> UIColor {
        return self.supportUserProfile ? UIColor.clearColor() : UIColor.darkGreyBlue()
    }
    
    func loadItemsFromDB() {
        let realm = try! Realm()
        
        self.storyActiveModel.removeData()
        if self.supportUserProfile {
            self.storyActiveModel.removeData()
            let currentUserId = self.userProfileId
            let allItems = realm.objects(DiscoverItem).filter("(storyPoint.user.id == \(currentUserId) OR (story.user.id == \(currentUserId) AND story.storyPoints.@count > 0)) AND (story.reported == false OR storyPoint.reported == false)").sorted("created_at", ascending: false)
            self.discoverItems = Array(allItems)
        } else {
            let itemsCount = self.itemsCountToShow()
            let sortRaram = self.sortedString()
            let allItems = realm.objects(DiscoverItem).filter("\(sortRaram) != 0 AND (story.storyPoints.@count > 0 OR storyPoint != nil) AND (story.reported == false OR storyPoint.reported == false)").sorted(sortRaram)
            if allItems.count >=  itemsCount {
                self.discoverItems = Array(allItems[0..<itemsCount])
            } else {
                self.discoverItems = Array(allItems)
            }
        }
        if (self.discoverItems.count == 0) && (self.supportUserProfile) {
            let placeholderString = NSLocalizedString("Text.Placeholder.Profile", comment: String())
            self.storyActiveModel.addItems([placeholderString], cellIdentifier: String(), sectionTitle: nil, delegate: self, boundingSize: UIScreen.mainScreen().bounds.size)
        } else {
            self.storyActiveModel.addItems(self.discoverItems, cellIdentifier: String(), sectionTitle: nil, delegate: self, boundingSize: UIScreen.mainScreen().bounds.size)
        }
        self.storyDataSource.reloadTable()
    }
    
    func sortedString() -> String {
        if self.searchLocationParameter == SearchLocationParameter.NearMe {
            return DiscoverItemSortParameter.nearMe.rawValue
        } else if self.searchLocationParameter == SearchLocationParameter.AllOverTheWorld {
            return DiscoverItemSortParameter.allOverTheWorld.rawValue
        } else if self.searchLocationParameter == SearchLocationParameter.ChoosenPlace {
            return DiscoverItemSortParameter.choosenPlace.rawValue
        }
        return String()
    }
    
    func itemsCountToShow() -> Int {
        return self.page * kDiscoverItemsInPage
    }
    
    // MARK: - remote
    func loadRemoteData() {
        if self.supportUserProfile {
            self.loadUserDiscoverData()
        } else {
            self.loadDiscoverRemoteData()
        }
    }
    
    func loadUserDiscoverData() {
        if self.storyActiveModel.hasData() == false {
            self.showProgressHUD()
        }
        ApiClient.sharedClient.getUserStoryPoints(self.userProfileId,
            success: { [weak self] (response) in
                let storyPoints = response as! [StoryPoint]
                ApiClient.sharedClient.getUserStories((self?.userProfileId)!, success: { [weak self] (response) in
                    self?.hideProgressHUD()
                    let stories = response as! [Story]
                    let discoverItems = UserRequestHelper.sortAndMerge(storyPoints, stories: stories)
                    DiscoverItemManager.deleteNonExisting((self?.userProfileId)!, existingItemsIds: discoverItems.map({$0.id}))
                    
                    self?.loadItemsFromDB()
                    },
                failure: { (statusCode, errors, localDescription, messages) in
                    self?.hideProgressHUD()
                    self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
                })
            },
            failure: { [weak self] (statusCode, errors, localDescription, messages) in
                self?.hideProgressHUD()
                self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
            })
    }
    
    func loadDiscoverRemoteData() {
        if self.searchLocationParameter == SearchLocationParameter.NearMe {
            self.loadRemoteDataNearMe()
        } else if self.searchLocationParameter == SearchLocationParameter.AllOverTheWorld {
            self.loadRemoteDataAllOverTheWorld()
        } else if self.searchLocationParameter == SearchLocationParameter.ChoosenPlace {
            self.loadRemoteDataChoosenPlace()
        }
    }
    
    // MARK: - all over the world searching
    func loadRemoteDataAllOverTheWorld() {
        let params: [String: AnyObject] = ["page": self.page]
        self.retrieveDiscoverList(params)
    }
    
    func loadRemoteDataChoosenPlace() {
        self.retrieveDiscoverListWithLocation(self.searchParamChoosenLocation.latitude, longitude: self.searchParamChoosenLocation.longitude)
    }
    
    // MARK: - near me searching
    func loadRemoteDataNearMe() {
        // get current location
        if SessionHelper.sharedHelper.locationEnabled() {
            INTULocationManager.sharedInstance().requestLocationWithDesiredAccuracy(.City, timeout: Network.mapRequestTimeOut) { [weak self] (location, accuracy, status) -> () in
                if location != nil {
                    self?.retrieveDiscoverListWithLocation(location.coordinate.latitude, longitude: location.coordinate.longitude)
                } else {
                    self?.retrieveDiscoverListWithLocation(DefaultLocation.washingtonDC.0, longitude: DefaultLocation.washingtonDC.1)
                }
            }
        } else {
            self.retrieveDiscoverListWithLocation(DefaultLocation.washingtonDC.0, longitude: DefaultLocation.washingtonDC.1)
        }
    }
    
    func retrieveDiscoverListWithLocation(latitude: Double, longitude: Double) {
        let params: [String: AnyObject] = ["page": self.page,
                                           "radius": kDiscoverSearchingRadius,
                                           "location[latitude]": latitude,
                                           "location[longitude]": longitude
        ]
        self.retrieveDiscoverList(params)
    }
    
    func retrieveDiscoverList(params: [String: AnyObject]) {
        self.requestState = RequestState.Loading
        
        if self.storyActiveModel.hasData() == false {
            self.showProgressHUD()
        }
        
        ApiClient.sharedClient.retrieveDiscoverList(self.page, params: params, success: { [weak self] (response) in
            self?.hideProgressHUD()
            DiscoverItemManager.saveDiscoverListItems(response as! [String: AnyObject], pageNumber: self!.page, itemsCountInPage: kDiscoverItemsInPage, searchLocationParameter: (self?.searchLocationParameter)!)
            
            self?.tableView.ins_endInfinityScroll()
            self?.tableView.ins_endPullToRefresh()
            
            let list: [DiscoverItem] = (response as! [String: AnyObject]).relations("discovered")!
            self?.tableView.ins_setInfinityScrollEnabled(list.count == kDiscoverItemsInPage)
            self?.requestState = RequestState.Ready
            
            self?.loadItemsFromDB()
            
        }) { [weak self] (statusCode, errors, localDescription, messages) in
            self?.hideProgressHUD()
            self?.tableView.ins_endInfinityScroll()
            self?.tableView.ins_endPullToRefresh()
            self?.requestState = RequestState.Ready
            self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
        }
    }
    
    // MARK: - actions
    func showEditContentMenu(storyPointId: Int) {
        let storyPoint = StoryPointManager.find(storyPointId)
        if storyPoint.user.profile.id == SessionManager.currentUser().profile.id {
            self.showStoryPointEditContentActionSheet( { [weak self] (selectedIndex) -> () in
                if selectedIndex == StoryPointEditContentOption.EditPost.rawValue {
                    self?.routesOpenStoryPointEditController(storyPointId, storyPointUpdateHandler: { [weak self] in
                        self?.storyDataSource.reloadTable()
                        })
                } else if selectedIndex == StoryPointEditContentOption.DeletePost.rawValue {
                    self?.deleteStoryPoint(storyPointId)
                } else if selectedIndex == StoryPointEditContentOption.SharePost.rawValue {
                    self?.shareStoryPoint(storyPointId)
                }
            })
        } else {
            self.showStoryPointDefaultContentActionSheet( { [weak self] (selectedIndex) in
                if selectedIndex == StoryPointDefaultContentOption.SharePost.rawValue {
                    self?.shareStoryPoint(storyPointId)
                } else if selectedIndex == StoryPointDefaultContentOption.ReportAbuse.rawValue {
                    self?.reportStoryPoint(storyPointId)
                }
            })
        }       
    }
    
    func deleteStoryPoint(storyPointId: Int) {
        let alertMessage = NSLocalizedString("Alert.DeleteStoryPoint", comment: String())
        let yesButton = NSLocalizedString("Button.Yes", comment: String())
        let noButton = NSLocalizedString("Button.No", comment: String())
        self.showAlert(nil, message: alertMessage, cancel: yesButton, buttons: [noButton]) { (buttonIndex) in
            if buttonIndex != 0 {
                self.showProgressHUD()
                ApiClient.sharedClient.deleteStoryPoint(storyPointId,
                                                        success: { [weak self] (response) in
                                                            StoryPointManager.saveStoryPoint(response as! StoryPoint)
                                                            let discoverItem = DiscoverItemManager.findWithStoryPoint(storyPointId)
                                                            let storyPoint = StoryPointManager.find(storyPointId)
                                                            if (storyPoint != nil) && (discoverItem != nil) {
                                                                DiscoverItemManager.delete(discoverItem)
                                                                StoryPointManager.delete(storyPoint)
                                                            }
                                                            self?.profileView?.setupDetailedLabels()
                                                            self?.hideProgressHUD()
                                                            self?.loadItemsFromDB()
                                                        },
                                                        failure: { [weak self] (statusCode, errors, localDescription, messages) in
                                                            self?.hideProgressHUD()
                                                            self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
                                                        }
                )
            }
        }
    }
    
    func shareStoryPoint(storyPointId: Int) {
        self.routesOpenShareStoryPointViewController(storyPointId) { [weak self] () in
            self?.navigationController?.popToViewController(self!, animated: true)
        }
    }
    
    func reportStoryPoint(storyPointId: Int) {
        self.routesOpenReportsController(storyPointId, postType: .StoryPoint) { 
            self.navigationController?.popToViewController(self, animated: true)
        }
    }
    
    // MARK: - story
    func showEditStoryContentMenu(storyId: Int) {
        let story = StoryManager.find(storyId)
        if story.user.profile.id == SessionManager.currentUser().profile.id {
            self.showEditStoryContentActionSheet({ [weak self] (selectedIndex) in
                if selectedIndex == StoryEditContentOption.EditStory.rawValue {
                    self?.routesOpenStoryEditController(storyId, editStoryCompletion: { [weak self] (storyId, cancelled) in
                        self?.navigationController?.popToViewController(self!, animated: true)
                        if cancelled == true {
                            self?.storyDataSource.reloadTable()
                        }
                    })
                } else if selectedIndex == StoryEditContentOption.DeleteStory.rawValue {
                    self?.deleteStory(storyId)
                } else if selectedIndex == StoryEditContentOption.ShareStory.rawValue {
                    self?.shareStory(storyId)
                }
            })
        } else {
            self.showStoryDefaultContentActionSheet( { [weak self] (selectedIndex) in
                if selectedIndex == StoryDefaultContentOption.ShareStory.rawValue {
                    self?.shareStory(storyId)
                } else if selectedIndex == StoryDefaultContentOption.ReportAbuse.rawValue {
                    self?.reportStory(storyId)
                }
            })
        }
    }
    
    func deleteStory(storyId: Int) {
        let alertMessage = NSLocalizedString("Alert.DeleteStoryPoint", comment: String())
        let yesButton = NSLocalizedString("Button.Yes", comment: String())
        let noButton = NSLocalizedString("Button.No", comment: String())
        self.showAlert(nil, message: alertMessage, cancel: yesButton, buttons: [noButton]) { (buttonIndex) in
            if buttonIndex != 0 {
                self.showProgressHUD()
                ApiClient.sharedClient.deleteStory(storyId,
                                                   success: { [weak self] (response) in
                                                        StoryManager.saveStory(response as! Story)
                                                        let discoverItem = DiscoverItemManager.findWithStory(storyId)
                                                        let story = StoryManager.find(storyId)
                                                        if (story != nil) && (discoverItem != nil) {
                                                            DiscoverItemManager.delete(discoverItem)
                                                            StoryManager.delete(story)
                                                        }
                                                        self?.profileView?.setupDetailedLabels()
                                                    self?.hideProgressHUD()
                                                    self?.loadItemsFromDB()
                                                    },
                                                    failure: { [weak self] (statusCode, errors, localDescription, messages) in
                                                        self?.hideProgressHUD()
                                                        self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
                                                    })
            }
        }
    }
    
    func shareStory(storyId: Int) {
        self.routesOpenShareStoryViewController(storyId) { [weak self] () in
            self?.navigationController?.popToViewController(self!, animated: true)
        }
    }
    
    func reportStory(storyId: Int) {
        self.routesOpenReportsController(storyId, postType: .Story) { 
            self.navigationController?.popToViewController(self, animated: true)
        }
    }
    
    func searchButtonTapped() {
        self.routerShowDiscoverChangeLocationPopupController(self)
    }
    
    func settingsButtonTapped() {
        self.routesOpenMenuController()
    }
    
    // MARK: - DiscoverStoryPointCellDelegate
    func reloadTable(storyPointId: Int) {
        let storyPointIndex = self.discoverItems.indexOf({$0.id == storyPointId})
        let indexPath = NSIndexPath(forRow: storyPointIndex!, inSection: 0)
        let cellDataModel = self.storyActiveModel.cellData(indexPath)
        self.storyActiveModel.selectModel(indexPath, selected: !cellDataModel.selected)
        self.storyDataSource.reloadTable()
    }
    
    func editContentDidTap(storyPointId: Int) {
        self.showEditContentMenu(storyPointId)
    }
    
    func profileImageTapped(userId: Int) {
        if self.supportUserProfile == false {
            self.routesOpenDiscoverController(userId, supportUserProfile: true, stackSupport: true)
        }
    }
    
    func likeStoryPointDidTap(storyPointId: Int, completion: ((success: Bool) -> ())) {
        let storyPoint = StoryPointManager.find(storyPointId)
        if storyPoint.liked {
            self.unlikeStoryPoint(storyPointId, completion: completion)
        } else {
            self.likeStoryPoint(storyPointId, completion: completion)
        }
    }
    
    private func likeStoryPoint(storyPointId: Int, completion: ((success: Bool) -> ())) {
        ApiClient.sharedClient.likeStoryPoint(storyPointId, success: { [weak self] (response) in
            StoryPointManager.saveStoryPoint(response as! StoryPoint)
            self?.profileView?.setupDetailedLabels()
            completion(success: true)
            }) { [weak self] (statusCode, errors, localDescription, messages) in
                self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
                completion(success: false)
        }
    }
    
    private func unlikeStoryPoint(storyPointId: Int, completion: ((success: Bool) -> ())) {
        ApiClient.sharedClient.unlikeStoryPoint(storyPointId, success: { [weak self] (response) in
            StoryPointManager.saveStoryPoint(response as! StoryPoint)
            self?.profileView?.setupDetailedLabels()
            completion(success: true)
            }) { [weak self] (statusCode, errors, localDescription, messages) in
                self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
                completion(success: false)
        }
    }
    
    func shareStoryPointDidTap(storyPointId: Int) {
        self.shareStoryPoint(storyPointId)
    }

    // MARK: - DiscoverStoryCellDelegate
    func didSelectStory(storyId: Int) {
        let itemIndex = self.discoverItems.indexOf({$0.id == storyId})
        if itemIndex != NSNotFound {
            let indexPath = NSIndexPath(forRow: itemIndex!, inSection: 0)
            let cellDataModel = self.storyActiveModel.cellData(indexPath)
            self.storyActiveModel.selectModel(indexPath, selected: !cellDataModel.selected)
            self.storyDataSource.reloadTable()
        }
    }
    
    func didSelectMap(story: Story!) {
        self.routesPushFromLeftStoryCaptureViewController(story.id)
    }
    
    func storyProfileImageTapped(userId: Int) {
        self.discoverShowProfileClosure?(userId: userId)
    }
    
    func editStoryContentDidTap(storyId: Int) {
        self.showEditStoryContentMenu(storyId)
    }
    
    func likeStoryDidTap(storyId: Int, completion: ((success: Bool) -> ())) {
        let story = StoryManager.find(storyId)
        if story.liked {
            self.unlikeStory(storyId, completion: completion)
        } else {
            self.likeStory(storyId, completion: completion)
        }
    }
    
    private func likeStory(storyId: Int, completion: ((success: Bool) -> ())) {
        ApiClient.sharedClient.likeStory(storyId, success: { [weak self] (response) in
            StoryManager.saveStory(response as! Story)
            self?.profileView?.setupDetailedLabels()
            completion(success: true)
            }) { [weak self] (statusCode, errors, localDescription, messages) in
                self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
                completion(success: false)
        }
    }
    
    private func unlikeStory(storyId: Int, completion: ((success: Bool) -> ())) {
        ApiClient.sharedClient.unlikeStory(storyId, success: { [weak self] (response) in
            StoryManager.saveStory(response as! Story)
            self?.profileView?.setupDetailedLabels()
            completion(success: true)
            }) { [weak self] (statusCode, errors, localDescription, messages) in
                self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
                completion(success: false)
        }
    }

    func followStory(storyId: Int, completion: ((success: Bool) -> ())) {
        let story = StoryManager.find(storyId)
        if story.followed == false {
            self.followStoryRemote(storyId, completion: completion)
        } else {
            self.unfollowStoryRemote(storyId, completion: completion)
        }
    }
    
    func followStoryRemote(storyId: Int, completion: ((success: Bool) -> ())) {
        ApiClient.sharedClient.followStory(storyId, success: { (response) in
            StoryManager.saveStory(response as! Story)
            completion(success: true)
            
        }) { [weak self] (statusCode, errors, localDescription, messages) in
            self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
            completion(success: false)
        }
    }
    
    func unfollowStoryRemote(storyId: Int, completion: ((success: Bool) -> ())) {
        ApiClient.sharedClient.unfollowStory(storyId, success: { (response) in
            StoryManager.saveStory(response as! Story)
            completion(success: true)
            
            }) { [weak self] (statusCode, errors, localDescription, messages) in
                self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
                completion(success: false)
        }
    }
    
    func shareStoryDidTap(storyId: Int) {
        self.shareStory(storyId)
    }

    // MARK: - ProfileViewDelegate
    func followButtonDidTap(userId: Int, completion: ((success: Bool) -> ())) {
        let user = SessionManager.findUser(userId)
        if user.followed {
            self.unfollowUser(userId, completion: completion)
        } else {
            self.followUser(userId, completion: completion)
        }
    }
    
    func createStoryButtonDidTap() {
        self.routesOpenStoryCreateCameraRollController { [weak self] (storyId, cancelled) in
            self?.profileView?.setupDetailedLabels()
            self?.navigationController?.popToViewController(self!, animated: true)
        }
    }
    
    func editButtonDidTap() {
        self.routesOpenEditProfileController(self.userProfileId, photo: self.profileView.userImageView.image) { [weak self] () in
            self?.storyDataSource.reloadTable()
            self?.configureProfileViewIfNeeded()
        }
    }
    
    func followingUsersTapped() {
        self.routesOpenFollowingContentController(ShowingListOption.Following)
    }
    
    func followersUsersTapped() {
        self.routesOpenFollowingContentController(ShowingListOption.Followers)
    }
    
    // MARK: - private
    private func followUser(userId: Int, completion: ((success: Bool) -> ())) {
        ApiClient.sharedClient.followUser(userId, success: { (response) in
            SessionManager.saveUser(response as! User)
            completion(success: true)
            
            }) { [weak self] (statusCode, errors, localDescription, messages) in
                self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
                completion(success: false)
        }
    }
    
    private func unfollowUser(userId: Int, completion: ((success: Bool) -> ())) {
        ApiClient.sharedClient.unfollowUser(userId, success: { (response) in
            SessionManager.saveUser(response as! User)
            completion(success: true)
            
            }) { [weak self] (statusCode, errors, localDescription, messages) in
                self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
                completion(success: false)
        }
    }
    
    // MARK: - DiscoverTableDataSourceDelegate
    func discoverTableDidScroll(scrollView: UIScrollView) {
        self.setupNavigationBarColorWithContentOffsetIfNeeded(scrollView.contentOffset)
    }
    
    func setupNavigationBarColorWithContentOffsetIfNeeded(contentOffset: CGPoint) {
        if self.supportUserProfile {
            let profileViewHeight = self.profileView.contentHeight()
            let alphaMin = NavigationBar.navigationBarAlphaMin
            let alphaMax = NavigationBar.defaultOpacity
            if (contentOffset.y > profileViewHeight * alphaMin && contentOffset.y <= profileViewHeight * alphaMax) {
                var alpha: CGFloat = contentOffset.y / profileViewHeight
                if alpha < kDiscoverBarMinLimitOpacity {
                    alpha = 0
                }
                self.setNavigationBarTransparentWithAlpha(alpha)
            } else if (contentOffset.y > profileViewHeight) {
                self.setNavigationBarTransparentWithAlpha(alphaMax)
            }
        }
    }
    
    func setNavigationBarTransparentWithAlpha(alpha: CGFloat) {
        let color = UIColor.darkBlueGrey().colorWithAlphaComponent(alpha)
        let image = UIImage(color: color)!
        self.navigationController?.navigationBar.setBackgroundImage(image, forBarMetrics: .Default)
    }

    // MARK: - ErrorHandlingProtocol
    func handleErrors(statusCode: Int, errors: [ApiError]!, localDescription: String!, messages: [String]!) {
        let title = NSLocalizedString("Alert.Error", comment: String())
        let cancel = NSLocalizedString("Button.Ok", comment: String())
        self.showMessageAlert(title, message: String.formattedErrorMessage(messages), cancel: cancel)
    }
    
    // MARK: - DiscoverChangeLocationDelegate
    func didSelectAllOverTheWorldLocation() {
        self.title = NSLocalizedString("Controller.DiscoverTitle.AllTheWorld", comment: String())
        self.updateData(SearchLocationParameter.AllOverTheWorld)
    }
    
    func didSelectNearMePosition() {
        self.title = NSLocalizedString("Controller.Capture.Title", comment: String())
        self.updateData(SearchLocationParameter.NearMe)
    }
    
    func didSelectChoosenPlace(coordinates: CLLocationCoordinate2D, placeName: String) {
        self.title = placeName
        self.searchParamChoosenLocation = coordinates
        self.updateData(SearchLocationParameter.ChoosenPlace)
    }
    
    func updateData(searchLocationParameter: SearchLocationParameter) {
        self.tableView.setContentOffset(CGPointZero, animated: false)
        self.searchLocationParameter = searchLocationParameter
        self.page = kDiscoverFirstPage
        self.loadItemsFromDB()
        self.loadRemoteData()
    }
}
