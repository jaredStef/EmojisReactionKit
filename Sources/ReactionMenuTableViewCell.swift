//
//  ReactionMenuTableViewCell.swift
//  EmojisReactionKit
//
//  Created by iKʜAʟED〆 on 07/05/2025.
//  Copyright © 2025 example. All rights reserved.
//

import UIKit

class ReactionMenuTableViewCell: UITableViewCell {

    var menuTitle: String = "" {
        didSet {
            menuTitleLabel.text = menuTitle
        }
    }
    
    var isDestructive: Bool = false {
        didSet { applyMenuRowAppearance() }
    }

    /// Informational row (``ReactionMenuLabel``); not highlighted like a button.
    var isMenuLabel: Bool = false {
        didSet {
            accessibilityTraits = isMenuLabel ? [.staticText] : [.button]
            applyMenuRowAppearance()
        }
    }
    
    var iconImage: UIImage? {
        didSet {
            iconImageView.image = iconImage
        }
    }
    
    override var accessibilityHint: String? {
        get {
            return menuTitle
        } set {
            super.accessibilityHint = newValue
        }
    }
    
    private let menuTitleLabel: UILabel = UILabel()
    private let iconImageView: UIImageView = UIImageView()
    private let selectionPillView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.alpha = 0
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        accessibilityTraits = [.button]

        contentView.preservesSuperviewLayoutMargins = false
        contentView.insetsLayoutMarginsFromSafeArea = false
        var margins = contentView.layoutMargins
        margins.top = 0
        margins.bottom = 0
        contentView.layoutMargins = margins
        
        menuTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        menuTitleLabel.numberOfLines = 1
        menuTitleLabel.lineBreakMode = .byTruncatingTail

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        selectionPillView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(selectionPillView)
        contentView.addSubview(menuTitleLabel)
        contentView.addSubview(iconImageView)

        if #available(iOS 26.0, *) {
            let titleFont = UIFont.systemFont(ofSize: 16.0, weight: .regular)
            menuTitleLabel.font = titleFont
            iconImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)

            selectionPillView.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.14)
            selectionPillView.layer.masksToBounds = true
            // True stadium end caps: corner radius must be half the height (`.continuous` + oversized radius bows the sides).
            selectionPillView.layer.cornerCurve = .circular

            let sideInset: CGFloat = 6
            // Menu edge → icon: native 100px vs ours 80px (same scale), ratio applied to 24pt leading baseline.
            let iconLeadingInset: CGFloat = (24.0 * 100.0 / 80.0).rounded()
            // Horizontal gap icon→title: native 57px vs ours 33px (same scale), ratio applied to 6pt baseline.
            let iconToTitleSpacing: CGFloat = (6.0 * 57.0 / 33.0).rounded()
            // Pin label to a one-line height and center it so text is not vertically floating in a tall frame.
            let titleLineHeight = ceil(titleFont.lineHeight)
            NSLayoutConstraint.activate([
                selectionPillView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sideInset),
                selectionPillView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sideInset),
                selectionPillView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
                selectionPillView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 0),

                iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: iconLeadingInset),
                iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                iconImageView.widthAnchor.constraint(equalToConstant: 20),
                iconImageView.heightAnchor.constraint(equalToConstant: 20),

                menuTitleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: iconToTitleSpacing),
                menuTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
                menuTitleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                menuTitleLabel.heightAnchor.constraint(equalToConstant: titleLineHeight),
            ])
        } else {
            menuTitleLabel.font = UIFont.systemFont(ofSize: 16.0, weight: .regular)
            iconImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)

            let horizontalPadding: CGFloat = 17.0
            let verticalPadding: CGFloat = 2.0
            let iconTrailingOffset: CGFloat = 27.0
            let titleToIconMinSpacing: CGFloat = -16.0
            
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: menuTitleLabel.leadingAnchor, constant: -horizontalPadding),
                contentView.topAnchor.constraint(equalTo: menuTitleLabel.topAnchor, constant: -verticalPadding),
                contentView.bottomAnchor.constraint(equalTo: menuTitleLabel.bottomAnchor, constant: verticalPadding),
                menuTitleLabel.trailingAnchor.constraint(equalTo: iconImageView.leadingAnchor, constant: titleToIconMinSpacing),
                
                contentView.trailingAnchor.constraint(equalTo: iconImageView.centerXAnchor, constant: iconTrailingOffset),
                contentView.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            ])
        }
        
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) { fatalError("\(#file) does not implement coder.") }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        if isMenuLabel {
            super.setSelected(false, animated: false)
            return
        }
        super.setSelected(selected, animated: animated)
        if #available(iOS 26.0, *) {
            updateSelectionPill(selected, animated: animated)
            backgroundColor = .clear
        } else {
            backgroundColor = selected ? UIColor(white: 0.5, alpha: 0.2) : .clear
        }
    }
    
    func highlight(_ highlighted: Bool, animated: Bool) {
        if isMenuLabel { return }
        if #available(iOS 26.0, *) {
            updateSelectionPill(highlighted, animated: animated)
            backgroundColor = .clear
        } else {
            backgroundColor = highlighted ? UIColor(white: 0.5, alpha: 0.2) : .clear
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if #available(iOS 26.0, *) {
            let h = selectionPillView.bounds.height
            guard h > 0 else { return }
            selectionPillView.layer.cornerRadius = h / 2
        }
    }

    private func applyMenuRowAppearance() {
        let titleColor: UIColor
        let iconTint: UIColor
        if isDestructive {
            titleColor = .systemRed
            iconTint = .systemRed
        } else if isMenuLabel {
            titleColor = .secondaryLabel
            iconTint = .secondaryLabel
        } else {
            titleColor = .label
            iconTint = .label
        }
        menuTitleLabel.textColor = titleColor
        iconImageView.tintColor = iconTint
    }

    private func updateSelectionPill(_ isVisible: Bool, animated: Bool) {
        if #available(iOS 26.0, *) {
            // Row chrome is driven by ``ReactionPreviewView``'s sliding overlay to match system menus.
            selectionPillView.alpha = 0
            return
        }
        let changes = {
            self.selectionPillView.alpha = isVisible ? 1 : 0
        }
        if animated {
            UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseInOut], animations: changes)
        } else {
            changes()
        }
    }
}
