//
//  RecommendedSettingsViewController.swift
//  Maplify
//
//  Created by jowkame on 31.03.16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import Foundation

class RecommendedSettingsViewController: ViewController {
    @IBOutlet weak var pushNotificationsSwitch: UISwitch!
    @IBOutlet weak var locationSwitch: UISwitch!
    @IBOutlet weak var pushNotificationsTitleLabel: UILabel!
    @IBOutlet weak var pushNotificationsDescriptionLabel: UILabel!
    @IBOutlet weak var locationTitleLabel: UILabel!
    @IBOutlet weak var locationDescriptionTitleLabel: UILabel!
    
    // MARK: - view controller life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setup()
    }
    
    // MARK: - setup
    func setup() {
        self.setupLabels()
        self.setupDoneButton()
        self.setupDefaultSettings()
    }
    
    func setupLabels() {
        self.title = NSLocalizedString("Controller.RecommendedSettings.Title", comment: String())
        self.pushNotificationsTitleLabel.text = NSLocalizedString("Label.Switch.PushNotification", comment: String())
        self.pushNotificationsDescriptionLabel.text = NSLocalizedString("Label.Switch.PushNotificationDescription", comment: String())
        self.locationTitleLabel.text = NSLocalizedString("Label.Switch.Location", comment: String())
        self.locationDescriptionTitleLabel.text = NSLocalizedString("Label.Switch.LocationDescription", comment: String())
    }
    
    func setupDoneButton() {
        self.addRightBarItem(NSLocalizedString("Button.Done", comment: String()))
    }
    
    func setupDefaultSettings() {
        SessionHelper.sharedManager.setPushNotificationsEnabled(true)
        SessionHelper.sharedManager.setLocationEnabled(true)
    }
    
    //MARK: - actions
    @IBAction func pushNotificationSwitchDidChangeValue(sender: AnyObject) {
        let enabled = self.pushNotificationsSwitch.on
        SessionHelper.sharedManager.setPushNotificationsEnabled(enabled)
    }
    
    @IBAction func locationSwitchDidChangeValue(sender: AnyObject) {
        let enabled = self.locationSwitch.on
        SessionHelper.sharedManager.setLocationEnabled(enabled)
    }
    
    override func rightBarButtonItemDidTap() {
        self.routesSetContentController()
    }
}