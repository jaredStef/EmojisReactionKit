//
//  ReactionPreviewView.swift
//  EmojisReactionKit
//
//  Created by iKʜAʟED〆 on 07/05/2025.
//  Copyright © 2025. All rights reserved.
//

import UIKit


public class ReactionPreviewView: UIView {
    
    /// Reference to the targeted view
    private weak var _hostingView: UIView?
    
    private var _config:ReactionConfig!
    
    private var _theme:ReactionTheme!
    
    /// container of views to control the translation
    private let container: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = true
        return view
    }()
    
    /// emojis view
    private var reactionView: ReactionView?
    
    /// menu blurry table view
    private var visualEffectView: UIVisualEffectView?
    private var menuTableView: UITableView?
    private var dataSource:UITableViewDiffableDataSource<UIMenu, UIAction>?
    
    /// haptic feedbacks
    private var feedbackGenerator:UIImpactFeedbackGenerator?
    private var selectionGenerator:UISelectionFeedbackGenerator?
    
    ///Used to power the "drag to select" functionality like the iOS version
    private let panGestureRecognizer: UIPanGestureRecognizer = UIPanGestureRecognizer()
    /// The caller-owned recognizer (typically long press) that should continue driving selection updates.
    private weak var continuedPanGestureRecognizer: UIGestureRecognizer?
    
    /// A blurred background view, applied only when Reduce Transparency is disabled in accessibility settings.
    private let blurBackgroundView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: nil)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }()
    
    /// A snapshot for the targeted view.
    private var snapshotView:UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    //MARK: - Custom propertis to be used inside the class
    /// A property to save the last highlighted index in menuTableView - used for pan
    private var currentlyHighlightedIndex:IndexPath?

    /// iOS 26: one shared pill that slides between rows (native-style). Created in ``setupMenuView()``.
    private var menuRowSelectionOverlayView: UIView?
    /// Debounces clearing the overlay when ``UITableView`` unhighlights before the next row highlights.
    private var menuOverlayRemovalWorkItem: DispatchWorkItem?
    /// Row the sliding menu pill is currently associated with (table delegate + pan).
    private var menuOverlayDisplayIndexPath: IndexPath?
    /// Check the state where the targeted view is resized vertically
    private var isSnapshotResizedV: Bool = false
    /// Check the state where the targeted view is resized horizontally
    private var isSnapshotResizedH: Bool = false
    /// Animator for background blur effect
    private var animator: UIViewPropertyAnimator?
    private var isDismissing: Bool = false
    /// Original rect for  targeted view
    private var originalRect:CGRect?
    ///
    /// Target view initial alpha
    /// Don't worry we save your view initial alpha ;)
    private var initialAlpha:CGFloat?
    
    //MARK: - Container frame properties
    private var initialY:CGFloat?
    private var initialHeight:CGFloat?
    private let defaultMargin:CGFloat = 8
    
    weak var delegate: ReactionPreviewDelegate?

    /// Hidden field used only to present the system keyboard in emoji mode.
    private let emojiKeyboardField = EmojiKeyboardTextField()
    /// While `true`, the action menu is collapsed and the emoji keyboard is intended to be visible.
    private var menuCollapsedForEmojiKeyboard = false
    private var isSystemEmojiKeyboardActive = false
    /// Preserves the adjusted (safe-area corrected) container position while entering emoji keyboard mode.
    private var keyboardCollapsedContainerOrigin: CGPoint?

    private var shouldUseBackgroundBlur: Bool {
        if #available(iOS 26.0, *) {
            return false
        }
        return !UIAccessibility.isReduceTransparencyEnabled
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    deinit {
        self.detachFromContinuedPanGesture()
    }
    
    init(_ view: UIView, with config: ReactionConfig, theme: ReactionTheme? = .default) {
        super.init(frame: .zero)
        // view should be visible in the window!
        guard let window = view.window else { return }
        
        self._hostingView = view
        
        self._config = config
        
        self._theme = theme
        
        if let emojis = config.emojis, !emojis.isEmpty {
            self.setupReactionView()
        }
        
        if let menu = config.menu, !menu.options.isEmpty {
            self.setupMenuView()
        }
        
        if config.enableFeedbackGeneration {
            self.enableFeedback()
        }
        
        if config.enablePanGesture {
            self.enablePanGesture()
            if let continuedPanGesture = config.continuedPanGesture {
                self.attachToContinuedPanGesture(continuedPanGesture)
            }
        }
        
        self.addTapToDismissGesture()
        
        self.setOriginalRect(view.convert(view.bounds, to: window))
        self.setSnapShot(view.snapshot())
        self.configureSnapshotShadow()
        
        self.add(to: window)
        self.buildView()
        self.setupEmojiKeyboardField()
        self.prepareLayout()
    }
    
    private func buildView() {
        self.addSubview(blurBackgroundView)
        self.addSubview(container)
        if let reactionView {
            container.addSubview(reactionView)
        }
        container.addSubview(snapshotView)
        
        if let visualEffectView, let menuTableView {
            container.addSubview(visualEffectView)
            visualEffectView.contentView.addSubview(menuTableView)
        }
    }
    
    private func prepareLayout() {
        
        blurBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            blurBackgroundView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 0),
            blurBackgroundView.topAnchor.constraint(equalTo: self.topAnchor, constant: 0),
            blurBackgroundView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 0),
            blurBackgroundView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 0),
        ])
        
        self.layout()
        
    }
    
    private func setSnapShot(_ image: UIImage?) {
        snapshotView.image = image
    }
    
    private func setOriginalRect(_ rect: CGRect?) {
        self.originalRect = rect
        self.vibrate(at: originalRect?.origin)
    }

    private func configureSnapshotShadow() {
        snapshotView.layer.masksToBounds = false
        snapshotView.layer.shadowColor = UIColor.black.cgColor
        snapshotView.layer.shadowOpacity = 0.14
        snapshotView.layer.shadowRadius = 12
        snapshotView.layer.shadowOffset = CGSize(width: 0, height: 6)
        snapshotView.layer.shouldRasterize = true
        snapshotView.layer.rasterizationScale = UIScreen.main.scale
    }
    
    private func layout(){
        guard var originalRect else {return}
        self.shouldResizeImage()
        var y = originalRect.origin.y - (reactionView != nil ? (REACTION.SIZE.height + REACTION.MARGIN) : 0 )
        initialY = y
        
        // container initial frame
        container.frame = CGRect(x: 0, y: y, width: self.window?.bounds.width ?? 0, height: 0)
        
        // Reaction view frame (full width always; keyboard “pill shrink” is handled inside ReactionView so the more button does not move.)
        let reactionWidth = REACTION.getWidth(count: (_config.emojis?.count ?? 0) + (_config.moreButton ? 1 : 0)) + 16 // 16 is the spacing
        let xReaction = _config.startFrom.isLeading() ? originalRect.origin.x : originalRect.origin.x + originalRect.width - reactionWidth
        y = 0
        reactionView?.frame = CGRect(x: xReaction, y: y, width: reactionWidth, height: REACTION.SIZE.height)
        
        // Message snapshot Frame
        y = reactionView != nil ? (reactionView!.bottom() + REACTION.MARGIN) : 0
        let snapshotSize = getImageSize()
        let xSanpshot = isSnapshotResizedV ? ( _config.startFrom.isLeading() ? originalRect.origin.x : originalRect.origin.x + originalRect.width - snapshotSize.width) : originalRect.origin.x
        snapshotView.frame = CGRect(x: xSanpshot, y: y, width: snapshotSize.width, height: snapshotSize.height)
        snapshotView.layer.shadowPath = UIBezierPath(roundedRect: snapshotView.bounds, cornerRadius: 12).cgPath
        
        // Menu Frame (hidden while system emoji keyboard is open from "more")
        if !menuCollapsedForEmojiKeyboard, visualEffectView != nil {
            let xMenu = _config.startFrom.isLeading() ? originalRect.origin.x : originalRect.origin.x + originalRect.width - MENU.WIDTH
            
            let menuHeight = height()
            // fisrt stage will draw the menu from the bottom
            var yMenu = getMaxBottom() - menuHeight - getMinTop()
            // here we are checking if we have space to move it to the bottom of snapshot
            let diff = yMenu - snapshotView.bottom()
            yMenu = diff > REACTION.MARGIN ? snapshotView.bottom() + REACTION.MARGIN : yMenu
            
            visualEffectView?.isHidden = false
            visualEffectView?.isUserInteractionEnabled = true
            visualEffectView?.frame = CGRect(x: xMenu, y: yMenu, width: MENU.WIDTH, height: menuHeight)
            menuTableView?.frame = visualEffectView?.bounds ?? .zero
        } else if menuCollapsedForEmojiKeyboard {
            visualEffectView?.isHidden = true
            visualEffectView?.isUserInteractionEnabled = false
        }
        
        container.frame.size.height = (menuCollapsedForEmojiKeyboard || visualEffectView == nil)
            ? snapshotView.bottom()
            : (visualEffectView?.bottom() ?? snapshotView.bottom())
        
        if menuCollapsedForEmojiKeyboard, let pinnedOrigin = keyboardCollapsedContainerOrigin {
            container.frame.origin = pinnedOrigin
        }

        if #available(iOS 26.0, *) {
            syncMenuOverlayFrameAfterLayout()
        }
    }
    
    func dismiss(with action: UIAction? = nil, emoji: String? = nil, moreButton: Bool = false){
        guard !self.isDismissing else { return }
        self.isDismissing = true
        menuOverlayRemovalWorkItem?.cancel()
        menuOverlayRemovalWorkItem = nil
        if #available(iOS 26.0, *) {
            menuOverlayDisplayIndexPath = nil
            menuRowSelectionOverlayView?.alpha = 0
        }
        self.detachFromContinuedPanGesture()
        self.emojiKeyboardField.resignFirstResponder()
        self.isSystemEmojiKeyboardActive = false
        self.menuCollapsedForEmojiKeyboard = false
        self.keyboardCollapsedContainerOrigin = nil
        self.blurBackgroundView.alpha = 1
        animator = UIViewPropertyAnimator(duration: 0.4, curve: .easeOut) { [weak self] in
            self?.blurBackgroundView.backgroundColor = .clear
            self?.blurBackgroundView.effect = nil
        }
        self.animator?.startAnimation()
        
        // Start state
        self.reactionView?.transform = .identity
        self.reactionView?.alpha = 1
        
        self.visualEffectView?.transform = .identity
        self.visualEffectView?.alpha = 1
        
        // Animate to final state
        UIView.animate(withDuration: 0.4,
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.5,
                       options: [.curveEaseOut],
                       animations: {
            
            if !self.isSnapshotResizedV {
                self.container.frame.origin.y = self.initialY ?? 0
                if self._config.startFrom.isCenter() {
                    self.snapshotView.frame.origin.x = self.originalRect?.origin.x ?? 0
                }
            }
            if !self.isSnapshotResizedH {
                self.container.frame.origin.x = 0
            }
            
            let anchorX: CGFloat = self._config.startFrom.isLeading() ? 0.0 : self._config.startFrom.isTrailing() ? 1.0 : 0.5
            self.reactionView?.setCustomAnchorPoint(CGPoint(x: anchorX, y: 1.1))
            self.reactionView?.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
            self.reactionView?.alpha = 0
            
            self.visualEffectView?.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
            self.visualEffectView?.alpha = 0
            
            // Fade the snapshot chrome back to clear on dismissal.
            self.snapshotView.backgroundColor = .clear
            self.snapshotView.layer.shadowOpacity = 0
            self.snapshotView.layer.shadowRadius = 0
            self.blurBackgroundView.alpha = 0
        }, completion: { _ in
            if self._config.hideTargetWhenReact {
                self._hostingView?.alpha = self.initialAlpha ?? 1
            }
            self.delegate?.didDismiss(on: self._config.itemIdentifier, action: action, emoji: emoji, moreButton: moreButton)
            self.removeFromSuperview()
        })
    }
    
    private func add(to view: UIView) {
        view.addSubview(self)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            self.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            self.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            self.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0),
            self.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
        ])
        
    }
    
    private func vibrate(at origin: CGPoint?) {
        if #available(iOS 17.5, *), let origin {
            feedbackGenerator?.impactOccurred(at: origin)
        } else {
            feedbackGenerator?.impactOccurred()
        }
    }
    
    
    
    func animate() {
        
        if _config.hideTargetWhenReact {
            self.initialAlpha = self._hostingView?.alpha ?? 1
            self._hostingView?.alpha = 0
        }
        delegate?.willReact?()
        
        animator = UIViewPropertyAnimator(duration: 0.4, curve: .linear) { [weak self] in
            guard let self else { return }
            if self.shouldUseBackgroundBlur {
                self.blurBackgroundView.backgroundColor = nil
                self.blurBackgroundView.effect = self._theme.backgroundBlurEffectStyle
            } else {
                self.blurBackgroundView.effect = nil
                self.blurBackgroundView.backgroundColor = self._theme.backgroundFallbackColor
            }
        }
        
        animator?.startAnimation()
        
        // Pause the animation at 50% progress
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in // Half of duration
            self?.animator?.pauseAnimation()
            self?.animator?.fractionComplete = 0.5
            self?.animator?.stopAnimation(false)
            self?.animator?.finishAnimation(at: .current)
        }
        
        // we don't need animation when resizing happen
        UIView.animate(withDuration: (isSnapshotResizedH || isSnapshotResizedV) ? 0 : 0.2) { [weak self] in
            if self?._config.startFrom.isCenter() ?? false {
                self?.snapshotView.setCenterX()
                self?.reactionView?.setCenterX()
                self?.visualEffectView?.setCenterX()
            }
            self?.checkViewInSafeArea()
        }
        self.animateMenuAndReaction()
    }
    
    private func checkViewInSafeArea(){
        checkViewInVerticalSafeArea()
        checkViewInHorizontalSafeArea()
    }
    
    private func checkViewInVerticalSafeArea(){
        let topOffset = container.top() - getMinTop()
        let bottomOffset = getMaxBottom() - container.bottom()
        guard topOffset < 0 || bottomOffset < 0  else { return }
        // the view is outside the safe area
        if topOffset < 0, !isSnapshotResizedV {
            if abs(topOffset) <= abs(bottomOffset) {
                // we can move down
                self.container.frame.origin.y += abs(topOffset)
            }else  {
                self.container.frame.origin.y = getMinTop()
            }
        }
        else if bottomOffset < 0 , abs(bottomOffset) <= abs(topOffset) {
            // we can move top
            self.container.frame.origin.y -= abs(bottomOffset)
        }else if isSnapshotResizedV {
            self.container.frame.origin.y = getMinTop()
        }
    }
    
    private func checkViewInHorizontalSafeArea(){
        let x0 = _config.startFrom.isLeading() ? self.snapshotView.left() : min(self.snapshotView.left(), self.reactionView?.left() ?? self.snapshotView.left(), self.visualEffectView?.left() ?? self.snapshotView.left())
        let x1 = max(self.snapshotView.width(), self.reactionView?.width() ?? self.snapshotView.width(), self.visualEffectView?.width() ?? self.snapshotView.width())
        
        if x0 < getMinLeft() {
            self.container.frame.origin.x += abs(x0) + getMinLeft()
        }else if x0 + x1 > getMaxAvailableWidth() {
            self.container.frame.origin.x = getMaxAvailableWidth() - x0 - x1 + getMinLeft()
        }
    }
    
    private func animateMenuAndReaction(){
        self.reactionView?.animateScaleAndFadeIn(startingFrom:CGAffineTransform(scaleX: 0.1, y: 0.4), startFrom: _config.startFrom)
        self.reactionView?.startAnimating()
        self.visualEffectView?.animateScaleAndFadeIn(startingFrom:  CGAffineTransform(scaleX: 0.2, y: 0.2), startFrom: _config.startFrom, isFromTop: true)
    }
    
    private func getImageSize() -> CGSize {
        guard let image = snapshotView.image else {return .zero}
        return image.size
    }
    
    private func shouldResizeImage() {
        guard let image = snapshotView.image else {return}
        let maxAvailableHeight = getMaxAvailableHeight()
        let maxAvailableWidth = getMaxAvailableWidth()
        if image.size.height > maxAvailableHeight {
            isSnapshotResizedV = true
        }
        if image.size.width > maxAvailableWidth {
            isSnapshotResizedH = true
        }
        if isSnapshotResizedH || isSnapshotResizedV {
            snapshotView.image = image.resizedToFit(in: CGSize(width: isSnapshotResizedH ? maxAvailableWidth : image.size.width, height: isSnapshotResizedV ? maxAvailableHeight : image.size.height))
        }
         
    }
    
    // vertically
    private func getMaxAvailableHeight() -> CGFloat {
        return getMaxBottom() - getMinTop() - REACTION.SIZE.height - REACTION.MARGIN
    }
    
    // horizontally
    private func getMaxAvailableWidth() -> CGFloat {
        return (self.window?.bounds.width ?? 0) - 2 * defaultMargin
    }
    
    private func getMinTop() -> CGFloat {
        let safeAreaTopInset:CGFloat = self.window?.safeAreaInsets.top ?? 0
        return REACTION.MARGIN + (self.window?.frame.origin.y ?? 0) + (safeAreaTopInset > 0 ? safeAreaTopInset : REACTION.MARGIN)
    }
    
    private func getMaxBottom() -> CGFloat {
        let height = self.window?.frame.height ?? 0
        let safeAreaBottomInset:CGFloat = self.window?.safeAreaInsets.bottom ?? 0
        return height - REACTION.MARGIN - (safeAreaBottomInset > 0 ? safeAreaBottomInset : REACTION.MARGIN)
    }
    
    private func getMinLeft() -> CGFloat {
        return defaultMargin
    }
    
    private func addInitialData() {
        guard let menu = _config.menu else {return}
        var snapshot = NSDiffableDataSourceSnapshot<UIMenu, UIAction>()

        if let actionChildren = menu.children as? [UIAction] {
            // To keep a consistent data structure, wrap actions in a UIMenu so we can still have menus at the top level to have support for secttions
            let wrapperMenu = UIMenu(title: "", image: nil, identifier: nil, options: [.displayInline], children: actionChildren)
            
            let menuChildren: [UIMenu] = [wrapperMenu]
            snapshot.appendSections(menuChildren)
            
            menuChildren.forEach {
                snapshot.appendItems($0.children as! [UIAction], toSection: $0)
            }
        } else if let menuChildren = menu.children as? [UIMenu] {
            snapshot.appendSections(menuChildren)
            
            menuChildren.forEach {
                snapshot.appendItems($0.children as! [UIAction], toSection: $0)
            }
        }
        
        (menuTableView?.dataSource as? UITableViewDiffableDataSource<UIMenu, UIAction>)?.apply(snapshot, animatingDifferences: false, completion: nil)
    }
    
    @objc private func didTapView(){
        if isSystemEmojiKeyboardActive {
            emojiKeyboardField.resignFirstResponder()
        }
        self.dismiss()
    }
    
    func height() -> CGFloat {
        let tableHeight = menuTableView?.sizeThatFits(CGSize(width: MENU.WIDTH, height: CGFloat.greatestFiniteMagnitude)).height.rounded()
        return tableHeight ?? 0
    }
    
}

