//
//  ReactionMenuTableViewCell.swift
//  EmojisReactionKit
//
//  Created by iKʜAʟED〆 on 07/05/2025.
//  Copyright © 2025 example. All rights reserved.
//

import UIKit

class ReactionMenuTableViewCell: UITableViewCell {
    /// Matches the iOS 26 menu container radius (28) minus the row inset (4).
    private let selectionPillCornerRadius: CGFloat = 24.0

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
        
        menuTitleLabel.font = UIFont.systemFont(ofSize: 17.0, weight: .regular)
        menuTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        menuTitleLabel.numberOfLines = 1
        menuTitleLabel.lineBreakMode = .byTruncatingTail
        
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        selectionPillView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(selectionPillView)
        contentView.addSubview(menuTitleLabel)
        contentView.addSubview(iconImageView)

        if #available(iOS 26.0, *) {
            selectionPillView.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.22)
            selectionPillView.layer.cornerCurve = .continuous

            NSLayoutConstraint.activate([
                selectionPillView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
                selectionPillView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
                selectionPillView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
                selectionPillView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

                iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
                iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                iconImageView.widthAnchor.constraint(equalToConstant: 20),
                iconImageView.heightAnchor.constraint(equalToConstant: 20),

                menuTitleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
                menuTitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
                menuTitleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
                menuTitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            ])
        } else {
            let horizontalPadding: CGFloat = 17.0
            let verticalPadding: CGFloat = 12.0
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
            selectionPillView.layer.cornerRadius = selectionPillCornerRadius
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
