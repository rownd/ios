import Foundation
import OSLog

private let log = Logger(subsystem: "io.rownd.sdk", category: "supertokens-sync")

private final class SuperTokensSyncEventHandler: RowndEventHandlerDelegate {
    func handleRowndEvent(_ event: RowndEvent) {
        let userType = event.data?["user_type"] ?? nil

        guard event.event == .signInCompleted,
              userType?.value as? String == "new_user",
              let appInfo = Rownd.config.supertokens?.appInfo
        else {
            return
        }

        Task {
            do {
                guard let accessToken = try await Rownd.getAccessToken() else {
                    return
                }

                await syncUserToSuperTokens(accessToken: accessToken, appInfo: appInfo)
            } catch {
                log.error("[Rownd->ST] failed to read access token for migration: \(error.localizedDescription)")
            }
        }
    }
}

private let superTokensSyncEventHandler = SuperTokensSyncEventHandler()

func registerSuperTokensSyncEventHandler() {
    let alreadyRegistered = Context.currentContext.eventListeners.contains { listener in
        listener === superTokensSyncEventHandler
    }

    if !alreadyRegistered {
        Context.currentContext.eventListeners.append(superTokensSyncEventHandler)
    }
}

func syncUserToSuperTokens(
    accessToken: String,
    appInfo: SuperTokensAppInfo
) async {
    guard let url = appInfo.migrationURL else {
        log.error(
            "[Rownd->ST] invalid migration URL constructed from apiDomain=\(appInfo.apiDomain) apiBasePath=\(appInfo.apiBasePath)"
        )
        return
    }

    do {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpShouldHandleCookies = true

        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            log.error("[Rownd->ST] migrate failed with status: \(http.statusCode)")
        }
    } catch {
        log.error("[Rownd->ST] migrate failed (non-fatal): \(error.localizedDescription)")
    }
}
