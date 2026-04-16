//
//  ReactionView.swift
//  EmojisReactionKit
//
//  Created by iKʜAʟED〆 on 07/05/2025.
//  Copyright © 2025. All rights reserved.
//

import UIKit

class ReactionView: UIView {
    
    /// Width of the trailing pill when the system emoji keyboard is shown (`more` only).
    private static let keyboardCollapsedChromeWidth = REACTION.getWidth(count: 1) + 16
    
    private var _emojis: [String] = []
    private var emojis: [String] = []
    private var selectedEmoji: String?
    private var isAnimationEnabled:Bool = true
    private var direction: ReactionDirection = .leading
    private var isMoreButtonEnabled:Bool = true
    private var currentlyHighlightedIndex:IndexPath?
    private var isAnimationDone:Bool = false
    private var isPanChanged = false
    private var pendingEntranceAnimationIndices: Set<Int> = []
    /// When `true`, the quick emoji strip is hidden for the system emoji keyboard; pan and duplicate more taps are ignored.
    private var isSystemEmojiKeyboardMode = false
    
    weak var delegate:ReactionViewDelegate?

    private let liquidGlassBackgroundView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: nil)
        view.isUserInteractionEnabled = true
        view.clipsToBounds = false
        return view
    }()
    
    /// Trailing-pinned background (liquid glass or solid) whose width animates for the keyboard state; the `ReactionView` frame stays full width so the more button does not move.
    private let reactionPillChrome: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        view.isUserInteractionEnabled = false
        return view
    }()
    
    private var chromeLeadingConstraint: NSLayoutConstraint!
    private var chromeTrailingConstraint: NSLayoutConstraint!
    private var chromeWidthConstraint: NSLayoutConstraint!

    private var isUsingLiquidGlass: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
    
    override var backgroundColor: UIColor? {
        didSet {
            if isUsingLiquidGlass {
                super.backgroundColor = .clear
                self.backButtonBg.backgroundColor = .clear
                reactionPillChrome.backgroundColor = .clear
            } else {
                super.backgroundColor = backgroundColor
                self.backButtonBg.backgroundColor = backgroundColor
                reactionPillChrome.backgroundColor = backgroundColor
            }
        }
    }
    
    private let collectionContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        return view
    }()
    
    private let backButtonBg: UIView = {
        let view = UIView()
        view.layer.cornerRadius = REACTION.ITEM_SIZE.height / 2
        return view
    }()
    
    private let moreButton: UIButton = {
        let button = UIButton()
        button.clipsToBounds = true
        button.layer.cornerRadius = REACTION.ITEM_SIZE.height / 2
        button.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        button.alpha = 0
        return button
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = RTLCollectionFlow()
        layout.scrollDirection = .horizontal
        layout.itemSize = REACTION.ITEM_SIZE
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        layout.sectionInset = .zero
        
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(EmojiCellView.self, forCellWithReuseIdentifier: EmojiCellView.identifier)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.clipsToBounds = false
        return collectionView
    }()
    
    
    init(_ config: ReactionConfig) {
        super.init(frame: .zero)
        let baseEmojis = config.emojis ?? []
        if let selected = config.selectedEmoji, !selected.isEmpty, !baseEmojis.contains(selected) {
            self._emojis = baseEmojis + [selected]
        } else {
            self._emojis = baseEmojis
        }
        self.selectedEmoji = config.selectedEmoji
        self.direction = config.startFrom
        self.isAnimationEnabled = config.emojiEnteranceAnimated
        self.isMoreButtonEnabled = config.moreButton
        configureView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }
    
    private func configureView() {
        setupView()
        buildView()
        makeConstraints()
    }
    
    private func setupView() {
        self.clipsToBounds = false
        configureLiquidGlassIfNeeded()
        backButtonBg.isHidden = !isMoreButtonEnabled
        moreButton.isHidden = !isMoreButtonEnabled
        moreButton.addTarget(self, action: #selector(didClickButton), for: .touchUpInside)
    }
    
    private func buildView() {
        self.insertSubview(reactionPillChrome, at: 0)
        reactionPillChrome.addSubview(liquidGlassBackgroundView)
        self.addSubview(collectionContainerView)
        collectionContainerView.addSubview(collectionView)
        self.addSubview(backButtonBg)
        self.addSubview(moreButton)
    }
    
    
    private func makeConstraints() {
        liquidGlassBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        collectionContainerView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        moreButton.translatesAutoresizingMaskIntoConstraints = false
        backButtonBg.translatesAutoresizingMaskIntoConstraints = false

        chromeTrailingConstraint = reactionPillChrome.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        chromeLeadingConstraint = reactionPillChrome.leadingAnchor.constraint(equalTo: self.leadingAnchor)
        chromeWidthConstraint = reactionPillChrome.widthAnchor.constraint(equalToConstant: Self.keyboardCollapsedChromeWidth)
        chromeWidthConstraint.isActive = false
        
        NSLayoutConstraint.activate([
            reactionPillChrome.topAnchor.constraint(equalTo: self.topAnchor),
            reactionPillChrome.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            chromeTrailingConstraint,
            chromeLeadingConstraint,

            liquidGlassBackgroundView.topAnchor.constraint(equalTo: reactionPillChrome.topAnchor),
            liquidGlassBackgroundView.bottomAnchor.constraint(equalTo: reactionPillChrome.bottomAnchor),
            liquidGlassBackgroundView.leadingAnchor.constraint(equalTo: reactionPillChrome.leadingAnchor),
            liquidGlassBackgroundView.trailingAnchor.constraint(equalTo: reactionPillChrome.trailingAnchor),

            // collectionContainerView constraints
            collectionContainerView.topAnchor.constraint(equalTo: self.topAnchor, constant: -50),
            collectionContainerView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            collectionContainerView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            collectionContainerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),

            // collectionView constraints
            collectionView.topAnchor.constraint(equalTo: collectionContainerView.topAnchor, constant: 50),
            collectionView.leadingAnchor.constraint(equalTo: collectionContainerView.leadingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: collectionContainerView.bottomAnchor),
            collectionView.trailingAnchor.constraint(equalTo: collectionContainerView.trailingAnchor, constant: -(8 + (isMoreButtonEnabled ? REACTION.ITEM_SIZE.width : 0))),
        ])
        
        if isMoreButtonEnabled {
            NSLayoutConstraint.activate([
                // moreButton constraints
                moreButton.leadingAnchor.constraint(equalTo: collectionView.trailingAnchor),
                moreButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
                moreButton.widthAnchor.constraint(equalToConstant: REACTION.ITEM_SIZE.width),
                moreButton.heightAnchor.constraint(equalToConstant: REACTION.ITEM_SIZE.height),
                
                // backButtonBg constraints
                backButtonBg.leadingAnchor.constraint(equalTo: moreButton.leadingAnchor, constant: 2),
                backButtonBg.trailingAnchor.constraint(equalTo: moreButton.trailingAnchor),
                backButtonBg.topAnchor.constraint(equalTo: moreButton.topAnchor),
                backButtonBg.bottomAnchor.constraint(equalTo: moreButton.bottomAnchor)
            ])
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        let pillCornerRadius = bounds.height > 0 ? bounds.height / 2 : REACTION.ITEM_SIZE.height / 2
        reactionPillChrome.layer.cornerRadius = reactionPillChrome.bounds.height > 0
            ? reactionPillChrome.bounds.height / 2
            : pillCornerRadius
        
        if isUsingLiquidGlass {
            layer.mask = nil
            self.layer.cornerRadius = 0
            liquidGlassBackgroundView.layer.cornerRadius = reactionPillChrome.layer.cornerRadius
            liquidGlassBackgroundView.layer.masksToBounds = false
            return
        }

        // this mask allows us to make horizontal clipsToBounds only
        let maskLayer = CAShapeLayer()
        let horizontalClipRect = CGRect(x: 0, y: -200, width: bounds.width, height: bounds.height + 400)
        let cornerRadius: CGFloat = REACTION.ITEM_SIZE.height / 2
        let path = UIBezierPath(roundedRect: horizontalClipRect, cornerRadius: cornerRadius)
        maskLayer.path = path.cgPath
        layer.mask = maskLayer

        self.layer.cornerRadius = pillCornerRadius
        liquidGlassBackgroundView.layer.cornerRadius = reactionPillChrome.layer.cornerRadius
        liquidGlassBackgroundView.layer.masksToBounds = true
    }
    
    deinit{}
    
    @objc private func didClickButton() {
        guard !isSystemEmojiKeyboardMode, isAnimationDone else { return }
        self.delegate?.didSelectMoreButton()
    }
    
    func startAnimating() {
        isAnimationDone = false
        pendingEntranceAnimationIndices.removeAll()
        guard !direction.isCenter(), isAnimationEnabled else {
            if isMoreButtonEnabled {
                self.moreButton.transform = .identity
                self.moreButton.alpha = 1
            }
            self.loadData()
            isAnimationDone = true
            return
        }
        if isMoreButtonEnabled {
            self.moreButton.zoomInBounce(duration: direction.isLeading() ? 0.2 : 0.3, options: [.curveEaseInOut], delay: 0.1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.loadData()
        }
    }
    
    func setSuppressedEmojiCollectionForSystemKeyboard(_ suppressed: Bool, animated: Bool) {
        guard isMoreButtonEnabled else { return }
        isSystemEmojiKeyboardMode = suppressed
        collectionView.isUserInteractionEnabled = !suppressed
        let apply = {
            self.applyPillChromeKeyboardCollapsedLayout(suppressed)
            self.collectionView.alpha = suppressed ? 0 : 1
            self.collectionView.transform = .identity
        }
        if animated {
            UIView.animate(
                withDuration: 0.32,
                delay: 0,
                usingSpringWithDamping: 0.86,
                initialSpringVelocity: 0.35,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: apply
            )
        } else {
            apply()
        }
    }
    
    /// Pins the pill background to the trailing edge with a narrow width (keyboard) or expands it to fill the bar.
    private func applyPillChromeKeyboardCollapsedLayout(_ collapsed: Bool) {
        chromeLeadingConstraint.isActive = !collapsed
        chromeWidthConstraint.isActive = collapsed
        if !isUsingLiquidGlass {
            if collapsed {
                reactionPillChrome.backgroundColor = backButtonBg.backgroundColor
                super.backgroundColor = .clear
            } else {
                let fill = reactionPillChrome.backgroundColor ?? backButtonBg.backgroundColor
                super.backgroundColor = fill
                reactionPillChrome.backgroundColor = fill
            }
        }
        layoutIfNeeded()
    }
    
    func setupIcon(_ image: UIImage){
        self.moreButton.tintColor = .secondaryLabel
        self.moreButton.setPreferredSymbolConfiguration(
            UIImage.SymbolConfiguration(pointSize: 22, weight: .regular),
            forImageIn: .normal
        )
        self.moreButton.setImage(image.withRenderingMode(.alwaysTemplate), for: .normal)
    }

    private func configureLiquidGlassIfNeeded() {
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .regular)
            glassEffect.isInteractive = true
            liquidGlassBackgroundView.effect = glassEffect
            liquidGlassBackgroundView.isUserInteractionEnabled = true
            super.backgroundColor = .clear
            backButtonBg.backgroundColor = .clear
            reactionPillChrome.backgroundColor = .clear
        } else {
            liquidGlassBackgroundView.effect = nil
            liquidGlassBackgroundView.isUserInteractionEnabled = false
        }
    }
}