// MARK: - UITableViewDelegate


extension ReactionPreviewView: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let action = getActionAtIndexPath(indexPath), !ReactionMenuLabel.isLabel(action) else { return nil }
        return indexPath
    }

    public func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        guard let action = getActionAtIndexPath(indexPath) else { return true }
        return !ReactionMenuLabel.isLabel(action)
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard tableView === menuTableView else { return UITableView.automaticDimension }
        if #available(iOS 26.0, *) {
            // Row height: native 79px / ours 66px on 38pt baseline, then native 74px / ours 83px inter-row tweak.
            return (((38.0 * 79.0 / 66.0) * 74.0 / 83.0).rounded())
        }
        return UITableView.automaticDimension
    }

    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if #available(iOS 26.0, *) {
            return nil
        }
        guard section != tableView.numberOfSections - 1 else { return nil }

        let footerView = UIView()
        footerView.backgroundColor = UIColor(white: 0.0, alpha: 0.1)
        return footerView
    }
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if #available(iOS 26.0, *) {
            return 0.0
        }
        let sectionDividerHeight: CGFloat = 4.0

        // If it's the last section, don't show a divider, otherwise do
        return section == tableView.numberOfSections - 1 ? 0.0 : sectionDividerHeight
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let action = getActionAtIndexPath(indexPath), !ReactionMenuLabel.isLabel(action) else { return }
        selectionGenerator?.selectionChanged()
        self.dismiss(with: action)
    }
    
    public func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath) {
        guard let action = getActionAtIndexPath(indexPath), !ReactionMenuLabel.isLabel(action) else { return }
        if #available(iOS 26.0, *) {
            menuOverlayRemovalWorkItem?.cancel()
            menuOverlayRemovalWorkItem = nil
            let from = menuOverlayDisplayIndexPath
            applyMenuRowOverlayHighlight(from: from, to: indexPath, slideAnimated: from != nil && from != indexPath)
            return
        }
        guard let cell = tableView.cellForRow(at: indexPath) as? ReactionMenuTableViewCell else { return }
        cell.highlight(true, animated: true)
    }
    
    public func tableView(_ tableView: UITableView, didUnhighlightRowAt indexPath: IndexPath) {
        if #available(iOS 26.0, *) {
            let captured = indexPath
            menuOverlayRemovalWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard self.menuOverlayDisplayIndexPath == captured else { return }
                self.applyMenuRowOverlayHighlight(from: captured, to: nil, slideAnimated: false)
            }
            menuOverlayRemovalWorkItem = item
            DispatchQueue.main.async(execute: item)
            return
        }
        guard let cell = tableView.cellForRow(at: indexPath) as? ReactionMenuTableViewCell else { return }
        cell.highlight(false, animated: true)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ReactionPreviewView : UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if isSystemEmojiKeyboardActive {
            return !emojiKeyboardField.bounds.contains(touch.location(in: emojiKeyboardField))
        }
        // Let the container pan see touches that begin on the menu so drag-to-select works like the
        // system UI. Keep emoji-strip touches enabled too so emoji hold/drag highlighting starts
        // immediately when the finger begins on an emoji.
        if gestureRecognizer === panGestureRecognizer {
            return true
        }
        let isInTableView:Bool = (menuTableView?.bounds.contains(touch.location(in: menuTableView))) ?? false
        if let reactionView {
           return !isInTableView && !reactionView.bounds.contains(touch.location(in: reactionView))
        }
        return !isInTableView
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === panGestureRecognizer else { return false }
        if let tv = menuTableView {
            var node: UIView? = otherGestureRecognizer.view
            while let current = node {
                if current === tv { return true }
                node = current.superview
            }
        }
        if let reactionView {
            var node: UIView? = otherGestureRecognizer.view
            while let current = node {
                if current === reactionView { return true }
                node = current.superview
            }
        }
        return false
    }
}

