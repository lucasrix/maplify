//
//  PhotoViewController.swift
//  PhotoViewController
//
//  Created by Evgeniy Antonoff on 3/30/16.
//  Copyright © 2016 Evgeniy Antonoff. All rights reserved.
//

import LLSimpleCamera
import UIKit
import CoreMedia
import AVFoundation

let nibNamePhotoControllerView = "PhotoViewController"
let kPhotoViewHeightIPhone3_5: CGFloat = 240
let kPhotoDeleteButtonTopMarginIPhone3_5: CGFloat = 0
let kDeleteButtonHighlitedStateAlpha: CGFloat = 0.5

class PhotoViewController: UIViewController {
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var shotButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var previewViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var deleteButtonTopConstraint: NSLayoutConstraint!
    
    var simpleCamera: LLSimpleCamera! = nil
    var delegate: PhotoControllerDelegate! = nil
    var cameraStatePhoto = true
    
    // MARK: - view controller life cycle
    override func loadView() {
        super.viewDidLoad()
        
        if let view = UINib(nibName: nibNamePhotoControllerView, bundle: NSBundle(forClass: self.classForCoder)).instantiateWithOwner(self, options: nil).first as? UIView {
            self.view = view
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setup()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    // MARK: - setup
    func setup() {
        self.setupViews()
        self.setupCamera()
        self.setupBottomButtons()
    }
    
    func setupViews() {
        if UIScreen().isIPhoneScreenSize3_5() {
            self.previewViewHeightConstraint.constant = kPhotoViewHeightIPhone3_5
            self.deleteButtonTopConstraint.constant = kPhotoDeleteButtonTopMarginIPhone3_5
        } else {
            self.previewViewHeightConstraint.constant = UIScreen().screenWidth()
        }
    }
    
    func setupCamera() {
        AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { [weak self] (alowedAccess) -> () in
            dispatch_async(dispatch_get_main_queue(), { () -> () in
                if alowedAccess {
                    self?.configureCamera()
                } else {
                    self?.delegate?.photoCameraUnauthorized()
                }
            })
        })
    }
    
    func configureCamera() {
        self.simpleCamera = LLSimpleCamera(quality: AVCaptureSessionPresetHigh, position: LLCameraPositionRear, videoEnabled: false)
        self.updateUI()
        self.simpleCamera.start()
        self.configureChildViewController(self.simpleCamera, onView: self.cameraView)
    }
    
    func setupBottomButtons() {
        // shot button
        self.shotButton.setImage(UIImage(named: MediaButtons.photoShotHighlited), forState: [.Highlighted, .Selected])
        
        // delete button
        self.deleteButton.setTitleColor(UIColor.whiteColor().colorWithAlphaComponent(kDeleteButtonHighlitedStateAlpha), forState: .Selected)
        self.deleteButton.setTitleColor(UIColor.whiteColor().colorWithAlphaComponent(kDeleteButtonHighlitedStateAlpha), forState: .Highlighted)
        self.deleteButton.setTitleColor(UIColor.whiteColor().colorWithAlphaComponent(kDeleteButtonHighlitedStateAlpha), forState: [.Selected, .Highlighted])
        self.deleteButton.setTitle(NSLocalizedString("Button.Delete", comment: String()), forState: .Normal)
    }
    
    // MARK: - actions
    @IBAction func shotTapped(sender: UIButton) {
        if self.cameraStatePhoto {
            self.captureAction()
        }
    }
    
    @IBAction func cameraModeTapped(sender: UIButton) {
        if self.cameraStatePhoto {
            self.simpleCamera.togglePosition()
            self.flashButton.hidden = self.simpleCamera.position == LLCameraPositionFront
        }
    }
    
    @IBAction func flashTapped(sender: UIButton) {
        var flash = self.simpleCamera.flash
        if self.simpleCamera.flash == LLCameraFlashAuto {
            flash = LLCameraFlashOn
        } else if self.simpleCamera.flash == LLCameraFlashOn {
            flash = LLCameraFlashOff
        } else if self.simpleCamera.flash == LLCameraFlashOff {
            flash = LLCameraFlashAuto
        }
        self.simpleCamera.updateFlashMode(flash)
        self.updateFlashIcon()
    }
    
    @IBAction func deleteTapped(sender: UIButton) {
        self.simpleCamera.start()
        self.toggleCameraMode()
    }
    
    // MARK: - private
    func captureAction() {
        self.simpleCamera.capture({ [weak self] (camera, image, dict, error) -> () in
            if let capturedImage = image {
                let correctOrientedImage = capturedImage.correctlyOrientedImage()
                self?.toggleCameraMode()
                self?.simpleCamera.stop()
                self?.previewImageView.image = correctOrientedImage.cropToSquare()
            }
        })
    }
    
    func toggleCameraMode() {
        self.cameraStatePhoto = !self.cameraStatePhoto
        self.updateUI()
    }
    
    func updateUI() {
        self.previewImageView.hidden = self.cameraStatePhoto
        self.deleteButton.hidden = self.cameraStatePhoto
    }
    
    func updateFlashIcon() {
        var flashImageString = String()
        if self.simpleCamera.flash == LLCameraFlashAuto {
            flashImageString = MediaButtons.flashAuto
        } else if self.simpleCamera.flash == LLCameraFlashOn {
            flashImageString = MediaButtons.flashOn
        } else if self.simpleCamera.flash == LLCameraFlashOff {
            flashImageString = MediaButtons.flashOff
        }
        self.flashButton.setImage(UIImage(named: flashImageString), forState: .Normal)
    }
    
    func donePressed() {
        if !self.previewImageView.hidden {
            let imageData = UIImagePNGRepresentation(self.previewImageView.image!)
            self.delegate?.photoDidTake(imageData!)
        } else {
            self.delegate?.photoDidTake(nil)
        }
    }
}

protocol PhotoControllerDelegate {
    func photoDidTake(imageData: NSData!)
    func photoCameraUnauthorized()
}
