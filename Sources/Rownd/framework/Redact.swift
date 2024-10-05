//
//  File.swift
//  
//
//  Created by Matt Hamann on 10/4/24.
//

import Foundation

struct Redact {
    static func redactSensitiveKeys(in jsonString: String?) -> String {
        
        guard let jsonString = jsonString else {
            return ""
        }

        // Define the regular expression pattern to find accessToken or refreshToken
        let pattern = #"\\?"(accessToken|refreshToken|refresh_token|access_token)\\?"\s*:\s*\\?"[^"\\]*\\?""#

        // Use regular expression to search for the pattern
        let regex = try! NSRegularExpression(pattern: pattern, options: [])

        // Perform the replacement: redact the value
        let redactedString = regex.stringByReplacingMatches(
            in: jsonString,
            options: [],
            range: NSRange(location: 0, length: jsonString.utf16.count),
            withTemplate: #""$1": "[REDACTED]""#
        )

        return redactedString
    }
}