// MARK: - Target Action

extension ReactionPreviewView {
    @objc func panned(gestureRecognizer: UIGestureRecognizer) {
        let panPoint = gestureRecognizer.location(in: menuTableView)
        if let indexPath = menuTableView?.indexPathForRow(at: panPoint),
           let action = getActionAtIndexPath(indexPath),
           ReactionMenuLabel.isLabel(action) {
            if let currentlyHighlightedIndex {
                updatePanMenuHighlight(from: currentlyHighlightedIndex, to: nil, gestureRecognizer: gestureRecognizer)
            }
            self.currentlyHighlightedIndex = nil
            return
        }
        guard let indexPath = menuTableView?.indexPathForRow(at: panPoint) else {
            // If we pan outside the table and there's a cell selected, unselect it
            if let currentlyHighlightedIndex  {
                updatePanMenuHighlight(from: currentlyHighlightedIndex, to: nil, gestureRecognizer: gestureRecognizer)
            }
            if let point = reactionView?.panned(gestureRecognizer: gestureRecognizer){
                self.onSelectionChanged(at: point)
            }
            self.currentlyHighlightedIndex = nil
            return
        }
        
        if gestureRecognizer.isFinished(), currentlyHighlightedIndex == nil {
            return
        }
        
        guard indexPath != currentlyHighlightedIndex else {
            if gestureRecognizer.isFinished() {
                updatePanMenuHighlight(from: indexPath, to: nil, gestureRecognizer: gestureRecognizer)
                self.dismiss(with: getActionAtIndexPath(indexPath))
            }
            return
        }
        
        let previousHighlight = currentlyHighlightedIndex
        self.onSelectionChanged(at: panPoint)
        self.currentlyHighlightedIndex = indexPath
        
        if gestureRecognizer.isFinished() {
            updatePanMenuHighlight(from: previousHighlight, to: nil, gestureRecognizer: gestureRecognizer)
            self.dismiss(with: getActionAtIndexPath(indexPath))
        } else {
            updatePanMenuHighlight(from: previousHighlight, to: indexPath, gestureRecognizer: gestureRecognizer)
        }
    }
    
