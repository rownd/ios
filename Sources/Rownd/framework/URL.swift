//
//  File.swift
//  
//
//  Created by Bobby Radford on 10/23/23.
//

import Foundation

extension URL {
    func value(forQueryParam: String) -> String? {
        guard let url = URLComponents(string: self.absoluteString) else { return nil }
        return url.queryItems?.first(where: { $0.name == forQueryParam })?.value
    }
}
