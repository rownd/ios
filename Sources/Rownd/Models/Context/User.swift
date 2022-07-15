//
//  Auth.swift
//  framework
//
//  Created by Matt Hamann on 7/8/22.
//

import Foundation
import UIKit
import ReSwift
import ReSwiftThunk
import AnyCodable

public struct UserState: Hashable {
    public var isLoading: Bool = false
    public var isErrored: Bool = false
    public var errorMessage: String?
    public var data: Dictionary<String, AnyCodable> = [:]
}

extension UserState: Codable {}

struct SetUserLoading: Action {
    var isLoading: Bool
}

struct SetUserData: Action {
    var payload: Dictionary<String, AnyCodable> = [:]
}

struct SetUserError: Action {
    var isErrored: Bool = true
    var errorMessage: String
}

func userReducer(action: Action, state: UserState?) -> UserState {
    var state = state ?? UserState()
    
    switch action {
    case let action as SetUserData:
        state.data = action.payload
    case let action as SetUserLoading:
        state.isLoading = action.isLoading
    default:
        break
    }
    
    return state
}

/* API / side-effecty things */

// Easily unwrap the main payload from the `app` key
struct UserDataPayload: Codable {
    var data: Dictionary<String, AnyCodable>
    var redacted: [String]?
}

struct UserDataResource: APIResource {
    typealias ModelType = UserDataPayload
    
    var methodPath: String {
        guard let appId = store.state.appConfig.id else { return "/me/applications/unknown/data" }
        return "/me/applications/\(appId)/data"
    }
    
    var headers: Dictionary<String, String>? = Dictionary<String, String>()
}

class UserData {
    //    private var req: APIRequest<AppConfigResource>?
    
    static func fetch() -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let state = getState() else { return }
            guard !state.user.isLoading else { return }
            
            Task.init {
                guard let accessToken = await Rownd.getAccessToken() else {
                    return
                }
                
                dispatch(SetUserLoading(isLoading: true))
                var resource = UserDataResource()
                resource.headers = ["Authorization": "Bearer \(accessToken)"]
                let request = APIRequest(resource: resource)
                
                request.execute { userResp in
                    // This guard ensures that the resource allocator doesn't clean up the request object before
                    // the parsing closure in request.execute() is finished with it.
                    guard request.decode != nil else { return }
                    print(userResp)
                    //                print(self.req?.decode)
                    dispatch(SetUserLoading(isLoading: false))
                    dispatch(SetUserData(payload: userResp?.data ?? [:]))
                }
            }
        }
    }
    
    static func save() -> Thunk<RowndState> {
        return save(store.state.user.data)
    }
    
    static func save(_ data: Dictionary<String, AnyCodable>) -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let state = getState() else { return }
            guard !state.user.isLoading else { return }
            
            dispatch(SetUserData(payload: data))
            
            Task.init {
                guard let accessToken = await Rownd.getAccessToken() else {
                    return
                }
                
                dispatch(SetUserLoading(isLoading: true))
                var resource = UserDataResource()
                resource.headers = [
                    "Authorization": "Bearer \(accessToken)",
                    "Content-Type": "application/json"
                ]
                let request = APIRequest(resource: resource)
                
                // TODO: Get current user state as json string for body
                let encoder = JSONEncoder()
                let userDataPayload = UserDataPayload(data: data)
                var body: Data? = nil
                do {
                    body = try encoder.encode(userDataPayload)
                } catch {
                    dispatch(SetUserError(errorMessage: "The user profile could not be encoded: \(error)"))
                }
                request.execute(method: "PUT", body: body) { userResp in
                    // This guard ensures that the resource allocator doesn't clean up the request object before
                    // the parsing closure in request.execute() is finished with it.
                    guard request.decode != nil else { return }
                    logger.debug("Decoded user response: \(String(describing: userResp))")

                    dispatch(SetUserData(payload: userResp?.data ?? [:]))
                    dispatch(SetUserLoading(isLoading: false))
                }
            }
        }
    }
}
