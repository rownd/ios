//
//  Encryption.swift
//  framework
//
//  Created by Matt Hamann on 7/7/22.
//

import Foundation
import CryptoKit

class RowndEncryption {
    static func generateKey() {
        guard let accessControl =
            SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.privateKeyUsage],
                nil)
        else {
            fatalError("cannot set access control")
        }
        
        
        let key = SymmetricKey(size: .bits256)
//        return key.withUnsafeBytes {
//            return Data(Array($0)).base64EncodedString()
//        }
    }
}
