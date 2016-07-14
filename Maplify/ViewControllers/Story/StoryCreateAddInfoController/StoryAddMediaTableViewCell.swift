//
//  StoryAddMediaTableViewCell.swift
//  Maplify
//
//  Created by Evgeniy Antonoff on 7/11/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import Photos
import GoogleMaps
import KMPlaceholderTextView
import UIKit

let kCellTopMargin: CGFloat = 24
let kCellLocationViewHeight: CGFloat = 39
let kCellDescriptionViewHeight: CGFloat = 73
let kLocationLabelTextColorAlphaDefault: CGFloat = 0.4

protocol StoryAddMediaTableViewCellDelegate {
    func getIndexOfObject(draft: StoryPointDraft, completion: ((index: Int, count: Int) -> ())!)
    func addLocationDidTap(completion: ((location: CLLocationCoordinate2D, address: String) -> ())!)
}

class StoryAddMediaTableViewCell: CSTableViewCell {
    @IBOutlet weak var assetImageView: UIImageView!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var addressImageView: UIImageView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var changeAddressButton: UIButton!
    @IBOutlet weak var addLocationButton: UIButton!
    @IBOutlet weak var locationView: UIView!
    @IBOutlet weak var descriptionTextView: KMPlaceholderTextView!
    @IBOutlet weak var orderBackView: UIView!
    @IBOutlet weak var orderLabel: UILabel!
    @IBOutlet weak var isVideoImageView: UIImageView!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var cropButton: UIButton!
    
    var imageManager = PHCachingImageManager()
    var delegate: StoryAddMediaTableViewCellDelegate! = nil
    var draft: StoryPointDraft! = nil
    
    // MARK: - setup
    override func configure(cellData: CSCellData) {
        let draft = cellData.model as! StoryPointDraft
        self.draft = draft
        self.delegate = cellData.delegate as! StoryAddMediaTableViewCellDelegate
        self.setupViews(draft.asset)
        self.populateOrder(draft)
        self.populateImage(draft.asset)
        self.manageLocation(draft)
    }
    
    func setupViews(asset: PHAsset) {
        self.imageViewHeightConstraint.constant = UIScreen().screenWidth()
        let orderBackViewCornerRadius = CGRectGetHeight(self.orderBackView.frame) / 2
        self.orderBackView.layer.cornerRadius = orderBackViewCornerRadius
        self.isVideoImageView.hidden = asset.mediaType == .Image
        self.cropButton.hidden = asset.mediaType == .Video
        self.addressLabel.text = NSLocalizedString("Label.Loading", comment: String())
        self.changeAddressButton.setTitle(NSLocalizedString("Button.Change", comment: String()).uppercaseString, forState: .Normal)
        self.addLocationButton.setTitle(NSLocalizedString("Button.AddLocation", comment: String()).uppercaseString, forState: .Normal)
        self.descriptionTextView.placeholder = NSLocalizedString("Text.Placeholder.AddDescription", comment: String())
    }
    
    func populateOrder(draft: StoryPointDraft) {
        self.delegate?.getIndexOfObject(draft, completion: { [weak self] (index, count) in
            let order = index + 1
            self?.orderLabel.text = String(format: NSLocalizedString("Label.StoryAddInfoPostsOrder", comment: String()), order, count)
        })
    }
    
    func populateImage(asset: PHAsset) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            
            let targetSize = CGSizeMake(CGFloat(asset.pixelWidth), CGFloat(asset.pixelHeight))
            self.imageManager.requestImageForAsset(asset, targetSize: targetSize, contentMode: .AspectFill, options: nil) { [weak self] (result, info) in
                
                dispatch_async(dispatch_get_main_queue(), {
                    self?.assetImageView.image = result
                })
            }
        })
    }
    
    func manageLocation(draft: StoryPointDraft) {
        if draft.coordinate != nil {
            self.retrieveLocationIfNeeded(draft)
        } else {
            self.populateEmptyLocation()
        }
    }
    
    func retrieveLocationIfNeeded(draft: StoryPointDraft) {
        if draft.address.characters.count > 0 {
            self.populateLocation(draft.address)
        } else {
            GeocoderHelper.placeFromCoordinate(draft.coordinate) { [weak self] (addressString) in
                draft.address = addressString
                self?.populateLocation(addressString)
            }
        }
    }
    
    func populateLocation(address: String) {
        self.addressLabel.text = address
        self.addressImageView.image = UIImage(named: CellImages.locationGrey)
        self.addressLabel.textColor = UIColor.blackColor().colorWithAlphaComponent(kLocationLabelTextColorAlphaDefault)
        self.locationView.backgroundColor = UIColor.whiteColor()
        self.changeAddressButton.hidden = false
        self.addLocationButton.hidden = true
    }
    
    func populateEmptyLocation() {
        self.addressLabel.text = NSLocalizedString("Label.LocationRequired", comment: String())
        self.addressImageView.image = UIImage(named: CellImages.locationPink)
        self.addressLabel.textColor = UIColor.redPink()
        self.locationView.backgroundColor = UIColor.redPink().colorWithAlphaComponent(0.05)
        self.changeAddressButton.hidden = true
        self.addLocationButton.hidden = false
    }
    
    // MARK: - actions
    @IBAction func addLocationTapped(sender: UIButton) {
        self.delegate?.addLocationDidTap({ [weak self] (location, address) in
            self?.draft?.address = address
            self?.draft?.coordinate = location
            self?.populateLocation(address)
        })
    }
    
    @IBAction func changeLocationTapped(sender: UIButton) {
        self.delegate?.addLocationDidTap({ [weak self] (location, address) in
            self?.draft?.address = address
            self?.draft?.coordinate = location
            self?.populateLocation(address)
        })
    }
    
    class func contentHeight() -> CGFloat {
        let imageViewHeight: CGFloat = UIScreen().screenWidth()
        return kCellTopMargin + imageViewHeight + kCellLocationViewHeight + kCellDescriptionViewHeight
    }
}
