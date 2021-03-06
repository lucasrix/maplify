//
//  StoryCreateAddInfoViewController.swift
//  Maplify
//
//  Created by Evgeniy Antonoff on 7/11/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import Photos
import UIKit

enum NetworkState: Int {
    case Ready
    case InProgress
}

let kUploadCountViewHeight: CGFloat = 37

class StoryCreateAddInfoViewController: ViewController, StoryAddMediaTableViewCellDelegate, StoryCreateManagerDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var uploadingViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var uploadingCountLabel: UILabel!
    
    var storyDataSource: StoryAddMediaDataSource! = nil
    var storyActiveModel = CSActiveModel()
    var headerView: StoryAddMediaHeaderView! = nil
    
    var createStoryCompletion: createStoryClosure! = nil
    var selectedDrafts = [StoryPointDraft]()
    var succedDrafts = [StoryPointDraft]()
    var failedDrafts = [StoryPointDraft]()
    var uploadingDraftsCount: Int = 1
    var storyId: Int = 0
    var networkState = NetworkState.Ready

    // MARK: - view controller life cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        self.setup()
        self.loadData()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.setupNavigationBarItems()
        self.populateTitle()
    }
    
    // MARK: - setup
    func setup() {
        self.setupHeaderView()
        self.setupDataSource()
    }
    
    func populateTitle() {
        let localizedString = NSString.localizedStringWithFormat(NSLocalizedString("Count.Assets", comment: String()), self.selectedDrafts.count)
        self.title = String(localizedString)
    }
    
    func setupNavigationBarItems() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem.barButton(UIImage(named: ButtonImages.icoCancel)!, target: self, action: #selector(StoryCreateAddInfoViewController.cancelButtonTapped))
        self.addRightBarItem(NSLocalizedString("Button.Post", comment: String()))
    }
    
    func setupHeaderView() {
        self.headerView = NSBundle.mainBundle().loadNibNamed(String(StoryAddMediaHeaderView), owner: nil, options: nil).last as! StoryAddMediaHeaderView
        self.headerView.setup()
    }
    
    func setupDataSource() {
        self.storyDataSource = StoryAddMediaDataSource(tableView: self.tableView, activeModel: self.storyActiveModel, delegate: self)
        self.storyDataSource.headerView = self.headerView
    }
    
    func loadData() {
        self.storyActiveModel.removeData()
        self.storyActiveModel.addItems(self.selectedDrafts, cellIdentifier: String(StoryAddMediaTableViewCell), sectionTitle: nil, delegate: self)
        self.storyDataSource.reloadTable()
    }
    
    // MARK: - navigation bar
    override func navigationBarIsTranlucent() -> Bool {
        return false
    }
    
    override func navigationBarColor() -> UIColor {
        return UIColor.darkGreyBlue()
    }
    
    func setupInProgressState() {
        self.changeNetworkState(false)
    }
    
    func setupReadyState() {
        self.changeNetworkState(true)
    }
    
    private func changeNetworkState(enabled: Bool) {
        self.navigationItem.rightBarButtonItem?.enabled = enabled
        self.headerView?.titleTextField.enabled = enabled
        self.headerView?.descriptionTextView.editable = enabled
        self.headerView?.descriptionTextView.selectable = enabled
    }
    
    // MARK: - actions
    func cancelButtonTapped() {
        if self.networkState == .Ready {
            let alertMessage = NSLocalizedString("Alert.StoryCreateCancel", comment: String())
            let yesButton = NSLocalizedString("Button.YesDelete", comment: String())
            let noButton = NSLocalizedString("Button.No", comment: String())
            self.showAlert(nil, message: alertMessage, cancel: noButton, buttons: [yesButton]) { [weak self] (buttonIndex) in
                if buttonIndex == AlertButtonIndexes.Submit.rawValue {
                    self?.createStoryCompletion?(storyId: 0, cancelled: true)
                }
            }
        }
    }
    
    override func rightBarButtonItemDidTap() {
        let notReadyDrafts = self.selectedDrafts.filter { $0.readyToCreate() == false }
        if (self.headerView?.readyToCreate() == true) && (notReadyDrafts.count == 0) {
            let storyName = self.headerView?.titleTextField?.text
            self.postStory(storyName!)
        } else {
            self.showStoryNameErrorIfNedded()
        }
    }
    
    private func showStoryNameErrorIfNedded() {
        if self.headerView?.readyToCreate() == false {
            self.headerView?.setStoryNameErrorState()
            self.tableView?.setContentOffset(CGPointZero, animated:true)
            self.headerView?.titleTextField?.becomeFirstResponder()
        } else {
            self.headerView?.titleTextField?.resignFirstResponder()
            self.showStoryPointLocationErrorIfNeeded()
        }
    }
    
    private func showStoryPointLocationErrorIfNeeded() {
        for draft in self.selectedDrafts {
            if draft.readyToCreate() == false {
                let index = self.storyActiveModel.indexPathOfModel(draft)
                self.tableView.scrollToRowAtIndexPath(index, atScrollPosition: UITableViewScrollPosition.Bottom, animated: true)
                break
            }
        }
    }
    
    func postStory(storyName: String) {
        self.networkState = .InProgress
        self.showProgressHUD()
        self.setupInProgressState()
        let storyManager = StoryCreateManager.sharedManager
        storyManager.delegate = self
        let storyDescription = self.headerView?.descriptionTextView?.text
        
        self.updateUploadingCountView(self.uploadingDraftsCount, allItemsCount: self.selectedDrafts.count)
        self.tableView?.setContentOffset(CGPointZero, animated:true)
        
        storyManager.postStory(storyName, storyDescription: storyDescription, storyPointDrafts: self.selectedDrafts)
    }
    
    // MARK: - StoryAddMediaTableViewCellDelegate
    func getIndexOfObject(draft: StoryPointDraft, completion: ((index: Int, count: Int) -> ())!) {
        let index = self.storyActiveModel.indexPathOfModel(draft)
        completion?(index: index.row, count: self.storyActiveModel.numberOfItems(0))
    }
    
    func addLocationDidTap(completion: ((location: CLLocationCoordinate2D, address: String) -> ())!) {
        if self.networkState == .Ready {
            self.routesOpenStoryCreateAddLocationController { [weak self] (place) in
                completion(location: place.coordinate, address: place.name)
                self?.navigationController?.popToViewController(self!, animated: true)
            }
        }
    }
    
    func retryPostStoryPointDidTap(draft: StoryPointDraft) {
        draft.downloadState = .InProgress
        self.updateCell(draft)
        StoryCreateManager.sharedManager.retryPostStoryPoint(draft, storyId: self.storyId) { [weak self] (createdDraft, success) in
            draft.downloadState = success == true ? .Success : .Fail
            self?.updateCell(draft)
        }
    }
    
    func deleteStoryPointDidTap(draft: StoryPointDraft) {
        if self.networkState == .Ready {
            self.manageStoryPointDraftDeletion(draft)
        }
    }
    
    func canEditInfo() -> Bool {
        return self.networkState == .Ready
    }
    
    // MARK: - private
    private func manageStoryPointDraftDeletion(draft: StoryPointDraft) {
        if self.selectedDrafts.count == 1 {
            self.showLastDraftDeletionAlert()
        } else {
            self.showDraftDelationAlert(draft)
        }
    }
    
    private func removeDraft(draft: StoryPointDraft) {
        let index = self.selectedDrafts.indexOf(draft)
        if (index != nil) && (index != NSNotFound) {
            self.selectedDrafts.removeAtIndex(index!)
            let indexPath = NSIndexPath(forRow: index!, inSection: 0)
            self.storyDataSource.removeRow(indexPath)
            self.storyDataSource.reloadTable()
            self.populateTitle()
        }
    }
    
    private func showDraftDelationAlert(draft: StoryPointDraft) {
        let alertMessage = NSLocalizedString("Alert.StoryPointDraftDeletion", comment: String())
        let yesButton = NSLocalizedString("Button.YesDelete", comment: String())
        let noButton = NSLocalizedString("Button.No", comment: String())
        self.showAlert(nil, message: alertMessage, cancel: noButton, buttons: [yesButton]) { [weak self] (buttonIndex) in
            if buttonIndex == AlertButtonIndexes.Submit.rawValue {
                self?.removeDraft(draft)
            }
        }
    }
    
    private func showLastDraftDeletionAlert() {
        let alertMessage = NSLocalizedString("Alert.StoryPointDraftDeletionLast", comment: String())
        let yesButton = NSLocalizedString("Button.YesRemoveAndDelete", comment: String())
        let noButton = NSLocalizedString("Button.No", comment: String())
        self.showAlert(nil, message: alertMessage, cancel: noButton, buttons: [yesButton]) { [weak self] (buttonIndex) in
            if buttonIndex == AlertButtonIndexes.Submit.rawValue {
                self?.createStoryCompletion?(storyId: 0, cancelled: true)
            }
        }
    }
    
    // MARK: - StoryCreateManagerDelegate
    func creationStoryDidSuccess(storyId: Int) {
        self.storyId = storyId
        self.hideProgressHUD()
    }
    
    func creationStoryDidFail(statusCode: Int, errors: [ApiError]!, localDescription: String!, messages: [String]!) {
        self.networkState = .Ready
        self.hideProgressHUD()
        self.setupReadyState()
        self.handleErrors(statusCode, errors: errors, localDescription: localDescription, messages: messages)
    }
    
    func creationStoryPointDidStartCreating(draft: StoryPointDraft) {
        dispatch_async(dispatch_get_main_queue(), {
            self.updateUploadingCountView(self.uploadingDraftsCount, allItemsCount: self.selectedDrafts.count)
        })
        draft.downloadState = .InProgress
        self.updateCell(draft)
    }
    
    func creationStoryPointDidSuccess(draft: StoryPointDraft) {
        self.uploadingDraftsCount += 1
        if self.succedDrafts.contains(draft) == false {
            self.succedDrafts.append(draft)
        }
        draft.downloadState = .Success
        self.updateCell(draft)
    }
    
    func creationStoryPointDidFail(draft: StoryPointDraft) {
        self.uploadingDraftsCount += 1
        if self.failedDrafts.contains(draft) == false {
            self.failedDrafts.append(draft)
        }
        draft.downloadState = .Fail
        self.updateCell(draft)
    }
    
    func allOperationsCompleted(storyId: Int) {
        dispatch_async(dispatch_get_main_queue(), {
            self.setCompletedUploading(self.succedDrafts.count, allItemsCount: self.selectedDrafts.count)
        })
        self.networkState = .Ready
        if self.failedDrafts.count == 0 {
            self.setupReadyState()
            self.createStoryCompletion?(storyId: storyId, cancelled: false)
        } else {
            self.showNotAllUploadedSuccesfullAlert()
        }
    }
    
    private func showNotAllUploadedSuccesfullAlert() {
        let alertMessage = NSLocalizedString("Alert.StoryProblemSavingSomeMoments", comment: String())
        let yesButton = NSLocalizedString("Button.YesRetry", comment: String())
        let noButton = NSLocalizedString("Button.NoThanks", comment: String())
        self.showAlert(nil, message: alertMessage, cancel: noButton, buttons: [yesButton]) { [weak self] (buttonIndex) in
            if buttonIndex == AlertButtonIndexes.Cancel.rawValue {
                self?.createStoryCompletion?(storyId: (self?.storyId)!, cancelled: false)
            }
        }
    }
    
    private func updateCell(draft: StoryPointDraft) {
        let index = self.selectedDrafts.indexOf(draft)
        if (index != nil) && (index != NSNotFound) {
            let indexPath = NSIndexPath(forRow: index!, inSection: 0)
            dispatch_async(dispatch_get_main_queue(), {
                self.storyDataSource.reloadCell([indexPath])
            })
        }
    }
    
    private func updateUploadingCountView(uploadingItemsCount: Int, allItemsCount: Int) {
        self.uploadingViewHeightConstraint.constant = kUploadCountViewHeight
        self.uploadingCountLabel.hidden = false
        self.uploadingCountLabel.text = String(format: NSLocalizedString("Label.StoryUploadingCount", comment: String()), uploadingItemsCount, allItemsCount)
    }
    
    func setCompletedUploading(uploadingItemsCount: Int, allItemsCount: Int) {
        self.uploadingCountLabel.text = String(format: NSLocalizedString("Label.StoryUploadingCompleted", comment: String()), uploadingItemsCount, allItemsCount)
    }
    
    // MARK: - ErrorHandlingProtocol
    func handleErrors(statusCode: Int, errors: [ApiError]!, localDescription: String!, messages: [String]!) {
        let title = NSLocalizedString("Alert.Error", comment: String())
        let cancel = NSLocalizedString("Button.Ok", comment: String())
        self.showMessageAlert(title, message: String.formattedErrorMessage(messages), cancel: cancel)
    }
}
