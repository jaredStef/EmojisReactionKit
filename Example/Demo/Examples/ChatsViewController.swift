//
//  ChatsViewController.swift
//  Demo
//
//  Created by iKʜAʟED〆 on 17/06/2025.
//


import UIKit
import EmojisReactionKit

class ChatsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    /// You have instance means you have control ;)
    private var reactionPreview: ReactionPreviewView?
    private lazy var longPressGestureRecognizer: UILongPressGestureRecognizer = {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        gesture.minimumPressDuration = 0.35
        gesture.cancelsTouchesInView = true
        return gesture
    }()

    private var messages: [Message] = ChatsViewController.makeDemoMessages()

    private let tableView = UITableView()
    private let bg = UIImageView(image: UIImage(named: "bg"))

    private static let sentDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func reactionMenu(sentAt: Date) -> UIMenu {
        let sentTitle = Self.sentDateFormatter.string(from: sentAt)
        let sentLabel = ReactionMenuLabel.action(
            title: sentTitle,
            image: UIImage(systemName: "clock")
        )
        let footerSection = UIMenu(title: "", image: nil, identifier: nil, options: [.displayInline], children: [sentLabel])
        return UIMenu(
            title: "",
            image: nil,
            identifier: nil,
            options: [.displayInline],
            children: [ViewController.postMenu(), footerSection]
        )
    }

    private static func makeDemoMessages() -> [Message] {
        let base = Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 17, hour: 9, minute: 12))!
        let lines: [(String, Bool)] = [
            ("Hey there!", true),
            ("Hi! How are you?", false),
            ("I'm good, thanks. What about you?", true),
            ("Doing great! Thanks for asking.", false),
            ("It's worth noting that the mask property effectively masks a bounded area of the view, so if you are trying to mask a view whose bounds change to reveal new content", false),
            ("You should start by asking yourself why you think you need this. If you want to display the horizontal content when clipsToBounds is YES, why not make the view big enough horizontally? It can go right off the screen on both sides, no problem. A view that is visible when it is not inside its superview is usually a very bad idea in any case (for example, the user can see it but can't touch it, which is usually undesirable and confusing).Otherwise, this is going to be a very tricky problem. You will probably need to put another view above your view and another view below it, to cover the content that sticks out above and below your view. Crude but effective.", true),
            ("maskToBounds needs to be false in this case.", false),
            ("You should start by asking yourself why you think you need this. If you want to display the horizontal content when clipsToBounds is YES, why not make the view big enough horizontally? It can go right off the screen on both sides, no problem. A view that is visible when it is not inside its superview is usually a very bad idea in any case (for example, the user can see it but can't touch it, which is usually undesirable and confusing).Otherwise, this is going to be a very tricky problem. You will probably need to put another view above your view and another view below it, to cover the content that sticks out above and below your view. Crude but effective. ou should start by asking yourself why you think you need this. If you want to display the horizontal content when clipsToBounds is YES, why not make the view big enough horizontally? It can go right off the screen on both sides, no problem. A view that is visible when it is not inside its superview is usually a very bad idea in any case (for example, the user can see it but can't touch it, which is usually undesirable and confusing).Otherwise, this is going to be a very tricky problem. You will probably need to put another view above your view and another view below it, to cover the content that sticks out above and below your view. Crude but effective.", true),
            ("maskToBounds needs to be false in this case.", false),
            ("yourself why you think you need this", false),
            ("🥹🥹🥹🥹🥹", false),
            ("🥹🥹🥹🥹🥹", true)
        ]
        return lines.enumerated().map { index, pair in
            Message(text: pair.0, isIncoming: pair.1, sentAt: base.addingTimeInterval(Double(index) * 187))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Chat"

        self.view.backgroundColor = .systemBackground
        bg.backgroundColor = .systemBackground
        bg.contentMode = .scaleAspectFill

        bg.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(bg)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bg.topAnchor.constraint(equalTo: view.topAnchor),
            bg.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: view.trailingAnchor)

        ])

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: "MessageCell")
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 44
        tableView.rowHeight = UITableView.automaticDimension
        tableView.backgroundColor = .clear
        tableView.addGestureRecognizer(longPressGestureRecognizer)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reactionPreview?.removeFromSuperview()
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as? MessageCell else {
            return UITableViewCell()
        }
        cell.configure(with: messages[indexPath.row])
        return cell
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: location),
              let cell = tableView.cellForRow(at: indexPath) as? MessageCell else {
            return
        }

        if gesture.state == .began {
            reactionPreview?.removeFromSuperview()
            let message = messages[indexPath.row]
            let reactConfig = ReactionConfig(
                itemIdentifier: indexPath,
                emojis: ["❤️", "👍", "😂", "‼️", "❓"],
                menu: reactionMenu(sentAt: message.sentAt),
                startFrom: cell.isIncoming ? .leading : .trailing,
                continuedPanGesture: gesture
            )
            reactionPreview = cell.bubbleView.react(with: reactConfig, delegate: self)
        }
    }
}


class MessageCell: UITableViewCell {

    let bubbleView = UIView()
    private let messageLabel = UILabel()

    var isIncoming: Bool = true {
        didSet {
            bubbleView.backgroundColor = isIncoming ? UIColor(white: 0.9, alpha: 1) : UIColor.systemBlue
            messageLabel.textColor = isIncoming ? .black : .white
            updateConstraintsForSide()
        }
    }

    private var leftConstraint: NSLayoutConstraint!
    private var rightConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(bubbleView)
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false

        bubbleView.addSubview(messageLabel)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.numberOfLines = 0

        leftConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        rightConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: 250),

            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            messageLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12)
        ])
    }

    func configure(with message: Message) {
        messageLabel.text = message.text
        isIncoming = message.isIncoming
    }

    private func updateConstraintsForSide() {
        leftConstraint.isActive = isIncoming
        rightConstraint.isActive = !isIncoming
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct Message {
    let text: String
    let isIncoming: Bool
    let sentAt: Date
}


extension ChatsViewController : ReactionPreviewDelegate {
    func didDismiss(on identifier: Any?, action: UIAction?, emoji: String?, moreButton: Bool) {
        if let emoji = emoji {
            print("User reacted with: \(emoji)")
        } else if let action = action {
            print("User selected: \(action.identifier.rawValue)")
        } else if moreButton {
            print("more button clicked")
        }
    }
}
