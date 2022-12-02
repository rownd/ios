//
//  RowndConfig.swift
//  ios native
//
//  Created by Matt Hamann on 6/14/22.
//

import Foundation

public struct RowndConfig: Encodable {
    internal init(){}

    // public var apiUrl = "https://api.us-east-2.dev.rownd.io"
    // public var baseUrl = "https://hub.rownd.workers.dev"
    public var apiUrl = "https://ae50-71-147-45-181.ngrok.io"
    public var baseUrl = "https://abc-microphone-sustainability-bt.trycloudflare.com"
    public var subdomainExtension = ".dev.rownd.link"
    public var appKey = ""
    public var forceDarkMode = false
    public var postSignInRedirect: String? = "NATIVE_APP"
    public var googleClientId: String = ""
    public var customizations: RowndCustomizations = RowndCustomizations()
    
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
