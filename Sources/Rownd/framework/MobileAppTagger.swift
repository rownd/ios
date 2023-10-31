//
//  File.swift
//  
//
//  Created by Bobby Radford on 10/20/23.
//

import Foundation
import Get
import SwiftUI
import AnyCodable

class MobileAppTagger {
    var platformAccessToken: String?

    internal func capturePage(rootViewDescriptionBase64: String, screenshotDataBase64: String) async throws -> CreatePageResponse? {
        guard platformAccessToken != nil else {
            throw ConnectionActionError.customMessage("User needs to be authenticated with a Platform JWT for mobile app tagging")
        }

        guard let releaseVersionNumber = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            logger.error("Failed to capture page. Unable to determine release version number")
            return nil
        }

        /// Make an API call to save the page
        do {
            let body = CreatePagePayload(
                name: "New Page",
                platform: "ios",
                versionName: releaseVersionNumber,
                viewHierarchyStringBase64: rootViewDescriptionBase64,
                screenshotBase64: screenshotDataBase64,
                screenshotMimeType: "image/png"
            )
            let response: CreatePageResponse = try await Rownd.apiClient.send(
                Get.Request(
                    url: URL(string: "/applications/\(store.state.appConfig.id ?? "unknown")/automations/mobile/pages")!,
                    method: "post",
                    body: body,
                    headers: [
                        "authorization": "Bearer \(String(describing: platformAccessToken ?? ""))",
                        "content-type":"application/json"
                    ]
                )
            ).value

            return response
        } catch {
           throw error
        }
    }
}

internal struct CreatePagePayload: Encodable {
    public var name: String
    public var platform: String
    public var versionName: String
    public var viewHierarchyStringBase64: String
    public var screenshotBase64: String
    public var screenshotMimeType: String

    enum CodingKeys: String, CodingKey {
        case name = "name"
        case platform = "platform"
        case versionName = "version_name"
        case viewHierarchyStringBase64 = "view_hierarchy_string_base64"
        case screenshotBase64 = "screenshot_base64"
        case screenshotMimeType = "screenshot_mime_type"
    }
}

internal struct CreatePageResponse: Hashable, Codable {
    public var name: String
    public var platform: String
    public var versionId: String
    public var viewHierarchy: ViewHierarchy
    public var screenshotUrl: String

    enum CodingKeys: String, CodingKey {
        case name = "name"
        case platform = "platform"
        case versionId = "version_id"
        case viewHierarchy = "view_hierarchy"
        case screenshotUrl = "screenshot_url"
    }
}

internal struct ViewHierarchy: Hashable, Codable {
    public var item: String
    public var children: AnyCodable
    public var depth: Int
    public var frame: Frame
    public var name: String
    public var layer: String

    enum CodingKeys: String, CodingKey {
        case item = "item"
        case children = "children"
        case depth = "depth"
        case frame = "frame"
        case name = "name"
        case layer = "layer"
    }
}

internal struct Frame: Hashable, Codable {
    public var frame: AnyCodable
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    enum CodingKeys: String, CodingKey {
        case frame = "frame"
        case x = "x"
        case y = "y"
        case width = "width"
        case height = "height"
    }
}
