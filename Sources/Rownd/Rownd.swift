//
//  Rownd.swift
//  framework
//
//  Created by Matt Hamann on 6/23/22.
//

import Foundation
import SwiftUI
import UIKit
import ReSwift
import WebKit
import AnyCodable
import AuthenticationServices
import LBBottomSheet
import GoogleSignIn
import LocalAuthentication
import Kronos
import Get

public class Rownd: NSObject {
    private static let inst: Rownd = Rownd()
    public static var config: RowndConfig = RowndConfig()
    private let appStateListener = AppStateListener()

    public static let user = UserPropAccess()
    private static var appleSignUpCoordinator: AppleSignUpCoordinator = AppleSignUpCoordinator(inst)
    internal static var googleSignInCoordinator: GoogleSignInCoordinator = GoogleSignInCoordinator(inst)
    internal var bottomSheetController: BottomSheetController = BottomSheetController()
    internal static var passkeyCoordinator: PasskeyCoordinator = PasskeyCoordinator()
    internal static var apiClient = RowndApi().client
    internal static var authenticator = Authenticator()
    internal static let automationsCoordinator = AutomationsCoordinator()
    internal static var connectionAction = ConnectionAction()

    // Run processAutomations() every second to support time-based automations
    internal var automationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        Rownd.automationsCoordinator.processAutomations()
    }

    private override init() {
        super.init()

        // Start NTP sync
        let ntpStart = Date()
        Clock.sync(from: "time.cloudflare.cox", first: { date, offset in
            logger.debug("NTP sync complete after \(ntpStart.distance(to: Date())) seconds. (Date: \(String(describing: date)); Offset: \(String(describing: offset)))")

            if Context.currentContext.store.state.clockSyncState != .synced {
                Context.currentContext.store.dispatch(SetClockSync(clockSyncState: .synced))
            }
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if Context.currentContext.store.state.clockSyncState == .waiting {
                logger.warning("NTP clock not synced after \(ntpStart.distance(to: Date())) seconds.")
                Context.currentContext.store.dispatch(SetClockSync(clockSyncState: .unknown))
            }
        }
    }

    @discardableResult
    public static func configure(launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil, appKey: String?) async -> RowndState {
        if let _appKey = appKey {
            config.appKey = _appKey
        }

        let state = await inst.inflateStoreCache()

        // Skip the rest within app extensions
        if Bundle.main.bundlePath.hasSuffix(".appex") {
            return state
        }

        await inst.loadAppConfig()
        inst.loadAppleSignIn()

        let store = Context.currentContext.store
        if store.state.isInitialized &&
            !store.state.auth.isAuthenticated {
            if !Bundle.main.bundlePath.hasSuffix(".appex") {
                var launchUrl: URL?
                if let _launchUrl = launchOptions?[.url] as? URL {
                    launchUrl = _launchUrl
                    handleSignInLink(url: launchUrl)
                } else if UIPasteboard.general.hasStrings {
                    UIPasteboard.general.detectPatterns(for: [UIPasteboard.DetectionPattern.probableWebURL]) { result in
                        switch result {
                        case .success(let detectedPatterns):
                            if detectedPatterns.contains(UIPasteboard.DetectionPattern.probableWebURL) {
                                if var _launchUrl = UIPasteboard.general.string {
                                    if !_launchUrl.starts(with: "http") {
                                        _launchUrl = "https://\(_launchUrl)"
                                    }
                                    launchUrl = URL(string: _launchUrl)
                                    handleSignInLink(url: launchUrl)
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            }

            if store.state.appConfig.config?.hub?.auth?.signInMethods?.google?.enabled == true {
                do {
                    _ = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                    logger.debug("Successfully restored previous Google Sign-in")
                } catch {
                    logger.warning("Failed to restore previous Google Sign-in: \(String(describing: error))")
                }
            }
        }

        // Fetch user if authenticated and app is in foreground
        DispatchQueue.main.async {
            if store.state.auth.isAuthenticated && UIApplication.shared.applicationState == .active {
                store.dispatch(UserData.fetch())
                store.dispatch(PasskeyData.fetchPasskeyRegistration())
            }
        }

        return state
    }

    @discardableResult public static func handleSignInLink(url: URL?) -> Bool {
        let store = Context.currentContext.store
        if store.state.auth.isAuthenticated {
            return true
        }

        if (url?.host?.hasSuffix("rownd.link")) != nil, let url = url {
            logger.trace("handling url: \(String(describing: url.absoluteString))")
            
            if (url.path.starts(with: "/verified")) {
                return false
            }

            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
            urlComponents?.scheme = "https"

            guard let url = urlComponents?.url else {
                return false
            }

            Task {
                do {
                    try await SignInLinks.signInWithLink(url)
                } catch {
                    logger.error("Sign-in attempt failed during launch: \(String(describing: error))")
                }
            }

            return true
        }

        return false
    }
    
    public class auth {
        public class passkeys {
            public static func register() {
                inst.displayHub(.connectPasskey, jsFnOptions: RowndConnectPasskeySignInOptions(biometricType: LAContext().biometricType.rawValue).dictionary())
            }
            public static func authenticate() {
                passkeyCoordinator.authenticate()
            }
        }
    }

    public static func getInstance() -> Rownd {
        return inst
    }

    public static func requestSignIn() {
        requestSignIn(RowndSignInOptions())
    }

    public static func requestSignIn(with: RowndSignInHint, completion: (() -> Void)? = nil) {
        requestSignIn(with: with, signInOptions: RowndSignInOptions(), completion: completion)
    }

    public static func requestSignIn(with: RowndSignInHint, signInOptions: RowndSignInOptions?, completion: (() -> Void)? = nil) {
        let signInOptions = determineSignInOptions(signInOptions)
        switch with {
        case .appleId:
            appleSignUpCoordinator.signIn(signInOptions?.intent)
        case .passkey:
            passkeyCoordinator.authenticate()
        case .googleId:
            Task {
                await googleSignInCoordinator.signIn(
                    signInOptions?.intent,
                    hint: signInOptions?.hint
                )
                completion?()
            }
        case .guest, .anonymous:
            requestSignIn(jsFnOptions: RowndSignInJsOptions(
                signInType: .anonymous
            ))
        }

    }

    public static func requestSignIn(_ signInOptions: RowndSignInOptions?) {
        let signInOptions = determineSignInOptions(signInOptions)
        inst.displayHub(.signIn, jsFnOptions: signInOptions ?? RowndSignInOptions() )
    }

    internal static func requestSignIn(jsFnOptions: Encodable?) {
        inst.displayHub(.signIn, jsFnOptions: jsFnOptions)
    }

    @MainActor
    public static func connectAuthenticator(with: RowndConnectSignInHint, completion: (() -> Void)? = nil) {
        connectAuthenticator(with: with, completion: completion, args: nil)
    }

    internal static func connectAuthenticator(with: RowndConnectSignInHint, completion: (() -> Void)? = nil, args: [String: AnyCodable]?) {
        switch with {
        case .passkey:
            let store = Context.currentContext.store
            if store.state.auth.accessToken != nil {
                var passkeySignInOptions = RowndConnectPasskeySignInOptions(biometricType: LAContext().biometricType.rawValue).dictionary()
                args?.forEach { (k, v) in passkeySignInOptions[k] = v }
                inst.displayHub(.connectPasskey, jsFnOptions: passkeySignInOptions)
            } else {
                logger.log("Need to be authenticated to Connect another method")
                requestSignIn()
            }
        }
    }

    public static func signOut() {
        DispatchQueue.main.async {
            let store = Context.currentContext.store
            store.dispatch(SetAuthState(payload: AuthState()))
            store.dispatch(SetUserData(data: [:], meta: [:]))
            store.dispatch(SetPasskeyState())

            RowndEventEmitter.emit(RowndEvent(
                event: .signOut
            ))
        }
    }

    public static func transferEncryptionKey() throws {
        throw RowndError("Encryption is currently not enabled with this SDK. If you like to enable it, please reach out to support@rownd.io")
    }

    public static func manageAccount() {
        _ = inst.displayHub(.manageAccount)
    }

    public class firebase {
        public static func getIdToken() async throws -> String {
            return try await connectionAction.getFirebaseIdToken()
        }
    }

    @discardableResult public static func getAccessToken() async throws -> String? {
        let store = Context.currentContext.store
        return try await store.state.auth.getAccessToken()
    }

    @discardableResult public static func getAccessToken(token: String) async -> String? {
        guard let tokenResponse = try? await Auth.fetchToken(token) else { return nil }

        DispatchQueue.main.async {
            let store = Context.currentContext.store
            store.dispatch(SetAuthState(payload: AuthState(accessToken: tokenResponse.accessToken, refreshToken: tokenResponse.refreshToken)))
            store.dispatch(UserData.fetch())
        }

        return tokenResponse.accessToken

    }

    public func state() -> Store<RowndState> {
        return Context.currentContext.store
    }

    public static func addEventHandler(_ handler: RowndEventHandlerDelegate) {
        Context.currentContext.eventListeners.append(handler)
    }

    // This is an internal test function used only to manually test
    // ensuring refresh tokens are only used once when attempting
    // to fetch new access tokens
    @available(*, deprecated, message: "Internal test use only. This method may change any time without warning.")
    public static func _refreshToken() {
        Task {
            do {
                let refreshResp = try await authenticator.refreshToken()
                print("refresh 1: \(String(describing: refreshResp))")
            } catch {
                print("Error refreshing token 1: \(String(describing: error))")
            }
        }

        Task {
            do {
                let refreshResp = try await authenticator.refreshToken()
                print("refresh 2: \(String(describing: refreshResp))")
            } catch {
                print("Error refreshing token 2: \(String(describing: error))")
            }
        }

        Task {
            do {
                let refreshResp = try await authenticator.refreshToken()
                print("refresh 3: \(String(describing: refreshResp))")
            } catch {
                print("Error refreshing token 3: \(String(describing: error))")
            }
        }
    }

    internal static func determineSignInOptions(_ signInOptions: RowndSignInOptions?) -> RowndSignInOptions? {
        let store = Context.currentContext.store
        var signInOptions = signInOptions
        if signInOptions?.intent == RowndSignInIntent.signUp || signInOptions?.intent == RowndSignInIntent.signIn {
            if store.state.appConfig.config?.hub?.auth?.useExplicitSignUpFlow != true {
                signInOptions?.intent = nil
                logger.error("Sign in with intent: SignIn/SignUp is not enabled. Turn it on in the Rownd platform")
            }
        }
        return signInOptions
    }

    // MARK: Internal methods
    private func loadAppleSignIn() {
        // If we want to check if the AppleId userIdentifier is still valid
    }

    private func loadAppConfig() async {
        let store = Context.currentContext.store
        if store.state.appConfig.id == nil {
            // Await the config if it wasn't already cached
            guard let appConfig = await AppConfig.fetch() else {
                return
            }

            DispatchQueue.main.async {
                store.dispatch(SetAppConfig(payload: appConfig.app))
            }
        } else {
            DispatchQueue.main.async {
                // Refresh in background if already present
                store.dispatch(AppConfig.requestAppState())
            }
        }

    }

    @discardableResult
    private func inflateStoreCache() async -> RowndState {
        let store = Context.currentContext.store
        return await store.state.load()
    }

    private func displayHub(_ page: HubPageSelector) -> HubViewController {
        return displayHub(page, jsFnOptions: nil)
    }

    @discardableResult
    private func displayHub(_ page: HubPageSelector, jsFnOptions: Encodable?) -> HubViewController {
        let hubController = getHubViewController()

        Task { @MainActor in
            displayViewControllerOnTop(hubController)
            hubController.loadNewPage(targetPage: page, jsFnOptions: jsFnOptions)
        }

        return hubController
    }

    private func getHubViewController() -> HubViewController {

        if bottomSheetController.controller is HubViewController {
            return bottomSheetController.controller as! HubViewController
        }

        if Thread.isMainThread {
            return HubViewController()
        } else {
            var hubViewController: HubViewController?
            DispatchQueue.main.sync {
                hubViewController = HubViewController()
            }
            return hubViewController!
        }
    }

    internal func getRootViewController() -> UIViewController? {
        return UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .compactMap({$0 as? UIWindowScene})
            .first?.windows
            .filter({$0.isKeyWindow}).first?.rootViewController
    }

    private func displayViewControllerOnTop(_ viewController: UIViewController) {
        Task { @MainActor in
            let rootViewController = getRootViewController()

            // Don't try to present again if it's already presented
            if bottomSheetController.presentingViewController != nil {
                return
            }

            // TODO: Eventually, replace this with native iOS 15+ sheetPresentationController
            // But, we can't replace it yet (2022) since there are too many devices running iOS 14.
            bottomSheetController.controller = viewController
            bottomSheetController.modalPresentationStyle = .overFullScreen

            DispatchQueue.main.async {
                rootViewController?.present(self.bottomSheetController, animated: true, completion: nil)
            }
        }
    }

    internal static func isDisplayingHub() -> Bool {
        return inst.bottomSheetController.controller != nil && inst.bottomSheetController.presentingViewController != nil
    }

}

public class UserPropAccess {
    private var store: Store<RowndState> {
        get {
            return Context.currentContext.store
        }
    }
    public func get() -> UserState {
        return store.state.user.get()
    }

    public func get(field: String) -> Any {
        return store.state.user.get(field: field)
    }

    public func get<T>(field: String) -> T? {
        let value: T? = store.state.user.get(field: field)
        return value
    }

    public func set(data: [String: AnyCodable]) {
        store.state.user.set(data: data)
    }

    public func set(field: String, value: AnyCodable) {
        store.state.user.set(field: field, value: value)
    }

    public func isEncryptionPossible() throws {
        throw RowndError("Encryption is currently not enabled with this SDK. If you like to enable it, please reach out to support@rownd.io")
    }

    public func encrypt(plaintext: String) throws {
        throw RowndError("Encryption is currently not enabled with this SDK. If you like to enable it, please reach out to support@rownd.io")
    }

    public func decrypt(ciphertext: String) throws {
        throw RowndError("Encryption is currently not enabled with this SDK. If you like to enable it, please reach out to support@rownd.io")
    }
}

public enum RowndStateType {
    case auth, user, app, none
}

public enum UserFieldAccessType {
    case string, int, float, dictionary, array
}

public enum RowndSignInHint {
    case appleId, googleId, passkey,
         guest, anonymous // these two do the same thing
}

public enum RowndConnectSignInHint {
    case passkey
}

public struct RowndSignInOptions: Encodable {
    public init(postSignInRedirect: String? = Rownd.config.postSignInRedirect, intent: RowndSignInIntent? = nil, hint: String? = nil) {
        self.postSignInRedirect = postSignInRedirect
        self.intent = intent
        self.hint = hint
    }

    public var postSignInRedirect: String? = Rownd.config.postSignInRedirect
    public var intent: RowndSignInIntent?
    public var hint: String?

    enum CodingKeys: String, CodingKey {
        case intent
        case hint
        case postSignInRedirect = "post_login_redirect"
    }
}

public enum RowndSignInIntent: String, Codable {
    case signIn = "sign_in"
    case signUp = "sign_up"
}

public enum SignInType: String, Codable {
    case email = "email"
    case phone = "phone"
    case apple = "apple"
    case google = "google"
    case passkey = "passkey"
    case anonymous = "anonymous"
}

internal enum RowndSignInLoginStep: String, Codable {
    case initialize = "init"
    case noAccount = "no_account"
    case success = "success"
    case completing = "completing"
    case error = "error"
}

internal struct RowndSignInJsOptions: Encodable {
    public var token: String?
    public var loginStep: RowndSignInLoginStep?
    public var intent: RowndSignInIntent?
    public var userType: UserType?
    public var signInType: SignInType?

    enum CodingKeys: String, CodingKey {
        case token, intent
        case loginStep = "login_step"
        case userType = "user_type"
        case signInType = "sign_in_type"
    }
}

public struct RowndConnectPasskeySignInOptions: Encodable {
    public var status: Status?
    public var biometricType: String? = ""
    public var type: String = "passkey"
    public var error: String?
    internal func dictionary() -> [String: AnyCodable] {
        return ["status": AnyCodable(status),
                "biometric_type": AnyCodable(biometricType),
                "type": AnyCodable(type),
                "error": AnyCodable(error)
        ]
    }

    enum CodingKeys: String, CodingKey {
        case status, type, error
        case biometricType = "biometric_type"
    }
}

public enum Status: String, Codable {
    case loading
    case success
    case failed
}

struct RowndError: Error, CustomStringConvertible {
    var message: String

    init(_ message: String) {
        self.message = message
    }

    public var description: String {
        return message
    }
}