    @objc func emojiPanned(gestureRecognizer: UIGestureRecognizer) {
        if let point = reactionView?.panned(gestureRecognizer: gestureRecognizer){
            self.onSelectionChanged(at: point)
        }
    }
    
    /// Continues drag-to-select while the presenting long press is still active.
    @objc private func continuedPanGestureChanged(_ gestureRecognizer: UIGestureRecognizer) {
        self.panned(gestureRecognizer: gestureRecognizer)
    }
    
    private func highlightCell(_ bool: Bool, at indexPath: IndexPath){
        guard let cell = self.menuTableView?.cellForRow(at: indexPath) as? ReactionMenuTableViewCell else { return }
        cell.highlight(bool, animated: false)
    }

    private func updatePanMenuHighlight(from oldIndex: IndexPath?, to newIndex: IndexPath?, gestureRecognizer: UIGestureRecognizer) {
        if #available(iOS 26.0, *) {
            menuOverlayRemovalWorkItem?.cancel()
            menuOverlayRemovalWorkItem = nil
            let slide = oldIndex != nil && newIndex != nil && oldIndex != newIndex
            applyMenuRowOverlayHighlight(from: oldIndex, to: newIndex, slideAnimated: slide)
            return
        }
        if let oldIndex {
            highlightCell(false, at: oldIndex)
        }
        if let newIndex, !gestureRecognizer.isFinished() {
            highlightCell(true, at: newIndex)
        }
    }
    
    private func onSelectionChanged(at point: CGPoint){
        if #available(iOS 17.5, *) {
            selectionGenerator?.selectionChanged(at: point)
        } else {
            selectionGenerator?.selectionChanged()
        }
    }
}

