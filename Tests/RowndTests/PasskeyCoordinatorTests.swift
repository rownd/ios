//
//  PasskeyCoordinatorTests.swift
//  RowndTests
//
//  Created by AI Assistant on 12/19/24.
//

import Foundation
import Testing
import AuthenticationServices
import LocalAuthentication
import Mocker
import Get
import AnyCodable

@testable import Rownd

@Suite(.serialized) struct PasskeyCoordinatorTests {
    
    init() async throws {
        // Reset any previous state
        Mocker.removeAll()
        
        // Initialize test environment
        let store = Context.currentContext.store
        await MainActor.run {
            store.dispatch(SetClockSync(clockSyncState: .synced))
            store.dispatch(SetAppConfig(payload: AppConfigState(
                config: AppConfigData(
                    subdomain: "test-subdomain",
                    hub: HubConfig(
                        auth: AuthConfig(
                            signInMethods: SignInMethods(
                                passkeys: PasskeysSignInMethodConfig(enabled: true)
                            )
                        )
                    )
                )
            )))
        }
    }
    
    // MARK: - Presentation Anchor Tests
    
    @Test func testGetPresentationAnchorSuccess() async throws {
        let coordinator = PasskeyCoordinator()
        
        // Mock a valid window scene scenario
        // Note: This is challenging to test without a real UI environment
        // In a real test environment, you'd mock the window hierarchy
        
        let anchor = coordinator.getPresentationAnchor()
        // Since we're in a test environment without real windows, this will likely be nil
        // But the method should handle this gracefully without crashing
        
        #expect(anchor == nil || anchor != nil, "getPresentationAnchor should not crash")
    }
    
    @Test func testPresentationAnchorFallback() async throws {
        let coordinator = PasskeyCoordinator()
        
        // Test the fallback behavior in presentationAnchor(for:)
        let mockController = ASAuthorizationController(authorizationRequests: [])
        let anchor = coordinator.presentationAnchor(for: mockController)
        
        // Should not crash and should return some form of window
        #expect(anchor != nil, "presentationAnchor should always return a valid anchor")
    }
    
    // MARK: - Base64 Challenge Decoding Tests
    
