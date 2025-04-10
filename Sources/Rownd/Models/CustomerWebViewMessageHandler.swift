import Foundation
import WebKit

struct RowndCustomerInteropMessage: Decodable {
    var type: CustomerMessageType
    var payload: CustomerMessagePayload?

    static func fromJson(message: String) throws -> RowndCustomerInteropMessage {
        let decoder = JSONDecoder()
        let messageTypeHolder = CustomerMessageTypeHolder()
        decoder.userInfo[.messageType] = messageTypeHolder
        let result = try decoder.decode(RowndCustomerInteropMessage.self, from: message.data(using: .utf8)!)
        return result
    }
}

enum CustomerMessagePayload: Decodable {
    case unknown
    case triggerSignInWithGoogle(TriggerSignInWithGoogleMessage)

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        guard let messageType = decoder.userInfo[.messageType] as? CustomerMessageTypeHolder,
              let type = messageType.type else {
            self = .unknown
            return
        }

        let objectContainer = try decoder.singleValueContainer()

        switch type {
        case .triggerSignInWithGoogle:
            let payload = try objectContainer.decode(TriggerSignInWithGoogleMessage.self)
            self = .triggerSignInWithGoogle(payload)
        case .unknown:
            self = .unknown
        }
    }
    
    struct TriggerSignInWithGoogleMessage: Codable {
        var intent: RowndSignInIntent?
        var hint: String?

        enum CodingKeys: String, CodingKey {
            case intent, hint
        }
    }
}

enum CustomerMessageType: String, Codable {
    case triggerSignInWithGoogle = "trigger_sign_in_with_google"
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let type = try container.decode(String.self)
        self = CustomerMessageType(rawValue: type) ?? .unknown

        if let messageType = decoder.userInfo[.messageType] as? CustomerMessageTypeHolder {
            messageType.type = self
        }
    }
}

class CustomerMessageTypeHolder {
    var type: CustomerMessageType?
}

class CustomerWebViewMessageHandler: NSObject, WKScriptMessageHandler {
    private var webViewId: String
    
    init(customerWebViewId: String) {
        self.webViewId = customerWebViewId
    }
    
    /// Receives messages from javascript in the web view
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let response = message.body as? String else { return }

        logger.trace("Received message from managed web view: \(Redact.redactSensitiveKeys(in: response))")

        do {
            let hubMessage = try RowndCustomerInteropMessage.fromJson(message: response)

            logger.debug("Message type: \(String(describing: hubMessage.type))")

            switch hubMessage.type {
            case .unknown: break
            case .triggerSignInWithGoogle:
                var signInWithGoogleMessage: CustomerMessagePayload.TriggerSignInWithGoogleMessage
                if case .triggerSignInWithGoogle(let message) = hubMessage.payload {
                    signInWithGoogleMessage = message
                    Rownd.googleSignInCoordinator.signIn(webViewId: self.webViewId, intent: signInWithGoogleMessage.intent, hint: signInWithGoogleMessage.hint)
                } else {
                    logger.error("Failed to decode message payload \(String(describing: hubMessage.payload))")
                }
            }
        } catch {
            logger.debug("Failed to decode message: \(String(describing: error))")
        }
    }
}