// MARK: - ReactionViewDelegate

extension ReactionPreviewView : ReactionViewDelegate {
    func didSelectEmoji(_ emoji: String) {
        self.dismiss(emoji: emoji)
    }
    
    func didSelectMoreButton() {
        beginSystemEmojiKeyboardFromMoreButton()
    }

}

// MARK: - Setup helper
extension ReactionPreviewView {
    
    private func setupReactionView() {
        self.reactionView = ReactionView(_config)
        self.reactionView!.setupIcon(_theme.moreButtonIcon)
        self.reactionView!.backgroundColor = _theme.reactionBackgroundColor
        self.reactionView!.alpha = 0
        self.reactionView!.delegate = self
    }
    
    private func setupMenuView() {
        visualEffectView = UIVisualEffectView(effect: nil)
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect(style: .regular)
            glassEffect.isInteractive = true
            visualEffectView!.effect = glassEffect
            visualEffectView!.backgroundColor = .clear
        } else if !UIAccessibility.isReduceTransparencyEnabled {
            visualEffectView!.effect = _theme.menuBlurEffectStyle
        } else {
            visualEffectView!.backgroundColor = _theme.menuBlurFallbackColor
        }
        visualEffectView!.layer.masksToBounds = true
        if #available(iOS 26.0, *) {
            visualEffectView!.layer.cornerRadius = 28.0
            visualEffectView!.layer.cornerCurve = .continuous
        } else {
            visualEffectView!.layer.cornerRadius = 13.0
        }
        visualEffectView!.isUserInteractionEnabled = true
        visualEffectView!.alpha = 0
        
        menuTableView = UITableView(frame: .zero, style: .plain)
        menuTableView!.register(ReactionMenuTableViewCell.self, forCellReuseIdentifier: ReactionMenuTableViewCell.identifier)
        if #available(iOS 15.0, *) {
            menuTableView!.sectionHeaderTopPadding = 0
        }
        if #available(iOS 26.0, *) {
            // Align separator with text column (same insets as ReactionMenuTableViewCell iOS 26).
            let iconLeadingInset = (24.0 * 100.0 / 80.0).rounded()
            let iconToTitleSpacing = (6.0 * 57.0 / 33.0).rounded()
            menuTableView!.separatorInset = UIEdgeInsets(top: 0, left: iconLeadingInset + 20 + iconToTitleSpacing, bottom: 0, right: 14)
        } else {
            menuTableView!.separatorInset = .zero
        }
        menuTableView!.separatorColor = UIColor.clear
        menuTableView!.translatesAutoresizingMaskIntoConstraints = false
        menuTableView!.backgroundColor = .clear
        menuTableView!.isUserInteractionEnabled = true
        menuTableView!.isScrollEnabled = false
        if #available(iOS 26.0, *) {
            menuTableView!.contentInset = .zero
            menuTableView!.verticalScrollIndicatorInsets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0)
        } else {
            menuTableView!.verticalScrollIndicatorInsets = UIEdgeInsets(top: 13.0, left: 0.0, bottom: 13.0, right: 0.0)
        }
        
        
        // Required to not get whacky spacing
        menuTableView!.estimatedSectionHeaderHeight = 0.0
        menuTableView!.estimatedRowHeight = 0.0
        menuTableView!.estimatedSectionFooterHeight = 0.0
        
        // This hack still seems to be the best way to hide the last separator in a UITableView
        let fauxTableFooterView = UIView()
        if #available(iOS 26.0, *) {
            // Top/bottom chrome vs native (screenshot ratio native 70px / ours 50px) applied to prior 6pt baseline.
            let verticalInset: CGFloat = (6.0 * 70.0 / 50.0).rounded()
            let topPaddingView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 1.0, height: verticalInset))
            topPaddingView.backgroundColor = .clear
            menuTableView!.tableHeaderView = topPaddingView
            fauxTableFooterView.frame = CGRect(x: 0.0, y: 0.0, width: 1.0, height: verticalInset)
        } else {
            fauxTableFooterView.frame = CGRect(x: 0.0, y: 0.0, width: CGFloat.leastNormalMagnitude, height: CGFloat.leastNormalMagnitude)
        }
        menuTableView!.tableFooterView = fauxTableFooterView
        
        self.dataSource = makeDataSource()
        menuTableView!.delegate = self
        self.addInitialData()

        if #available(iOS 26.0, *) {
            let pill = UIView()
            pill.translatesAutoresizingMaskIntoConstraints = true
            pill.isUserInteractionEnabled = false
            pill.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.14)
            pill.layer.masksToBounds = true
            pill.layer.cornerCurve = .circular
            pill.alpha = 0
            visualEffectView!.contentView.addSubview(pill)
            visualEffectView!.contentView.bringSubviewToFront(pill)
            menuRowSelectionOverlayView = pill
        }
    }
    
    private func enableFeedback() {
        self.feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
        self.feedbackGenerator!.prepare()
        
        self.selectionGenerator = UISelectionFeedbackGenerator()
        self.selectionGenerator!.prepare()
    }
    
    private func enablePanGesture() {
        panGestureRecognizer.addTarget(self, action: #selector(panned(gestureRecognizer:)))
        panGestureRecognizer.cancelsTouchesInView = false
        // Match tap-to-dismiss: do not let this pan steal touches meant for the menu table or
        // emoji strip. Otherwise UITableView highlights/selection only appear after the finger
        // moves (pan waits to fail before touches reach subviews).
        panGestureRecognizer.delegate = self
        self.container.addGestureRecognizer(panGestureRecognizer)
    }
    
    private func attachToContinuedPanGesture(_ gestureRecognizer: UIGestureRecognizer) {
        self.detachFromContinuedPanGesture()
        self.continuedPanGestureRecognizer = gestureRecognizer
        gestureRecognizer.addTarget(self, action: #selector(continuedPanGestureChanged(_:)))
        // Process current touch location immediately so highlight begins without waiting for next state change.
        self.panned(gestureRecognizer: gestureRecognizer)
    }
    
    private func detachFromContinuedPanGesture() {
        self.continuedPanGestureRecognizer?.removeTarget(self, action: #selector(continuedPanGestureChanged(_:)))
        self.continuedPanGestureRecognizer = nil
    }
    
    private func addTapToDismissGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapView))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        self.addGestureRecognizer(tap)
    }

    private func setupEmojiKeyboardField() {
        emojiKeyboardField.onEmojiInserted = { [weak self] string in
            guard let self, !string.isEmpty else { return }
            guard string.containsOnlyEmoji else {
                // Treat non-emoji keyboard output like a cancel action.
                self.dismiss()
                return
            }
            self.selectionGenerator?.selectionChanged()
            self.dismiss(emoji: string)
        }
        addSubview(emojiKeyboardField)
        emojiKeyboardField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emojiKeyboardField.widthAnchor.constraint(equalToConstant: 1),
            emojiKeyboardField.heightAnchor.constraint(equalToConstant: 1),
            emojiKeyboardField.leadingAnchor.constraint(equalTo: leadingAnchor),
            emojiKeyboardField.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor)
        ])
    }

    private func beginSystemEmojiKeyboardFromMoreButton() {
        guard !isSystemEmojiKeyboardActive else { return }
        isSystemEmojiKeyboardActive = true
        keyboardCollapsedContainerOrigin = container.frame.origin
        visualEffectView?.isUserInteractionEnabled = false

        UIView.animate(
            withDuration: 0.1,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                self.reactionView?.setSuppressedEmojiCollectionForSystemKeyboard(true, animated: false)
                self.visualEffectView?.alpha = 0
                self.visualEffectView?.transform = CGAffineTransform(translationX: 0, y: -10).scaledBy(x: 0.96, y: 0.96)
            },
            completion: { _ in
                self.menuCollapsedForEmojiKeyboard = true
                self.visualEffectView?.transform = .identity
                self.layout()
                _ = self.emojiKeyboardField.becomeFirstResponder()
                self.emojiKeyboardField.reloadInputViews()
            }
        )
    }
    
}

