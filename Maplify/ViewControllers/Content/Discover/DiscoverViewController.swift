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

let kDiscoverItemsInPage = 25
let kDiscoverFirstPage = 1

enum EditContentOption: Int {
    case EditPost
    case DeletePost
    case Directions
    case SharePost
}

enum DefaultContentOption: Int {
    case Directions
    case SharePost
    case ReportAbuse
}

enum RequestState: Int {
    case Ready
    case Loading
}

let kDiscoverNavigationBarShadowOpacity: Float = 0.8
let kDiscoverNavigationBarShadowRadius: CGFloat = 3

class DiscoverViewController: ViewController, CSBaseTableDataSourceDelegate, DiscoverStoryPointCellDelegate, DiscoverStoryCellDelegate, ErrorHandlingProtocol {
    @IBOutlet weak var tableView: UITableView!
    
    var storyDataSource: DiscoverTableDataSource! = nil
    var storyActiveModel = CSActiveModel()
    var discoverShowProfileClosure: ((userId: Int) -> ())! = nil
    var canLoadMore: Bool = true
    var discoverItems: [DiscoverItem]! = nil
    var page: Int = kDiscoverFirstPage
    var requestState: RequestState = RequestState.Ready
    
    // MARK: - view controller life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.loadItemsFromDB()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.loadRemoteData()
    }
    
    deinit {
        self.tableView.ins_removePullToRefresh()
        self.tableView.ins_endInfinityScroll()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.setup()
    }
    
    // MARK: - setup
    func setup() {
        self.setupNavigationBar()
        self.setupTableView()
    }
    
    func setupNavigationBar() {
        self.title = NSLocalizedString("Controller.Capture.Title", comment: String())
        
        // add shadow
        self.navigationController?.navigationBar.layer.shadowOpacity = kDiscoverNavigationBarShadowOpacity;
        self.navigationController?.navigationBar.layer.shadowOffset = CGSizeZero;
        self.navigationController?.navigationBar.layer.shadowRadius = kDiscoverNavigationBarShadowRadius;
        self.navigationController?.navigationBar.layer.masksToBounds = false;
    }
    
    func setupTableView() {
        self.setupPullToRefresh()
        self.setupInfinityScroll()
    }
    
    func setupPullToRefresh() {
        self.tableView.ins_addPullToRefreshWithHeight(NavigationBar.defaultHeight) { [weak self] (scrollView) in
            self?.page = kDiscoverFirstPage
            self?.loadRemoteData()
        }
        
        let pullToRefresh = INSDefaultPullToRefresh(frame: Frame.pullToRefreshFrame, backImage: nil, frontImage: nil)
        self.tableView.ins_pullToRefreshBackgroundView.preserveContentInset = false
        self.tableView.ins_pullToRefreshBackgroundView.delegate = pullToRefresh
        self.tableView.ins_pullToRefreshBackgroundView.addSubview(pullToRefresh)
    }
    
    func setupInfinityScroll() {
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
    
    // MARK: - navigation bar
    override func backButtonHidden() -> Bool {
        return true
    }
    
    override func navigationBarIsTranlucent() -> Bool {
        return false
    }
    
    override func navigationBarColor() -> UIColor {
        return UIColor.darkGreyBlue()
    }
    
    func loadItemsFromDB() {
        let realm = try! Realm()
        
        self.storyActiveModel.removeData()
        let itemsCount = self.itemsCountToShow()
        let allItems = realm.objects(DiscoverItem).sorted("nearMePosition")
        print(allItems)
        if allItems.count >=  itemsCount {
            self.discoverItems = Array(allItems[0..<itemsCount])
        } else {
            self.discoverItems = Array(allItems)
        }
//        self.discoverItems = Array(realm.objects(DiscoverItem).sorted("nearMePosition")[0..<itemsCount])
//        print(self.discoverItems)
        self.storyActiveModel.addItems(self.discoverItems, cellIdentifier: String(), sectionTitle: nil, delegate: self)
        self.storyDataSource = DiscoverTableDataSource(tableView: self.tableView, activeModel: self.storyActiveModel, delegate: self)
        self.storyDataSource.reloadTable()
    }
    
    func itemsCountToShow() -> Int{
        return self.page * kDiscoverItemsInPage
    }
    
    // MARK: - remote
    func loadRemoteData() {
        // get current location
        if SessionHelper.sharedManager.locationEnabled() {
            INTULocationManager.sharedInstance().requestLocationWithDesiredAccuracy(.City, timeout: Network.mapRequestTimeOut) { [weak self] (location, accuracy, status) -> () in
                if location != nil {
                    self?.retrieveDiscoverList(location)
                }
            }
        } else {
            self.retrieveDiscoverList(CLLocation(latitude: DefaultLocation.washingtonDC.0, longitude: DefaultLocation.washingtonDC.1))
        }
    }
    
    func retrieveDiscoverList(location: CLLocation) {
        self.requestState = RequestState.Loading
        print(self.page)
        ApiClient.sharedClient.retrieveDiscoverList(location.coordinate.latitude, longitude: location.coordinate.longitude, radius: 10000000, page: self.page, success: { [weak self] (response) in
//            print(response)
            DiscoverItemManager.saveDiscoverListItems(response as! [String: AnyObject], pageNumber: self!.page, itemsCountInPage: kDiscoverItemsInPage)
            
            self?.tableView.ins_endInfinityScroll()
            self?.tableView.ins_endPullToRefresh()
            
            self?.tableView.ins_setInfinityScrollEnabled(response.count == kDiscoverItemsInPage)
            self?.requestState = RequestState.Ready
            
            self?.loadItemsFromDB()
            
            /*
            self?.storyActiveModel.addItems(response as! [AnyObject], cellIdentifier: String(), sectionTitle: nil, delegate: self!)
            self?.storyDataSource = DiscoverTableDataSource(tableView: (self?.tableView)!, activeModel: (self?.storyActiveModel)!, delegate: self!)
            self?.storyDataSource.reloadTable()*/
            
            }) { [weak self] (statusCode, errors, localDescription, messages) in
                self?.requestState = RequestState.Ready
                self?.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
        }
    }
    
    // MARK: - actions
    func showEditContentMenu(storyPointId: Int) {
        let storyPoint = StoryPointManager.find(storyPointId)
        if storyPoint.user.profile.id == SessionManager.currentUser().profile.id {
            self.showEditContentActionSheet(storyPointId)
        } else {
            self.showDefaultContentActionSheet(storyPointId)
        }       
    }
    
    func showEditContentActionSheet(storyPointId: Int) {
        let editPost = NSLocalizedString("Button.EditPost", comment: String())
        let deletePost = NSLocalizedString("Button.DeletePost", comment: String())
        let directions = NSLocalizedString("Button.Directions", comment: String())
        let sharePost = NSLocalizedString("Button.SharePost", comment: String())
        let cancel = NSLocalizedString("Button.Cancel", comment: String())
        let buttons = [editPost, deletePost, directions, sharePost]
        
        self.showActionSheet(nil, message: nil, cancel: cancel, destructive: nil, buttons: buttons, handle: { [weak self] (buttonIndex) in
            if buttonIndex == EditContentOption.EditPost.rawValue {
                self?.routesOpenStoryPointEditController(storyPointId, storyPointUpdateHandler: { [weak self] in
                    self?.storyDataSource.reloadTable()
                })
            } else if buttonIndex == EditContentOption.DeletePost.rawValue {
                self?.deleteStoryPoint(storyPointId)
            }
            }
        )
    }
    
    func showDefaultContentActionSheet(storyPointId: Int) {
        let directions = NSLocalizedString("Button.Directions", comment: String())
        let sharePost = NSLocalizedString("Button.SharePost", comment: String())
        let reportAbuse = NSLocalizedString("Button.ReportAbuse", comment: String())
        let cancel = NSLocalizedString("Button.Cancel", comment: String())
        let buttons = [directions, sharePost]
        
        self.showActionSheet(nil, message: nil, cancel: cancel, destructive: reportAbuse, buttons: buttons, handle: { (buttonIndex) in
                //TODO: -
            }
        )
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
                                                            let storyPoint = StoryPointManager.find(storyPointId)
                                                            if storyPoint != nil {
                                                                StoryPointManager.delete(storyPointId)
                                                            }
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
        self.discoverShowProfileClosure(userId: userId)
    }

    // MARK: - DiscoverStoryCellDelegate
    func didSelectStory(storyId: Int) {
        let itemIndex = self.discoverItems.indexOf({$0.id == storyId})
        let indexPath = NSIndexPath(forRow: itemIndex!, inSection: 0)
        let cellDataModel = self.storyActiveModel.cellData(indexPath)
        self.storyActiveModel.selectModel(indexPath, selected: !cellDataModel.selected)
        self.storyDataSource.reloadTable()
    }
    
    func didSelectStoryPoint(storyPoints: [StoryPoint], selectedIndex: Int, storyTitle: String) {
        self.parentViewController?.routesOpenStoryDetailViewController(storyPoints, selectedIndex: selectedIndex, storyTitle: storyTitle)
    }
    
    func didSelectMap() {
        // TODO:
    }
    
    func storyProfileImageTapped(userId: Int) {
        self.discoverShowProfileClosure(userId: userId)
    }

    // MARK: - ErrorHandlingProtocol
    func handleErrors(statusCode: Int, errors: [ApiError]!, localDescription: String!, messages: [String]!) {
        let title = NSLocalizedString("Alert.Error", comment: String())
        let cancel = NSLocalizedString("Button.Ok", comment: String())
        self.showMessageAlert(title, message: String.formattedErrorMessage(messages), cancel: cancel)
    }
}

