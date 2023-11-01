//
//  File.swift
//  
//
//  Created by Bobby Radford on 11/1/23.
//

import Foundation
import SwiftUI

protocol FloatingActionButtonViewModelProto {
    var backgroundImage: UIImage { get }
}

class FloatingActionButtonViewModel: NSObject {
    var backgroundImage: UIImage
    
    init(_ model: FloatingActionButton) {
        backgroundImage = model.backgroundImage
    }
}