private extension String {
    /// Returns `true` only when all visible characters are emoji.
    var containsOnlyEmoji: Bool {
        !isEmpty && allSatisfy(\.isSingleEmojiCharacter)
    }
}

private extension Character {
    var isSingleEmojiCharacter: Bool {
        // Multi-scalar clusters are typically composed emoji (ZWJ, skin tone, flags, etc.)
        if unicodeScalars.count > 1 {
            return unicodeScalars.contains { $0.properties.isEmoji }
        }
        return unicodeScalars.first?.properties.isEmojiPresentation == true
    }
}

// MARK: - Helpers
extension ReactionPreviewView {
    private func makeDataSource() -> UITableViewDiffableDataSource<UIMenu, UIAction> {
        let dataSource = UITableViewDiffableDataSource<UIMenu, UIAction>(tableView: menuTableView!) { (tableView, indexPath, action) -> UITableViewCell? in
            let cell = tableView.dequeueReusableCell(withIdentifier: ReactionMenuTableViewCell.identifier, for: indexPath) as! ReactionMenuTableViewCell
            cell.menuTitle = action.title
            cell.iconImage = action.image
            cell.isDestructive = action.attributes.contains(.destructive)
            cell.isMenuLabel = ReactionMenuLabel.isLabel(action)
            return cell
        }
        
        return dataSource
    }
    
