//
//  RphInit.swift
//  Rownd
//
//  Created by Bobby on 4/10/25.
//

import Foundation
import Gzip

struct RphInit: Encodable {
    let accessToken: String?
    let refreshToken: String?
    let appId: String?
    let appUserId: String?
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case appId = "app_id"
        case appUserId = "app_user_id"
    }
    
    /// Computes a value suitable for appending to a URL fragment. The returne dvalue is JSON-encoded, Gzipped, and base64 encoded with a "gz." prefix
    func valueForURLFragment() throws -> String {
        let encoder = JSONEncoder()
        let json = try encoder.encode(self)
        let compressed = try Data(json).gzipped(level: .bestCompression)
        let base64 = compressed.base64EncodedString()

        return "gz.\(base64)"
    }
}