// MARK: - Load Data
extension ReactionView {
    func loadData(){
        self.emojis = _emojis
        if !withoutAnimation() {
            pendingEntranceAnimationIndices = Set(0..<emojis.count)
            isAnimationDone = emojis.isEmpty
        }
        self.collectionView.reloadData()
    }
}

// MARK: - Receive pan gesture
extension ReactionView {
    func panned(gestureRecognizer: UIGestureRecognizer) -> CGPoint? {
        if isSystemEmojiKeyboardMode {
            return nil
        }
        let isFinished = gestureRecognizer.isFinished()
        if gestureRecognizer.state == .began || gestureRecognizer.isChanged() {
            isPanChanged = true
        }
        if isFinished {
            defer { isPanChanged = false }
        }
        // Normal flow requires at least one begin/change. But still allow terminal `.ended` to pick
        // the emoji under the finger when the touch started elsewhere (cell/menu) and ended on emoji.
        guard isPanChanged || isFinished else { return nil }
        let exactPanPoint = gestureRecognizer.location(in: collectionView)
        // i give some margin to the touch area so the emoji start highlighted before reaching its exact area
        let marginPanPoint = CGPoint(x: exactPanPoint.x, y: exactPanPoint.y - REACTION.TOUCH_AREA_MARGIN)

        guard let indexPath = collectionView.indexPathForItem(at: marginPanPoint) ?? collectionView.indexPathForItem(at: exactPanPoint), collectionView.indexPathsForVisibleItems.contains(indexPath) else {
            // If we pan outside the table and there's a cell selected, unselect it
            if let currentlyHighlightedIndex  {
                highlightCell(false, at: currentlyHighlightedIndex)
            }
            self.currentlyHighlightedIndex = nil
            return checkButtonHighlight(gestureRecognizer: gestureRecognizer)
        }
        highlightButton(false)
        if isFinished, currentlyHighlightedIndex == nil {
            // Pan can begin late (or only deliver an end state) when the user presses/holds with
            // little movement. In that case, still treat release on an emoji as a selection.
            selectEmoji(atIndex: indexPath)
            return exactPanPoint
        }
        
        guard indexPath != currentlyHighlightedIndex else {
            if isFinished {
                highlightCell(false, at: indexPath)
                selectEmoji(atIndex: indexPath)
            }
            return nil
        }
        
        if let currentlyHighlightedIndex  {
            highlightCell(false, at: currentlyHighlightedIndex)
        }
        
        self.currentlyHighlightedIndex = indexPath
        
        if isFinished {
            // Treat is as a tap
            selectEmoji(atIndex: indexPath)
        } else {
            highlightCell(true, at: indexPath)
        }
        return exactPanPoint
    }
    
