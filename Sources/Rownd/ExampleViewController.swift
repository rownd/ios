//
//  ExampleViewController.swift
//  UIViewControllerPlay
//
//  Created by Michael Murray on 4/13/23.
//

import UIKit

class ExampleViewController: UIViewController, BottomSheetHostProtocol {
    var hostController: BottomSheetController?
    @objc var preferredHeightInBottomSheet: CGFloat = 550
    
    private let label: UILabel = {
        let label = UILabel()
        label.text = "Hello, World!"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let button: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Tap me!", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let textField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.backgroundColor = .red
        return textField
    }()
    
    private let childVC = ChildViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        //add(childVC)
    }
    
    private func add(_ child: UIViewController) {
            addChild(child)
            view.addSubview(child.view)
            child.didMove(toParent: self)

            child.view.translatesAutoresizingMaskIntoConstraints = false
            let newHeight: CGFloat = 450 // Change this value to your desired height
            NSLayoutConstraint.activate([
                child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                child.view.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                child.view.heightAnchor.constraint(equalToConstant: newHeight)
            ])
        }
    
    private func setupUI() {
        //view.addSubview(label)
        view.addSubview(button)
        view.addSubview(textField)
        
        view.backgroundColor = .green
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        //label.backgroundColor = .red
        
        NSLayoutConstraint.activate([
            textField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            textField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 20),
            
            //textField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        
        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }
    
    @objc private func buttonTapped() {
        self.preferredHeightInBottomSheet = 300
        if (label.text == "Tap me!") {
            label.text = "You tapped the button!"
        } else {
            label.text = "Tap me!"
        }
    }
}
