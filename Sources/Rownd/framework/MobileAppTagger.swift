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
    
    func createPage(name: String?) async throws -> CreatePageResponse? {
        guard platformAccessToken != nil else {
            throw ConnectionActionError.customMessage("User needs to be authenticated with a Platform JWT for mobile app tagging")
        }
        
        do {
            let body = CreatePagePayload(
                name: name ?? "New Page"
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

    func createPageCapture(pageId: String, screenStructure: RowndScreen, screenshotDataBase64: String, screenshotHeight: Int, screenshotWidth: Int) async throws -> CreatePageCaptureResponse? {
        guard platformAccessToken != nil else {
            throw ConnectionActionError.customMessage("User needs to be authenticated with a Platform JWT for mobile app tagging")
        }

        guard let releaseVersionNumber = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            logger.error("Failed to capture page. Unable to determine release version number")
            return nil
        }

        /// Make an API call to create the page capture
        do {
            let body = CreatePageCapturePayload(
                platform: "ios",
                screenshotBase64: screenshotDataBase64,
                screenshotMimeType: "image/png",
                screenshotHeight: screenshotHeight,
                screenshotWidth: screenshotWidth,
                screenStructure: screenStructure,
                capturedOnAppVersion: releaseVersionNumber,
                capturedOnSdkVersion: getFrameworkVersion()
            )
            let response: CreatePageCaptureResponse = try await Rownd.apiClient.send(
                Get.Request(
                    url: URL(string: "/applications/\(store.state.appConfig.id ?? "unknown")/automations/mobile/pages/\(pageId)/captures")!,
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
    var name: String?
    
    enum CodingKeys: String, CodingKey {
        case name
    }
}

typealias CreatePageResponse = MobileAppPage

internal struct CreatePageCapturePayload: Encodable {
    public var platform: String
    public var screenshotBase64: String
    public var screenshotMimeType: String
    public var screenshotHeight: Int
    public var screenshotWidth: Int
    public var screenStructure: RowndScreen
    public var capturedOnAppVersion: String
    public var capturedOnSdkVersion: String

    enum CodingKeys: String, CodingKey {
        case platform = "platform"
        case screenshotBase64 = "screenshot_base64"
        case screenshotMimeType = "screenshot_mime_type"
        case screenshotHeight = "screenshot_height"
        case screenshotWidth = "screenshot_width"
        case screenStructure = "screen_structure"
        case capturedOnAppVersion = "captured_on_app_version"
        case capturedOnSdkVersion = "captured_on_sdk_version"
    }
}

typealias CreatePageCaptureResponse = MobileAppPageCapture

