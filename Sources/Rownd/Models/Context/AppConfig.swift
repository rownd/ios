//
//  AppConfig.swift
//  framework
//
//  Created by Matt Hamann on 6/23/22.
//

import AnyCodable
import Foundation
import Get
import UIKit

public struct AppConfigState: Hashable, Sendable {
    public var isLoading: Bool = false
    public var id: String?
    public var icon: String?
    public var name: String?
    public var userVerificationFields: [String]?
    public var schema: [String: AppSchemaField]?
    public var config: AppConfigConfig?
}

extension AppConfigState: Codable {
    enum CodingKeys: String, CodingKey {
        case id, icon, schema, config, name
        case userVerificationFields = "user_verification_fields"
    }
}

public struct AppConfigConfig: Hashable, Sendable {
    public var automations: [RowndAutomation]?
    public var hub: AppHubConfigState?
    public var customizations: AppCustomizationsConfigState?
    public var subdomain: String?
}

extension AppConfigConfig: Codable {
    enum CodingKeys: String, CodingKey {
        case hub, customizations, subdomain, automations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Attempt to decode the automations array, handling each RowndAutomation individually
        if var nestedContainer = try? container.nestedUnkeyedContainer(forKey: .automations) {
            var tempAutomations = [RowndAutomation]()

            while !nestedContainer.isAtEnd {
                if let automation = try? nestedContainer.decode(RowndAutomation.self) {
                    tempAutomations.append(automation)
                } else {
                    _ = try? nestedContainer.decode(AnyCodable.self)  // This line skips over the bad entry
                }
            }

            self.automations = tempAutomations.isEmpty ? nil : tempAutomations
        } else {
            self.automations = nil
        }

        self.hub = try? container.decode(AppHubConfigState.self, forKey: .hub)
        self.customizations = try? container.decode(AppCustomizationsConfigState.self, forKey: .customizations)
        self.subdomain = try? container.decode(String.self, forKey: .subdomain)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode automations, skipping any that fail to encode
        if let automations = automations {
            var nestedContainer = container.nestedUnkeyedContainer(forKey: .automations)
            for automation in automations {
                do {
                    try nestedContainer.encode(automation)
                } catch {
                    continue  // Skip the automation if encoding fails
                }
            }
        }

        try container.encodeIfPresent(hub, forKey: .hub)
        try container.encodeIfPresent(customizations, forKey: .customizations)
        try container.encodeIfPresent(subdomain, forKey: .subdomain)
    }

    public func toDictionary() throws -> [String: Any?] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
    }
}

public struct AppSchemaField: Hashable, Sendable {
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

public struct AppSchemaFieldEncryption: Hashable, Codable, Sendable {
    public var state: AppSchemaEncryptionState?
}

public enum AppSchemaEncryptionState: String, Codable, Sendable {
    case enabled, disabled
}

public struct AppHubConfigState: Hashable, Sendable {
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

public struct AppHubAuthConfigState: Hashable, Sendable {
    public var signInMethods: SignInMethods?
    public var useExplicitSignUpFlow: Bool?
}

extension AppHubAuthConfigState: Codable {
    enum CodingKeys: String, CodingKey {
        case signInMethods = "sign_in_methods"
        case useExplicitSignUpFlow = "use_explicit_sign_up_flow"
    }
}

public struct AppCustomizationsConfigState: Hashable, Sendable {
    public var primaryColor: String?
}

extension AppCustomizationsConfigState: Codable {
    enum CodingKeys: String, CodingKey {
        case primaryColor = "primary_color"
    }
}

public struct AppHubCustomizationsConfigState: Hashable, Sendable {
    public var fontFamily: String?
    public var darkMode: String?
    public var primaryColor: String?
    public var primaryColorDarkMode: String?
}

extension AppHubCustomizationsConfigState: Codable {
    enum CodingKeys: String, CodingKey {
        case fontFamily = "font_family"
        case darkMode = "dark_mode"
        case primaryColor = "primary_color"
        case primaryColorDarkMode = "primary_color_dark_mode"
    }
}

public struct AppHubCustomStylesConfigState: Hashable, Sendable {
    public var content: String
}

extension AppHubCustomStylesConfigState: Codable {
    enum CodingKeys: String, CodingKey {
        case content
    }
}

public struct SignInMethods: Hashable, Sendable {
    public var google: GoogleSignInMethodConfig?
    public var passkeys: PasskeysSignInMethodConfig?
}

extension SignInMethods: Codable {
    enum CodingKeys: String, CodingKey {
        case google, passkeys
    }
}

public struct GoogleSignInMethodConfig: Hashable, Sendable {
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

public struct PasskeysSignInMethodConfig: Hashable, Sendable {
    public var enabled: Bool?
    public var domains: [String]?
}

extension PasskeysSignInMethodConfig: Codable {
    enum CodingKeys: String, CodingKey {
        case enabled, domains
    }
}

// MARK: - API / side-effect actions

// Easily unwrap the main payload from the `app` key
struct AppConfigResponse: Decodable {
    var app: AppConfigState
}

class AppConfig {
    static func requestAppState() async {
        let state = Context.currentContext.store.state
        guard !state.appConfig.isLoading else { return }

        await Context.currentContext.store.mutate { state in
            state.appConfig.isLoading = true
        }

        let appConfig = await AppConfig.fetch()

        await Context.currentContext.store.mutate { state in
            if let appConfig = appConfig {
                state.appConfig = appConfig.app
            }
            state.appConfig.isLoading = false
        }
    }

    static func fetch() async -> AppConfigResponse? {
        do {
            let appConfig: AppConfigResponse = try await Rownd.apiClient.send(Get.Request(url: URL(string: "/hub/app-config")!, method: "get")).value

            return appConfig
        } catch {
            logger.error("Failed to fetch app config: \(String(describing: error), privacy: .auto)")
            return nil
        }
    }
}
