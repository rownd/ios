//
//  RowndStorage.swift
//  ios native
//
//  Created by Matt Hamann on 6/15/22.
//

import Foundation

struct Storage {
//    static let inst = Storage();
    private init(){}
    
    static var store = UserDefaults.init(suiteName: "io.rownd.sdk")
}
