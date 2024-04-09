//
//  AuthRepository.swift
//  rownd_ios_example
//
//  Created by Matt Hamann on 3/25/24.
//

import Combine
import Foundation
import AnyCodable
import Rownd

protocol AuthRepositoryProtocol {
    var internalAuthState: InternalAuthState { get }
    var rowndUser: RowndUser? { get }
    @MainActor func signUp() async
    @MainActor func signOut() async
    @MainActor func signUpWithApple() async
    @MainActor func continueAnonomyously() async
    @MainActor func manageAccount() async
    var internalAuthStatePublisher: Published<InternalAuthState>.Publisher { get }
    var userPublisher: Published<RowndUser?>.Publisher { get }
}

struct RowndUser: Serializable {
    let userId: String
    let googleId: String?
    let fullName: String?
    let email: String?
    let phoneNumber: String?
    let firstName: String?

    private enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case googleId = "google_id"
        case fullName = "full_name"
        case email = "email"
        case phoneNumber = "phone_number"
        case firstName = "first_name"
    }

    init?(from dictionary: [String: AnyCodable]) {
        self.userId = (dictionary[CodingKeys.userId.rawValue]?.value as? String) ?? ""
        self.googleId = dictionary[CodingKeys.googleId.rawValue]?.value as? String
        self.fullName = dictionary[CodingKeys.fullName.rawValue]?.value as? String
        self.email = dictionary[CodingKeys.email.rawValue]?.value as? String
        self.phoneNumber = dictionary[CodingKeys.phoneNumber.rawValue]?.value as? String
        self.firstName = dictionary[CodingKeys.firstName.rawValue]?.value as? String
    }
}

enum InternalAuthState {
    case loading
    case loggedIn
    case loggedOut
    case error
}

enum AuthError: Error {
    case invalidToken
}

final class AuthRepository: AuthRepositoryProtocol {    

//    @Published var user: User? {
//        didSet {
//            if let userId = user?.id {
//                let userIdString = "\(userId)"
//                print("User was set: \(userId)")
//            }
//        }
//    }

    @Published var rowndUser: RowndUser?
    @Published var internalAuthState: InternalAuthState = .loading
    private var authState = Rownd.getInstance().state().subscribe { $0.auth }
    private var rowndState = Rownd.getInstance().state().subscribe { $0 }
    private var userState = Rownd.getInstance().state().subscribe { $0.user }

    var internalAuthStatePublisher: Published<InternalAuthState>.Publisher { $internalAuthState }
    var userPublisher: Published<RowndUser?>.Publisher { $rowndUser }

    private var cancellables = Set<AnyCancellable>()
    private var shouldRetry: Bool = true
    private var isRowndStateInitialized = false

    init() {
        self.rowndState
            .$current
            .sink { state in
                guard state.isInitialized else { return }
                
                self.isRowndStateInitialized = true

                guard state.auth.isAuthenticated else {
                    self.internalAuthState = .loggedOut
                    return
                }
            }
            .store(in: &cancellables)

        self.authState
            .$current
            .sink { state in
                guard self.isRowndStateInitialized, state.isAuthenticated else { return }
                self.internalAuthState = .loading
                if let accessToken = state.accessToken,
                   state.isAccessTokenValid {
                    Task {
                        await self.exchangeRowndToken(idToken: accessToken)
                        self.internalAuthState = .loggedIn
                    }
                } else {
                    self.getAccessToken()
                }
            }
            .store(in: &cancellables)

        self.userState
            .$current
            .sink { [weak self] state in
                guard let self = self, !state.isLoading else { return }
                self.rowndUser = RowndUser(from: state.data)
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables = []
    }

    @MainActor func signUp() {
        DispatchQueue.main.async {
            Rownd.requestSignIn(
                RowndSignInOptions(
                    intent: .signIn
                )
            )
        }
    }

    @MainActor func signUpWithApple() {
        DispatchQueue.main.async {
            Rownd.requestSignIn(
                with: .appleId,
                signInOptions: RowndSignInOptions(
                    intent: .signUp
                )
            )
        }
    }

    @MainActor func continueAnonomyously() {
        // TODO: Will be implemented
    }

    @MainActor func manageAccount() {
        DispatchQueue.main.async {
            Rownd.manageAccount()
        }
    }

    @MainActor func signOut() {
        DispatchQueue.main.async {
            Rownd.signOut()
        }
        self.internalAuthState = .loggedOut
    }

    func getAccessToken() {
        Task {
            do {
                try await Rownd.getAccessToken()
            } catch {
                self.internalAuthState = .error
            }
        }
    }

    @MainActor func exchangeRowndToken(idToken: String) async {
        do {
            let resp = try await apiExchangeRowndToken(body: TokenExchangeBody( idToken: idToken ))
            print(String(describing: resp))
            
        } catch {
            print("Error exchanging token: \(String(describing: error))")
            if shouldRetry {
                self.shouldRetry = false
                // Only try once if the query timesout or fails
                Task { @MainActor in
                    await self.exchangeRowndToken(idToken: idToken)
                }
            } else {
                self.internalAuthState = .error
            }
        }
    }
}
