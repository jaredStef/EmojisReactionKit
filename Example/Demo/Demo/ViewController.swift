//
//  ViewController.swift
//  Demo
//
//  Created by iKʜAʟED〆 on 17/06/2025.
//

import UIKit

class ViewController: UIViewController {
    
    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.distribution = .fillEqually
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let chatExampleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Chat Example", for: .normal)
        return button
    }()
    
    private let listExampleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("List Example", for: .normal)
        return button
    }()
    
    private let otherExampleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Collection Example", for: .normal)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        view.addSubview(stack)
        
        // Add buttons to stack
        stack.addArrangedSubview(chatExampleButton)
        stack.addArrangedSubview(listExampleButton)
        stack.addArrangedSubview(otherExampleButton)
        
        // add targets
        chatExampleButton.addTarget(self, action: #selector(onClickChatExample), for: .touchUpInside)
        listExampleButton.addTarget(self, action: #selector(onClickListExample), for: .touchUpInside)
        otherExampleButton.addTarget(self, action: #selector(onClickOtherExample), for: .touchUpInside)
        
        // Center the stack in the view
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(equalToConstant: 200),
            chatExampleButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc func onClickChatExample() {
        self.navigationController?.pushViewController(ChatsViewController(), animated: true)
    }
    
    @objc func onClickListExample() {
        self.navigationController?.pushViewController(NewsListViewController(), animated: true)
    }
    
    @objc func onClickOtherExample() {
        self.navigationController?.pushViewController(CollectionViewController(), animated: true)
    }
    
    
    /// Inline block used by the collection demo and as the main section in ``existingMenu``.
    public static func postMenu() -> UIMenu {
        let ident1 = UIAction.Identifier("upvote")
        let upvoteAction = UIAction(title: "Upvote", image: UIImage(systemName: "arrow.up"), identifier: ident1, handler: { _ in })

        let ident2 = UIAction.Identifier("downvote")
        let downvoteAction = UIAction(title: "Downvote", image: UIImage(systemName: "arrow.down"), identifier: ident2, handler: { _ in })

        let ident3 = UIAction.Identifier("save")
        let saveAction = UIAction(title: "Save", image: UIImage(systemName: "bookmark"), identifier: ident3, handler: { _ in })

        let postActions: [UIMenuElement] = [upvoteAction, downvoteAction, saveAction]
        return UIMenu(title: "", image: nil, identifier: nil, options: [.displayInline], children: postActions)
    }

    public static let existingMenu: UIMenu = {
        UIMenu(title: "", image: nil, identifier: nil, options: [.displayInline], children: [postMenu()])
    }()
   
}



