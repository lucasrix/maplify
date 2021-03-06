//
//  InputTextView.swift
//  Maplify
//
//  Created by Sergey on 3/10/16.
//  Copyright © 2016 rubygarage. All rights reserved.
//

import RSKGrowingTextView
import RSKKeyboardAnimationObserver

let kInitialTextViewHeight: CGFloat = 50
private let kTextDefaultOpacity: CGFloat = 0.55
private let kSeparatorLineViewAnimationDuration: NSTimeInterval = 0.3
private let kInputTextViewAlphaMin: CGFloat = 0.0
private let kInputTextViewAlphaMax: CGFloat = 1.0

class InputTextView: UIView, UITextViewDelegate {
    @IBOutlet weak var lineView: UIView!
    @IBOutlet weak var textView: RSKGrowingTextView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var iconHighlightedImageView: UIImageView!
    @IBOutlet weak var imageTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var textLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightDetailLabel: UILabel!
    @IBOutlet weak var leftDetailLabel: UILabel!
    
    var delegate: InputTextViewDelegate! = nil
    var maxCharLength: Int = 0 {
        didSet {
            self.showTextLengthLimitIfNeeded(Int(0))
        }
    }
    var view: UIView! = nil
    private var isVisibleKeyboard = true
    
    // MARK: - init
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    // MARK: - setup
    private func setup() {
        self.view = NSBundle.mainBundle().loadNibNamed(String(InputTextView), owner: self, options: nil).first as? UIView
        if (self.view != nil) {
            self.view.frame = bounds
            self.addSubview(self.view)
            self.textView.delegate = self
        }
    }
    
    func registerForKeyboardNotifications(viewController: UIViewController) {
        viewController.rsk_subscribeKeyboardWithBeforeWillShowOrHideAnimation(nil,
            willShowOrHideAnimation: { [weak self] (keyboardRectEnd, duration, isShowing) -> Void in
                self!.isVisibleKeyboard = isShowing
                self!.adjustContentForKeyboardRect(keyboardRectEnd)
            }, onComplete: { [weak self] (finished, isShown) -> Void in
                self!.isVisibleKeyboard = isShown
            }
        )
        
        viewController.rsk_subscribeKeyboardWithWillChangeFrameAnimation(
            { [weak self] (keyboardRectEnd, duration) -> Void in
                self!.adjustContentForKeyboardRect(keyboardRectEnd)
            }, onComplete: nil)
    }
    
    private func adjustContentForKeyboardRect(keyboardRect: CGRect) {
        self.layoutIfNeeded()
    }
    
    func unregisterForKeyboardNotifications(viewController: UIViewController) {
        viewController.rsk_unsubscribeKeyboard()
    }
    
    func setupTextField(placeholder: String, defaultIconName: String!, highlitedIconName: String!) {
        self.textView.textColor = UIColor.whiteColor()
        self.textView.placeholder = placeholder
        self.textView.placeholderColor = UIColor.whiteColor().colorWithAlphaComponent(kTextDefaultOpacity)

        if (defaultIconName?.length > 0 && highlitedIconName?.length > 0) {
            self.iconImageView.image = UIImage(named: defaultIconName)
            self.iconHighlightedImageView.image = UIImage(named: highlitedIconName)
        } else {
            self.imageViewWidthConstraint.constant = 0
            self.imageTrailingConstraint.constant = 0
            self.textLeadingConstraint.constant = 0
        }
        self.setDefaultState()
    }
    
    private func updateViewWithAnimation(highlitedImageShow: Bool, errorShow: Bool, separatrorColor: UIColor) {
        self.delegate?.contentSizeWillChange?(self.textView.contentSize)
        UIView.animateWithDuration(kSeparatorLineViewAnimationDuration) { [weak self] () -> () in
            self?.lineView.backgroundColor = separatrorColor
            
            let iconAlpha: CGFloat = highlitedImageShow == true ? kInputTextViewAlphaMax : kInputTextViewAlphaMin
            let iconAlphaAnother: CGFloat = highlitedImageShow == false ? kInputTextViewAlphaMax : kInputTextViewAlphaMin
            self?.iconImageView.alpha = iconAlphaAnother
            self?.iconHighlightedImageView.alpha = iconAlpha
        }
    }
    
    func setDefaultState() {
        self.updateViewWithAnimation(false, errorShow: false, separatrorColor: UIColor.warmGrey())
    }
    
    func setHighlightedState() {
        self.updateViewWithAnimation(true, errorShow: false, separatrorColor: UIColor.dodgerBlue())
    }
    
    func showTextLengthLimitIfNeeded(charactersCount: Int) {
        let substringOf = NSLocalizedString("Substring.Of", comment: String())
        let substringChars = NSLocalizedString("Substring.Chars", comment: String())
        self.leftDetailLabel.text = "\(charactersCount) " + substringOf + " \(maxCharLength) " + substringChars
    }
    
    // MARK: - UITextViewDelegate
    func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        let resultCharacters = (self.textView.text as NSString).stringByReplacingCharactersInRange(range, withString: text)
        self.delegate?.textEditingChanged?(self, replacedText: resultCharacters)
        if resultCharacters.length <= maxCharLength {
            self.showTextLengthLimitIfNeeded(resultCharacters.length)
            self.setHighlightedState()
            return true
        }
        return false
    }
    
    func textViewDidBeginEditing(textView: UITextView) {
        self.setHighlightedState()
        self.delegate?.textEditingBegin?(self)
    }
    
    func textViewDidEndEditing(textView: UITextView) {
        self.setDefaultState()
        self.delegate?.textEditingEnd?(self)
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.delegate?.textDidPressReturnKey?(self)
        return true
    }
}

@objc protocol InputTextViewDelegate {
    optional func textEditingBegin(inputTextView: InputTextView)
    optional func textEditingEnd(inputTextView: InputTextView)
    optional func textEditingChanged(inputTextView: InputTextView, replacedText: String)
    optional func textDidPressReturnKey(inputTextView: InputTextView)
    optional func contentSizeWillChange(contentSize: CGSize)
}