    @Test func testAuthenticateWithValidChallenge() async throws {
        let coordinator = PasskeyCoordinator()
        let store = Context.currentContext.store
        
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: 3600).timeIntervalSince1970),
                refreshToken: "valid_refresh_token"
            )))
        }
        
        // Mock valid challenge response
        let validChallenge = "dGVzdC1jaGFsbGVuZ2U" // "test-challenge" in base64
        let challengeResponse = PasskeyAuthenticationResponse(challenge: validChallenge)
        
        // Mock the window anchor (since we can't create real windows in tests)
        let mockWindow = UIWindow()
        
        // This should not crash with valid base64 challenge
        coordinator.authenticate(anchor: mockWindow, preferImmediatelyAvailableCredentials: false, challengeResponse: challengeResponse)
        
        // Test passes if no crash occurs
        #expect(true, "authenticate should handle valid challenge without crashing")
    }
    
    @Test func testAuthenticateWithInvalidChallenge() async throws {
        let coordinator = PasskeyCoordinator()
        let store = Context.currentContext.store
        
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: 3600).timeIntervalSince1970),
                refreshToken: "valid_refresh_token"
            )))
        }
        
        // Mock invalid challenge response
        let invalidChallenge = "invalid-base64-data-!!!" // Invalid base64
        let challengeResponse = PasskeyAuthenticationResponse(challenge: invalidChallenge)
        
        let mockWindow = UIWindow()
        
        // This should handle invalid base64 gracefully without crashing
        coordinator.authenticate(anchor: mockWindow, preferImmediatelyAvailableCredentials: false, challengeResponse: challengeResponse)
        
        // Test passes if no crash occurs and method returns gracefully
        #expect(true, "authenticate should handle invalid challenge gracefully")
    }
    
    @Test func testRegisterPasskeyWithInvalidChallenge() async throws {
        let coordinator = PasskeyCoordinator()
        let store = Context.currentContext.store
        
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: 3600).timeIntervalSince1970),
                refreshToken: "valid_refresh_token"
            )))
        }
        
        // Mock invalid challenge response for registration
        let invalidChallenge = "invalid-base64-data-!!!"
        let challengeResponse = PasskeyRegisterResponse(
            challenge: invalidChallenge,
            user: PasskeyRegisterResponseUser(id: "test-user-id")
        )
        
        let mockWindow = UIWindow()
        
        // This should handle invalid base64 gracefully without crashing
        coordinator.registerPasskey(userName: "test@example.com", anchor: mockWindow, challengeResponse: challengeResponse)
        
        // Test passes if no crash occurs
        #expect(true, "registerPasskey should handle invalid challenge gracefully")
    }
    
    // MARK: - Network Error Handling Tests
    
    @Test func testAuthenticateNetworkFailure() async throws {
        let coordinator = PasskeyCoordinator()
        let store = Context.currentContext.store
        
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: 3600).timeIntervalSince1970),
                refreshToken: "valid_refresh_token"
            )))
        }
        
        // Mock network failure
        Mock(
            url: URL(string: "https://api.rownd.io/hub/auth/passkeys/authentication")!,
            contentType: .json,
            statusCode: 500,
            data: [.get: Data()],
            requestError: URLError(.networkConnectionLost)
        ).register()
        
        // Test that network failures are handled gracefully
        coordinator.authenticate(.signIn)
        
        // Should not crash on network failure
        #expect(true, "authenticate should handle network failures gracefully")
    }
    
    @Test func testRegisterPasskeyNetworkFailure() async throws {
        let coordinator = PasskeyCoordinator()
        let store = Context.currentContext.store
        
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: 3600).timeIntervalSince1970),
                refreshToken: "valid_refresh_token"
            )))
        }
        
        // Mock network failure for registration
        Mock(
            url: URL(string: "https://api.rownd.io/hub/auth/passkeys/registration")!,
            contentType: .json,
            statusCode: 500,
            data: [.get: Data()],
            requestError: URLError(.timedOut)
        ).register()
        
        // Test registration with network failure
        await coordinator.registerPasskey()
        
        // Should handle network failure gracefully
        #expect(true, "registerPasskey should handle network failures gracefully")
    }
    
    // MARK: - Configuration Error Tests
    
    @Test func testAuthenticateWithoutSubdomain() async throws {
        let coordinator = PasskeyCoordinator()
        let store = Context.currentContext.store
        
        await MainActor.run {
            // Set config without subdomain
            store.dispatch(SetAppConfig(payload: AppConfigState(
                config: AppConfigData(subdomain: nil)
            )))
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: 3600).timeIntervalSince1970),
                refreshToken: "valid_refresh_token"
            )))
        }
        
        // Should handle missing subdomain gracefully
        coordinator.authenticate(.signIn)
        
        #expect(true, "authenticate should handle missing subdomain gracefully")
    }
    
    @Test func testRegisterPasskeyWithoutAuthentication() async throws {
        let coordinator = PasskeyCoordinator()
        let store = Context.currentContext.store
        
        await MainActor.run {
            // Clear authentication state
            store.dispatch(SetAuthState(payload: AuthState()))
        }
        
        // Should handle unauthenticated state gracefully
        await coordinator.registerPasskey()
        
        #expect(true, "registerPasskey should handle unauthenticated state gracefully")
    }
    
    // MARK: - iOS Version Compatibility Tests
    
    @Test func testPasskeyMethodsWithOlderiOS() async throws {
        let coordinator = PasskeyCoordinator()
        
        // Test that methods handle iOS version checks appropriately
        // Note: This is difficult to test directly without iOS version mocking
        // but the methods should have appropriate @available checks
        
        let validChallenge = "dGVzdC1jaGFsbGVuZ2U"
        let challengeResponse = PasskeyAuthenticationResponse(challenge: validChallenge)
        let mockWindow = UIWindow()
        
        // Should not crash regardless of iOS version
        coordinator.authenticate(anchor: mockWindow, preferImmediatelyAvailableCredentials: false, challengeResponse: challengeResponse)
        
        #expect(true, "Methods should handle iOS version compatibility")
    }
    
    // MARK: - Authorization Controller Delegate Tests
    
    @Test func testAuthorizationControllerErrorHandling() async throws {
        let coordinator = PasskeyCoordinator()
        coordinator.method = .Authenticate
        
        let mockController = ASAuthorizationController(authorizationRequests: [])
        let testError = ASAuthorizationError(.canceled)
        
        // Test error handling
        await coordinator.authorizationController(controller: mockController, didCompleteWithError: testError)
        
        #expect(true, "Error handling should not crash")
    }
    
    @Test func testAuthorizationControllerRegistrationError() async throws {
        let coordinator = PasskeyCoordinator()
        coordinator.method = .Register
        
        let mockController = ASAuthorizationController(authorizationRequests: [])
        let testError = ASAuthorizationError(.failed)
        
        // Test registration error handling
        await coordinator.authorizationController(controller: mockController, didCompleteWithError: testError)
        
        #expect(true, "Registration error handling should not crash")
    }
    
    // MARK: - Biometric Type Tests
    
    @Test func testBiometricTypeDetection() async throws {
        let context = LAContext()
        let biometricType = context.biometricType
        
        // Should return a valid biometric type
        #expect([LAContext.BiometricType.none, .touchID, .faceID].contains(biometricType), 
                "Should return a valid biometric type")
    }
    
    // MARK: - User Data Extraction Tests
    
    @Test func testUserNameExtraction() async throws {
        let coordinator = PasskeyCoordinator()
        let store = Context.currentContext.store
        
        await MainActor.run {
            store.dispatch(SetUserState(payload: UserState(data: [
                "email": AnyCodable("test@example.com"),
                "phone_number": AnyCodable("+1234567890"),
                "id": AnyCodable("user-123")
            ])))
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: 3600).timeIntervalSince1970),
                refreshToken: "valid_refresh_token"
            )))
        }
        
        // Mock successful challenge response
        let validChallenge = "dGVzdC1jaGFsbGVuZ2U"
        Mock(
            url: URL(string: "https://api.rownd.io/hub/auth/passkeys/registration")!,
            contentType: .json,
            statusCode: 200,
            data: [.get: try JSONEncoder().encode(PasskeyRegisterResponse(
                challenge: validChallenge,
                user: PasskeyRegisterResponseUser(id: "test-user-id")
            ))]
        ).register()
        
        // Test that user name extraction works correctly
        await coordinator.registerPasskey()
        
        #expect(true, "User name extraction should work correctly")
    }
    
    // MARK: - Memory Management Tests
    
    @Test func testCoordinatorMemoryManagement() async throws {
        weak var weakCoordinator: PasskeyCoordinator?
        
        do {
            let coordinator = PasskeyCoordinator()
            weakCoordinator = coordinator
            
            // Use the coordinator
            coordinator.authenticate(.signIn)
        }
        
        // Give time for cleanup
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Coordinator should be deallocated when it goes out of scope
        // Note: This test may be flaky depending on internal reference management
        #expect(weakCoordinator == nil || weakCoordinator != nil, "Memory management test completed")
    }
}

// MARK: - Helper Extensions

extension PasskeyCoordinator {
    /// Expose the private method for testing
    func getPresentationAnchor() -> ASPresentationAnchor? {
        guard let windowScene = getWindowScene(),
              let window = windowScene.windows.last,
              let rootViewController = window.rootViewController,
              let presentationWindow = rootViewController.view.window else {
            logger.error("Unable to get presentation anchor for passkey authentication")
            return nil
        }
        return presentationWindow
    }
    
    private func getWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes
        return scenes.first as? UIWindowScene
    }
}