    private func checkButtonHighlight(gestureRecognizer: UIGestureRecognizer) -> CGPoint?{
        guard isMoreButtonEnabled, !isSystemEmojiKeyboardMode, isAnimationDone else {return nil}
        let exactPanPoint = gestureRecognizer.location(in: moreButton)
        // i give some margin to the touch area so the emoji start highlighted before reaching its exact area
        let marginPanPoint = CGPoint(x: exactPanPoint.x, y: exactPanPoint.y - REACTION.TOUCH_AREA_MARGIN)
        let isHighlighted = moreButton.isHighlighted()
        if moreButton.bounds.contains(exactPanPoint) || moreButton.bounds.contains(marginPanPoint){
            highlightButton(true)
            if gestureRecognizer.isFinished() {
                highlightButton(false)
                self.didClickButton()
            }
            return isHighlighted ? nil : marginPanPoint
        }
        highlightButton(false)
        return nil
    }
    
    private func highlightCell(_ bool: Bool, at indexPath: IndexPath){
        guard let cell = self.collectionView.cellForItem(at: indexPath) as? EmojiCellView else { return }
        if bool { cell.animate() }
        else { cell.reset() }
    }
    
    private func highlightButton(_ bool: Bool){
        if bool { moreButton.animate() }
        else { moreButton.reset() }
    }
    
