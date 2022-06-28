//
//  RowndConfig.swift
//  ios native
//
//  Created by Matt Hamann on 6/14/22.
//

import Foundation

public struct RowndConfig: Hashable, Codable {
    static let inst = RowndConfig();
    private init(){}

    var apiUrl = "https://api.us-east-2.dev.rownd.io"
    var baseUrl = "http://localhost:8787"
    var appKey = "82f7fa9a-8110-416c-8cc8-e3c0506fbf93"
    
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
