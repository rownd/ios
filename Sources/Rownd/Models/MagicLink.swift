//
//  MagicLink.swift
//  RowndSDK
//
//  Created by Matt Hamann on 8/22/22.
//

import Foundation

struct MagicLink: Codable {
    var link: String
    var appUserId: String

    enum CodingKeys: String, CodingKey {
        case link
        case appUserId = "app_user_id"
    }
}
