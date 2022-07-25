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

public struct AppConfigState: Hashable {
    public var isLoading: Bool = false
    public var id: String?
    public var icon: String?
    public var userVerificationFields: [String]?
    public var schema: Dictionary<String, AppSchemaField>?
}

extension AppConfigState: Codable {
    enum CodingKeys: String, CodingKey {
        case id, icon, schema
        case userVerificationFields = "user_verification_fields"
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

/* API / side-effecty things */

// Easily unwrap the main payload from the `app` key
struct AppConfigResponse: Decodable {
    var app: AppConfigState
}

struct AppConfigResource: APIResource {
    var headers: Dictionary<String, String>?
    
    typealias ModelType = AppConfigResponse
    
    var methodPath: String {
        return "/hub/app-config"
    }
}

class AppConfig {
    static func requestAppState() -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let state = getState() else { return }
            guard !state.appConfig.isLoading else { return }
            dispatch(SetAppLoading(isLoading: true))

            Task.init {
                let appConfig = await AppConfig.fetch()
                
                dispatch(SetAppConfig(payload: appConfig?.app ?? state.appConfig))
                dispatch(SetAppLoading(isLoading: false))
            }
        }
    }

    static func fetch() async -> AppConfigResponse? {
        let resource = AppConfigResource()
        let request = APIRequest(resource: resource)

        return await withCheckedContinuation { continuation in
            request.execute { appConfig in
                // This guard ensures that the resource allocator doesn't clean up the request object before
                // the parsing closure in request.execute() is finished with it.
                guard request.decode != nil else {
                    continuation.resume(returning: nil)
                    return
                }
                logger.trace("fetched app_config \(String(describing: appConfig))")
                continuation.resume(returning: appConfig)
            }
        }
    }
}
