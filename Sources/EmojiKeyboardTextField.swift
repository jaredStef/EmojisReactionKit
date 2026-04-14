//
//  EmojiKeyboardTextField.swift
//  EmojisReactionKit
//

import UIKit

/// A minimal text field used only to become first responder and receive emoji input from the system keyboard.
/// See [Stack Overflow](https://stackoverflow.com/questions/11382753/change-the-ios-keyboard-layout-to-emoji) for the `textInputMode` pattern.
final class EmojiKeyboardTextField: UITextField, UITextFieldDelegate {
    var onEmojiInserted: ((String) -> Void)?

    override var textInputMode: UITextInputMode? {
        for mode in UITextInputMode.activeInputModes {
            if mode.primaryLanguage?.lowercased() == "emoji" {
                return mode
            }
        }
        return super.textInputMode
    }

    override var textInputContextIdentifier: String? {
        ""
    }

    init() {
        super.init(frame: .zero)
        self.delegate = self
        self.autocorrectionType = .no
        self.autocapitalizationType = .none
        self.spellCheckingType = .no
        self.textContentType = nil
        self.borderStyle = .none
        self.backgroundColor = .clear
        self.tintColor = .clear
        self.textColor = .clear
        self.alpha = 0.02
        self.isAccessibilityElement = false
        self.accessibilityElementsHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.isEmpty {
            return true
        }
        onEmojiInserted?(string)
        return false
    }
}
