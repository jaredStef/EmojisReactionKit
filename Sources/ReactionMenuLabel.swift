//
//  ReactionMenuLabel.swift
//  EmojisReactionKit
//

import UIKit

/// Non-interactive reaction menu rows (metadata such as timestamps).
///
/// Label rows use a reserved `UIAction` identifier and the `.disabled` attribute so they are not
/// selectable like ordinary actions, while keeping the same layout as other menu rows.
public enum ReactionMenuLabel {

    public static let actionIdentifier = UIAction.Identifier("com.emojisreactionkit.reactionMenuLabel")

    /// Returns `true` when the action was created with ``action(title:image:)``.
    public static func isLabel(_ action: UIAction) -> Bool {
        action.identifier == actionIdentifier
    }

    /// Builds a menu label row: secondary styling, no selection, same layout as other menu actions.
    public static func action(title: String, image: UIImage? = nil) -> UIAction {
        UIAction(
            title: title,
            image: image,
            identifier: actionIdentifier,
            attributes: [.disabled],
            handler: { _ in }
        )
    }
}
