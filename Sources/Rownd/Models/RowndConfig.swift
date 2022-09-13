//
//  RowndConfig.swift
//  ios native
//
//  Created by Matt Hamann on 6/14/22.
//

import Foundation
import UIKit

public struct RowndConfig: Hashable, Codable {
    static let inst = RowndConfig();
    private init(){}

    public var apiUrl = "https://api.rownd.io"
    public var baseUrl = "https://hub.rownd.io"
    public var appKey = ""
    public var forceDarkMode = false
    public var postSignInRedirect: String? = nil
    public var fontSize = UIFontMetrics(forTextStyle: .body).scaledFont(for: .preferredFont(forTextStyle: .body)).pointSize - 5
    
    func toJson() -> String {
        let encoder = JSONEncoder()
        encoder.dataEncodingStrategy = .base64
        
        do {
            let encodedData = try encoder.encode(self)
            return String(data: encodedData, encoding: .utf8) ?? "{}"
        } catch {
            fatalError("Couldn't encode Rownd Config as \(self):\n\(error)")
        }
    }
}
