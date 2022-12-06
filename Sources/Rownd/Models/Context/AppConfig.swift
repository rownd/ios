//
//  AppConfig.swift
//  framework
//
//  Created by Matt Hamann on 6/23/22.
//

import Foundation
import UIKit
import ReSwift
import ReSwiftThunk
import Get

public struct AppConfigState: Hashable {
    public var isLoading: Bool = false
    public var id: String?
    public var icon: String?
    public var userVerificationFields: [String]?
    public var schema: Dictionary<String, AppSchemaField>?
    public var config: AppConfigConfig?
}

extension AppConfigState: Codable {
    enum CodingKeys: String, CodingKey {
        case id, icon, schema, config
        case userVerificationFields = "user_verification_fields"
    }
}

public struct AppConfigConfig: Hashable {
    public var hub: AppHubConfigState?
    public var customizations: AppCustomizationsConfigState?
}

extension AppConfigConfig: Codable {
    enum CodingKeys: String, CodingKey {
        case hub, customizations
    }
}

public struct AppSchemaField: Hashable {
    public var displayName: String?
    public var type: String?
    public var required: Bool?
    public var ownedBy: String?
    public var encryption: AppSchemaFieldEncryption?
}

extension AppSchemaField: Codable {
    enum CodingKeys: String, CodingKey {
        case type, required, encryption
        case displayName = "display_name"
        case ownedBy = "owned_by"
    }
}

public struct AppSchemaFieldEncryption: Hashable, Codable {
    public var state: AppSchemaEncryptionState?
}

public enum AppSchemaEncryptionState: String, Codable {
    case enabled, disabled
}

public struct AppHubConfigState: Hashable {
    public var auth: AppHubAuthConfigState?
    public var customizations: AppHubCustomizationsConfigState?
    public var customStyles: [AppHubCustomStylesConfigState]?
}

extension AppHubConfigState: Codable {
    enum CodingKeys: String, CodingKey {
        case auth, customizations
        case customStyles = "custom_styles"
    }
}

public struct AppHubAuthConfigState: Hashable {
    public var signInMethods: SignInMethods?
}

extension AppHubAuthConfigState: Codable {
    enum CodingKeys: String, CodingKey {
        case signInMethods = "sign_in_methods"
    }
}

public struct AppCustomizationsConfigState: Hashable {
    public var primaryColor: String?
}

extension AppCustomizationsConfigState: Codable {
    enum CodingKeys: String, CodingKey {
        case primaryColor = "primary_color"
    }
}

public struct AppHubCustomizationsConfigState: Hashable {
    public var fontFamily: String?
    public var darkMode: String?
}

extension AppHubCustomizationsConfigState: Codable {
    enum CodingKeys: String, CodingKey {
        case fontFamily = "font_family"
        case darkMode = "dark_mode"
    }
}

public struct AppHubCustomStylesConfigState: Hashable {
    public var content: String
}

extension AppHubCustomStylesConfigState: Codable {
    enum CodingKeys: String, CodingKey {
        case content
    }
}

public struct SignInMethods: Hashable {
    public var google: GoogleSignInMethodConfig?
}

extension SignInMethods: Codable {
    enum CodingKeys: String, CodingKey {
        case google
    }
}

public struct GoogleSignInMethodConfig: Hashable {
    public var enabled: Bool?
    public var serverClientId: String?
    public var iosClientId: String?
}

extension GoogleSignInMethodConfig: Codable {
    enum CodingKeys: String, CodingKey {
        case enabled
        case serverClientId = "client_id"
        case iosClientId = "ios_client_id"
    }
}

struct SetAppConfig: Action {
    var payload: AppConfigState
}

struct SetAppLoading: Action {
    var isLoading: Bool
}

func appConfigReducer(action: Action, state: AppConfigState?) -> AppConfigState {
    var state = state ?? AppConfigState()
    
    switch action {
    case let action as SetAppConfig:
        state = action.payload
    case let action as SetAppLoading:
        state.isLoading = action.isLoading
    default:
        break
    }
    
    return state
}

// MARK: API / side-effecty things

// Easily unwrap the main payload from the `app` key
struct AppConfigResponse: Decodable {
    var app: AppConfigState
}

class AppConfig {
    static func requestAppState() -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let state = getState() else { return }
            guard !state.appConfig.isLoading else { return }
            dispatch(SetAppLoading(isLoading: true))

            Task {
                let appConfig = await AppConfig.fetch()

                DispatchQueue.main.async {
                    dispatch(SetAppConfig(payload: appConfig?.app ?? state.appConfig))
                    dispatch(SetAppLoading(isLoading: false))
                }
            }
        }
    }

    static func fetch() async -> AppConfigResponse? {
        do {
            let appConfig: AppConfigResponse = try await Rownd.apiClient.send(Get.Request(url: URL(string: "/hub/app-config")!, method: "get")).value

            return appConfig
        } catch {
            logger.error("Failed to fetch app config: \(String(describing: error))")
            return nil
        }
    }
}