    private func getActionAtIndexPath(_ indexPath: IndexPath) -> UIAction? {
        return (menuTableView?.dataSource as? UITableViewDiffableDataSource<UIMenu, UIAction>)?.itemIdentifier(for: indexPath)
    }

    @available(iOS 26.0, *)
    private func rectForMenuRowHighlightOverlay(at indexPath: IndexPath) -> CGRect? {
        guard let tv = menuTableView, let host = visualEffectView?.contentView else { return nil }
        let rect = tv.rectForRow(at: indexPath)
        guard rect.height > 0, !rect.isInfinite, !rect.isNull else { return nil }
        let converted = tv.convert(rect, to: host)
        let sideInset: CGFloat = 6
        return converted.insetBy(dx: sideInset, dy: 0)
    }

    @available(iOS 26.0, *)
    private func syncMenuOverlayFrameAfterLayout() {
        guard let pill = menuRowSelectionOverlayView, pill.alpha > 0.01,
              let idx = menuOverlayDisplayIndexPath,
              let frame = rectForMenuRowHighlightOverlay(at: idx) else { return }
        pill.frame = frame
        pill.layer.cornerRadius = max(1, frame.height / 2)
    }

    @available(iOS 26.0, *)
    private func applyMenuRowOverlayHighlight(from oldIndex: IndexPath?, to newIndex: IndexPath?, slideAnimated: Bool) {
        guard let pill = menuRowSelectionOverlayView else { return }
        menuOverlayRemovalWorkItem?.cancel()
        menuOverlayRemovalWorkItem = nil

        if let newIndex {
            guard let targetFrame = rectForMenuRowHighlightOverlay(at: newIndex) else { return }
            menuOverlayDisplayIndexPath = newIndex
            let canSlide = slideAnimated && pill.alpha > 0.05 && oldIndex != nil && oldIndex != newIndex
            if canSlide, let old = oldIndex, let oldFrame = rectForMenuRowHighlightOverlay(at: old) {
                pill.frame = oldFrame
                pill.layer.cornerRadius = max(1, oldFrame.height / 2)
                pill.alpha = 1
                UIView.animate(
                    withDuration: 0.34,
                    delay: 0,
                    usingSpringWithDamping: 0.88,
                    initialSpringVelocity: 0.38,
                    options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut]
                ) {
                    pill.frame = targetFrame
                    pill.layer.cornerRadius = max(1, targetFrame.height / 2)
                }
            } else {
                UIView.performWithoutAnimation {
                    pill.frame = targetFrame
                    pill.layer.cornerRadius = max(1, targetFrame.height / 2)
                }
                pill.alpha = 1
            }
        } else {
            menuOverlayDisplayIndexPath = nil
            UIView.animate(withDuration: 0.14, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
                pill.alpha = 0
            }
        }
    }
}