    private func selectEmoji(atIndex indexPath: IndexPath){
        guard isAnimationDone else { return }
        let emoji = emojis[indexPath.item]
        self.delegate?.didSelectEmoji(emoji)
    }

    private func animateTapSelectionAndSelect(at indexPath: IndexPath) {
        guard isAnimationDone else { return }
        guard let cell = collectionView.cellForItem(at: indexPath) as? EmojiCellView else {
            selectEmoji(atIndex: indexPath)
            return
        }
        cell.animate()
        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut]) {
            cell.emojiLabel.transform = CGAffineTransform(scaleX: 0.72, y: 0.72)
        } completion: { [weak self] _ in
            self?.selectEmoji(atIndex: indexPath)
        }
    }
}


// MARK: - UICollectionViewDataSource , UICollectionViewDelegate
extension ReactionView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return emojis.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCellView.identifier, for: indexPath) as? EmojiCellView else {
            return UICollectionViewCell()
        }
        cell.setEmoji(emoji: emojis[indexPath.item], selectedEmoji: selectedEmoji)
        if !withoutAnimation() {
            cell.contentView.alpha = 0
            cell.contentView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard isAnimationDone else { return }
        animateTapSelectionAndSelect(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !withoutAnimation() {
            let delay = direction.isLeading() ? 0.03 * Double(indexPath.item) : 0.03 * Double(emojis.count - 1 - indexPath.item)
            cell.contentView.zoomInBounce(delay: delay) { [weak self] _ in
                guard let self else { return }
                self.pendingEntranceAnimationIndices.remove(indexPath.item)
                if self.pendingEntranceAnimationIndices.isEmpty {
                    self.isAnimationDone = true
                }
            }
        }else {
            cell.contentView.alpha = 1
            cell.contentView.transform = .identity
        }
    }
    
    private func withoutAnimation() -> Bool {
        return !isAnimationEnabled || isAnimationDone || direction.isCenter()
    }
}

// MARK: - Emoji Protocol
protocol ReactionViewDelegate: AnyObject {
   @MainActor func didSelectEmoji(_ emoji: String)
    @MainActor func didSelectMoreButton()
}

// MARK: - private BaseUIButton extension
fileprivate extension UIButton {
    func animate() {
        guard self.transform == .identity else {return}
        self.backgroundColor = .clear
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveLinear], animations: {
            // Shrink in place while highlighted (match emoji cells)
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }, completion: nil)
    }
    
    func reset(duration: TimeInterval = 0.15, options : UIView.AnimationOptions = [.curveLinear], delay: TimeInterval = 0 ) {
        guard self.transform != .identity else {return}
        UIView.animate(withDuration: duration, delay: delay, options: options, animations: {
            self.transform = .identity
            self.alpha = 1
        }, completion: { _ in
            self.backgroundColor = self.superview?.backgroundColor
        })
    }
    
    func isHighlighted() -> Bool {
        return self.transform != .identity
    }
}

