//
//  Array+IsEqualTolerance.swift
//  Rownd
//
//  Created by Matt Hamann on 4/3/23.
//

import Foundation

extension Array {
    subscript(safe index: Index) -> Element? {
        let isValidIndex = index >= 0 && index < endIndex
        return isValidIndex ? self[index] : nil
    }
}
