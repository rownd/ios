//
//  File.swift
//  
//
//  Created by Matt Hamann on 10/4/24.
//

import Foundation

extension Data {
    var prettyPrintedJSONString: NSString? { /// NSString gives us a nice sanitized debugDescription
        guard let object = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
        else {
            return NSString(data: self, encoding: String.Encoding.utf8.rawValue)
        }

        return prettyPrintedString
    }
}
