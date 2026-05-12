//
//  InstantUsers.swift
//  Rownd
//
//  Created by Matt Hamann on 4/18/25.
//

import Combine

@MainActor
class InstantUsers {
    private let context: Context
    private var cancellables = Set<AnyCancellable>()
    private var hasTriggeredConversion: Bool = false

    init(
        context: Context
    ) {
        self.context = context
    }

    func tmpForceInstantUserConversionIfRequested() {
        if !Rownd.config.forceInstantUserConversion {
            return
        }

        let subscriber = Context.currentContext.store.subscribe {
            $0
        }
        subscriber.$current
            .map {
                (
                    $0.auth.isAuthenticated,
                    $0.user.authLevel
                )
            }
            .removeDuplicates(
                by: ==
            )
            .sink { [weak self] isAuthenticated, authLevel in
                guard let self = self, isAuthenticated else { return }

                if !self.hasTriggeredConversion && authLevel == .instant {
                    self.hasTriggeredConversion = true

                    var signInOptions = RowndSignInOptions()
                    signInOptions.title = "Add a sign-in method"
                    signInOptions.subtitle = "To make sure you can always access your account, please add a sign-in method."
                    signInOptions.intent = .signUp
                    Rownd.requestSignInForcedConversion(signInOptions)
                    return
                }

                // User has converted to a non-instant auth level (verified, unverified, guest).
                // Release the lock so the Hub's post-success auto-close can proceed.
                if self.hasTriggeredConversion && authLevel != .instant && authLevel != .unknown {
                    Rownd.releaseForcedConversionLock()
                    subscriber.unsubscribe()
                }
            }.store(
                in: &self.cancellables
            )
    }
}
