//
//  TTTAttributedLabelUtils.swift
//  Maplify
//
//  Created by Sergey on 3/4/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import TTTAttributedLabel

extension TTTAttributedLabel {
    func setupDefaultAttributes(str: String, textColor: UIColor, font: UIFont, delegate: TTTAttributedLabelDelegate) {
        let paragraphStyle = NSMutableParagraphStyle()
        let attributedString = NSAttributedString(string: str, attributes: [
            NSFontAttributeName: font,
            NSParagraphStyleAttributeName: paragraphStyle,
            NSForegroundColorAttributeName: textColor.CGColor,
            ])
        self.numberOfLines = 0
        self.delegate = delegate
        self.setText(attributedString)
    }
    
    func setupLinkAttributes(linkColor: UIColor, underlined: Bool) {
        let underlineStyle = underlined ? NSUnderlineStyle.StyleSingle.rawValue : NSUnderlineStyle.StyleNone.rawValue

        let linkAttributes = [
            NSForegroundColorAttributeName: linkColor,
            NSUnderlineStyleAttributeName: NSNumber(long: underlineStyle),
        ]
        let activeLinkAttributes = [
            NSForegroundColorAttributeName: linkColor,
            NSUnderlineStyleAttributeName: NSNumber(long: underlineStyle),
        ]
        
        self.linkAttributes = linkAttributes
        self.activeLinkAttributes = activeLinkAttributes
    }
    
    func addURLLink(link: String, str: String, rangeStr: String) {
        if let encodedString = link.stringByAddingPercentEncodingWithAllowedCharacters(
            NSCharacterSet.URLFragmentAllowedCharacterSet()) {
            let linkRange = (str as NSString).rangeOfString(rangeStr)
            let url = NSURL(string:encodedString)
            self.addLinkToURL(url, withRange:linkRange)
        }
    }
}
