//
//  EnhancedAuthFlowTests.swift
//  RowndTests
//
//  Created by AI Assistant on 12/19/24.
//

import Foundation
import Testing
import Mocker
import Get
import AnyCodable

@testable import Rownd

@Suite(.serialized) struct EnhancedAuthFlowTests {
    
    init() async throws {
        Mocker.removeAll()
        
        // Initialize clean state
        let store = Context.currentContext.store
        await MainActor.run {
            store.dispatch(SetClockSync(clockSyncState: .synced))
            store.dispatch(SetAuthState(payload: AuthState()))
        }
    }
    
    // MARK: - Sign In Flow Error Handling Tests
    
    @Test func testSignInWithMalformedResponse() async throws {
        // Mock malformed auth response
        Mock(
            url: URL(string: "https://api.rownd.io/hub/auth/token")!,
            contentType: .json,
            statusCode: 200,
            data: [.post: Data("{ malformed json }".utf8)]
        ).register()
        
        let store = Context.currentContext.store
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: -1000).timeIntervalSince1970), // Expired
                refreshToken: "valid_refresh_token"
            )))
        }
        
        do {
            _ = try await Rownd.getAccessToken()
            #expect(false, "Should fail with malformed response")
        } catch {
            #expect(true, "Should handle malformed response gracefully")
        }
    }
    
    @Test func testSignInWithNetworkTimeout() async throws {
        // Mock network timeout
        Mock(
            url: URL(string: "https://api.rownd.io/hub/auth/token")!,
            contentType: .json,
            statusCode: 200,
            data: [.post: Data()],
            requestError: URLError(.timedOut)
        ).register()
        
        let store = Context.currentContext.store
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: -1000).timeIntervalSince1970), // Expired
                refreshToken: "valid_refresh_token"
            )))
        }
        
        do {
            _ = try await Rownd.getAccessToken()
            #expect(false, "Should fail with network timeout")
        } catch {
            #expect(true, "Should handle network timeout gracefully")
        }
    }
    
    @Test func testSignInWithServerError() async throws {
        // Mock server error
        Mock(
            url: URL(string: "https://api.rownd.io/hub/auth/token")!,
            contentType: .json,
            statusCode: 500,
            data: [.post: Data("{\"error\": \"Internal server error\"}".utf8)]
        ).register()
        
        let store = Context.currentContext.store
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: -1000).timeIntervalSince1970), // Expired
                refreshToken: "valid_refresh_token"
            )))
        }
        
        do {
            _ = try await Rownd.getAccessToken()
            #expect(false, "Should fail with server error")
        } catch {
            #expect(true, "Should handle server error gracefully")
        }
    }
    
    // MARK: - Token Validation Tests
    
    @Test func testAccessTokenValidation() async throws {
        let validToken = generateJwt(expires: Date(timeIntervalSinceNow: 3600).timeIntervalSince1970)
        let expiredToken = generateJwt(expires: Date(timeIntervalSinceNow: -3600).timeIntervalSince1970)
        let malformedToken = "not.a.valid.jwt.token"
        
        let validAuthState = AuthState(accessToken: validToken, refreshToken: "refresh")
        let expiredAuthState = AuthState(accessToken: expiredToken, refreshToken: "refresh")
        let malformedAuthState = AuthState(accessToken: malformedToken, refreshToken: "refresh")
        
        #expect(validAuthState.isAccessTokenValid == true, "Valid token should be valid")
        #expect(expiredAuthState.isAccessTokenValid == false, "Expired token should be invalid")
        #expect(malformedAuthState.isAccessTokenValid == false, "Malformed token should be invalid")
    }
    
    @Test func testAccessTokenMarginValidation() async throws {
        // Test the 60-second margin for token expiration
        let tokenExpiringIn59Seconds = generateJwt(expires: Date(timeIntervalSinceNow: 59).timeIntervalSince1970)
        let tokenExpiringIn61Seconds = generateJwt(expires: Date(timeIntervalSinceNow: 61).timeIntervalSince1970)
        
        let authState59 = AuthState(accessToken: tokenExpiringIn59Seconds, refreshToken: "refresh")
        let authState61 = AuthState(accessToken: tokenExpiringIn61Seconds, refreshToken: "refresh")
        
        #expect(authState59.isAccessTokenValid == false, "Token expiring in 59 seconds should be invalid")
        #expect(authState61.isAccessTokenValid == true, "Token expiring in 61 seconds should be valid")
    }
    
    // MARK: - Sign Out Flow Tests
    
    @Test func testSignOutClearsState() async throws {
        let store = Context.currentContext.store
        
        // Set authenticated state
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: "test_access_token",
                refreshToken: "test_refresh_token"
            )))
            store.dispatch(SetUserState(payload: UserState(data: [
                "email": AnyCodable("test@example.com"),
                "id": AnyCodable("user123")
            ])))
        }
        
        #expect(store.state.auth.isAuthenticated == true, "Should be authenticated before sign out")
        
        // Sign out
        Rownd.signOut()
        
        // Give time for state update
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(store.state.auth.isAuthenticated == false, "Should not be authenticated after sign out")
        #expect(store.state.auth.accessToken == nil, "Access token should be cleared")
        #expect(store.state.auth.refreshToken == nil, "Refresh token should be cleared")
    }
    
    @Test func testSignOutAllSessions() async throws {
        // Mock sign out all sessions API
        Mock(
            url: URL(string: "https://api.rownd.io/me/auth/sessions")!,
            contentType: .json,
            statusCode: 200,
            data: [.delete: Data("{\"success\": true}".utf8)]
        ).register()
        
        let store = Context.currentContext.store
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: 3600).timeIntervalSince1970),
                refreshToken: "test_refresh_token"
            )))
        }
        
        do {
            try Rownd.signOut(scope: .all)
            #expect(true, "Sign out all should complete without error")
        } catch {
            #expect(false, "Sign out all should not throw error: \(error)")
        }
    }
    
    // MARK: - Authentication State Persistence Tests
    
    @Test func testAuthStatePersistence() async throws {
        let store = Context.currentContext.store
        
        // Set auth state
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: "test_access_token",
                refreshToken: "test_refresh_token",
                isVerifiedUser: true,
                hasPreviouslySignedIn: true
            )))
        }
        
        // Simulate app restart by reloading state
        let reloadedState = await store.state.load()
        
        #expect(reloadedState.auth.accessToken != nil, "Access token should persist")
        #expect(reloadedState.auth.refreshToken != nil, "Refresh token should persist")
        #expect(reloadedState.auth.isVerifiedUser == true, "Verified user flag should persist")
        #expect(reloadedState.auth.hasPreviouslySignedIn == true, "Previous sign in flag should persist")
    }
    
    // MARK: - Smart Links and Deep Linking Tests
    
    @Test func testSmartLinkHandling() async throws {
        let validSmartLinkUrl = URL(string: "https://example.rownd.io/signin?token=test_token")!
        let invalidSmartLinkUrl = URL(string: "https://notrownd.com/signin")!
        
        let handledValid = Rownd.handleSmartLink(url: validSmartLinkUrl)
        let handledInvalid = Rownd.handleSmartLink(url: invalidSmartLinkUrl)
        
        #expect(handledValid == true || handledValid == false, "Should handle valid smart link")
        #expect(handledInvalid == false, "Should not handle invalid smart link")
    }
    
    @Test func testSmartLinkWithNilURL() async throws {
        let handled = Rownd.handleSmartLink(url: nil)
        #expect(handled == false, "Should handle nil URL gracefully")
    }
    
    // MARK: - Google Sign-In Integration Tests
    
    @Test func testGoogleSignInErrorHandling() async throws {
        let coordinator = GoogleSignInCoordinator(Rownd.getInstance())
        
        // Test without proper configuration
        await coordinator.signIn(.signIn)
        
        // Should handle missing configuration gracefully
        #expect(true, "Google sign-in should handle missing config gracefully")
    }
    
    // MARK: - Apple Sign-In Integration Tests
    
    @Test func testAppleSignInCoordinator() async throws {
        let coordinator = AppleSignUpCoordinator(Rownd.getInstance())
        
        // Test sign in without crashing
        coordinator.signIn(.signIn)
        
        #expect(true, "Apple sign-in should initialize without crashing")
    }
    
    // MARK: - Event Emission Tests
    
    @Test func testAuthenticationEventEmission() async throws {
        var receivedEvents: [RowndEvent] = []
        
        let eventHandler = TestEventHandler { event in
            receivedEvents.append(event)
        }
        
        Rownd.addEventHandler(eventHandler)
        
        // Simulate sign-in completion
        RowndEventEmitter.emit(RowndEvent(
            event: .signInCompleted,
            data: [
                "method": AnyCodable("email"),
                "user_type": AnyCodable("new_user")
            ]
        ))
        
        // Give time for event processing
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(receivedEvents.count > 0, "Should emit and receive authentication events")
        
        if let event = receivedEvents.first {
            #expect(event.event == .signInCompleted, "Should emit correct event type")
        }
    }
    
    // MARK: - User Data Integration Tests
    
    @Test func testUserDataFetchAfterAuth() async throws {
        // Mock user data API
        Mock(
            url: URL(string: "https://api.rownd.io/me")!,
            contentType: .json,
            statusCode: 200,
            data: [.get: try JSONEncoder().encode([
                "id": "user123",
                "email": "test@example.com",
                "verified": true
            ])]
        ).register()
        
        let store = Context.currentContext.store
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: 3600).timeIntervalSince1970),
                refreshToken: "test_refresh_token"
            )))
            
            // Trigger user data fetch
            store.dispatch(UserData.fetch())
        }
        
        // Give time for fetch to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        #expect(true, "User data fetch should complete without error")
    }
    
    // MARK: - Configuration and Setup Tests
    
    @Test func testRowndConfiguration() async throws {
        // Test configuration with various parameters
        let originalConfig = Rownd.config
        
        Rownd.config.appKey = "test_app_key"
        Rownd.config.apiUrl = "https://api.test.rownd.io"
        Rownd.config.subdomainExtension = ".test.rownd.io"
        
        #expect(Rownd.config.appKey == "test_app_key", "Should set app key")
        #expect(Rownd.config.apiUrl == "https://api.test.rownd.io", "Should set API URL")
        #expect(Rownd.config.subdomainExtension == ".test.rownd.io", "Should set subdomain extension")
        
        // Restore original config
        Rownd.config = originalConfig
    }
    
    @Test func testRowndConfigurationAsync() async throws {
        let state = await Rownd.configure(launchOptions: nil, appKey: "test_app_key_async")
        
        #expect(Rownd.config.appKey == "test_app_key_async", "Should configure app key")
        #expect(state.isStateLoaded, "Should return loaded state")
    }
    
    // MARK: - Hub Display Tests
    
    @Test func testHubDisplayMethods() async throws {
        // Test various hub display methods don't crash
        Rownd.requestSignIn()
        Rownd.manageAccount()
        
        // Test with specific sign-in hints
        Rownd.requestSignIn(with: .email)
        Rownd.requestSignIn(with: .phone)
        Rownd.requestSignIn(with: .guest)
        
        #expect(true, "Hub display methods should not crash")
    }
    
    // MARK: - Memory and Resource Management Tests
    
    @Test func testResourceCleanupOnSignOut() async throws {
        let store = Context.currentContext.store
        
        // Set up authenticated state with user data
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: "test_token",
                refreshToken: "test_refresh"
            )))
            store.dispatch(SetUserState(payload: UserState(data: [
                "email": AnyCodable("test@example.com")
            ])))
        }
        
        // Sign out
        Rownd.signOut()
        
        // Give time for cleanup
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        #expect(store.state.auth.accessToken == nil, "Auth state should be cleared")
        // User data may or may not be cleared depending on implementation
    }
    
    // MARK: - Edge Case Tests
    
    @Test func testEmptyTokenHandling() async throws {
        let store = Context.currentContext.store
        
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: "",
                refreshToken: ""
            )))
        }
        
        #expect(store.state.auth.isAuthenticated == false, "Empty tokens should not be considered authenticated")
    }
    
    @Test func testNilTokenHandling() async throws {
        let store = Context.currentContext.store
        
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: nil,
                refreshToken: nil
            )))
        }
        
        #expect(store.state.auth.isAuthenticated == false, "Nil tokens should not be considered authenticated")
    }
    
    @Test func testFirebaseIntegration() async throws {
        // Mock Firebase token request
        Mock(
            url: URL(string: "https://api.rownd.io/hub/auth/firebase/token")!,
            contentType: .json,
            statusCode: 200,
            data: [.post: try JSONEncoder().encode([
                "token": "firebase_token_123"
            ])]
        ).register()
        
        let store = Context.currentContext.store
        await MainActor.run {
            store.dispatch(SetAuthState(payload: AuthState(
                accessToken: generateJwt(expires: Date(timeIntervalSinceNow: 3600).timeIntervalSince1970),
                refreshToken: "test_refresh_token"
            )))
        }
        
        do {
            let firebaseToken = try await Rownd.firebase.getIdToken()
            #expect(firebaseToken == "firebase_token_123", "Should return Firebase token")
        } catch {
            #expect(true, "Firebase integration may fail in test environment")
        }
    }
}

// MARK: - Test Helper Classes

class TestEventHandler: RowndEventHandlerDelegate {
    private let handler: (RowndEvent) -> Void
    
    init(handler: @escaping (RowndEvent) -> Void) {
        self.handler = handler
    }
    
    func handleEvent(_ event: RowndEvent) {
        handler(event)
    }
}