//
//  RowndConfig.swift
//  ios native
//
//  Created by Matt Hamann on 6/14/22.
//

import Foundation


public struct SuperTokensAppInfo: Encodable {
    public var appName: String
    public var apiDomain: String
    public var apiBasePath: String

    internal var normalizedApiDomain: String? {
        let domain = apiDomain.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let url = URL(string: domain),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else {
            return nil
        }

        return url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    internal var normalizedApiBasePath: String {
        let segments = apiBasePath
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/")
            .map(String.init)

        return segments.isEmpty ? "" : "/" + segments.joined(separator: "/")
    }

    internal var migrationURL: URL? {
        guard let normalizedApiDomain else {
            return nil
        }

        guard var components = URLComponents(string: normalizedApiDomain) else {
            return nil
        }

        components.path = normalizedApiBasePath + "/plugin/rownd/migrate"
        return components.url
    }

    public init(appName: String, apiDomain: String, apiBasePath: String = "/auth") {
        self.appName = appName
        self.apiDomain = apiDomain
        self.apiBasePath = apiBasePath
    }
}

public struct SuperTokensConfig: Encodable {
    public var appInfo: SuperTokensAppInfo

    public init(appInfo: SuperTokensAppInfo) {
        self.appInfo = appInfo
    }
}

public struct RowndConfig: Encodable {
    internal init() {}

    // These are encoded for the hub to read
    public var apiUrl = "https://api.rownd.io"
    public var baseUrl = "https://hub.rownd.io"
    public var subdomainExtension = ".rownd.link"
    public var appKey = ""
    public var forceDarkMode = false
    public var postSignInRedirect: String? = "NATIVE_APP"
    public var googleClientId: String = ""
    public var customizations: RowndCustomizations = RowndCustomizations()

    // These will not be encoded
    public var supertokens: SuperTokensConfig? = nil
    public var appGroupPrefix: String?
    public var enableSmartLinkPasteBehavior: Bool = true
    public var signInLinkPattern: String = ".*\\.rownd\\.link$"
    public var deepLinkHandler: RowndDeepLinkHandlerDelegate?
    public var forceInstantUserConversion: Bool = false

    private enum CodingKeys: String, CodingKey {
        case apiUrl,
             baseUrl,
             subdomainExtension,
             appKey,
             forceDarkMode,
             postSignInRedirect,
             googleClientId,
             customizations
    }

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
