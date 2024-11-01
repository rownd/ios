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
            return String(data: self, encoding: .utf8) as NSString?
        }

        return prettyPrintedString
    }
}
