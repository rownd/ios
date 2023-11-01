//
//  File.swift
//  
//
//  Created by Bobby Radford on 11/1/23.
//

import Foundation
import SwiftUI

protocol FloatingActionButtonControllerActionDelegate {
    func handleClick(_ e: Any) -> Void
}

//class FloatingActionButtonController: UIViewController {
//    var actionDelegate: FloatingActionButtonControllerActionDelegate?
//
//    var viewModel: FloatingActionButtonViewModelProto {
//        didSet {
//            // todo
//        }
//    }
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//    }
//}
