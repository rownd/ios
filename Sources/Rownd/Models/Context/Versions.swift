//
//  Versions.swift
//
//
//  Created by Bobby Radford on 3/4/24.
//

import Foundation
import Get
import ReSwift
import ReSwiftThunk

public struct VersionsState: Hashable, Codable {
    var loaded: Bool = false
    var isLoading: Bool = false
    var versions: Dictionary<String, MobileAppVersion> = [:]
    
    enum CodingKeys: String, CodingKey {
        case loaded, isLoading, versions
    }
}


internal struct SetVersionsLoading: Action {
    var isLoading: Bool
}

internal struct SetVersions: Action {
    var payload: Dictionary<String, MobileAppVersion>
}

internal struct SetVersionsLoaded: Action {
    var loaded: Bool
}

func versionsReducer(action: Action, state: VersionsState?) -> VersionsState {
    var state = state ?? VersionsState()
    
    switch action {
    case let action as SetVersionsLoading:
        state.isLoading = action.isLoading;
    case let action as SetVersions:
        state.versions = action.payload
    case let action as SetVersionsLoaded:
        state.loaded = action.loaded
    default:
        break
    }
    
    return state
}

struct MobileAppVersionsResponse: Decodable {
    var results: [MobileAppVersion]
}

struct MobileAppVersion: Hashable {
    public var id: String
    public var name: String
    public var platform: String
    public var appId: String
    public var createdAt: String
    public var createdBy: String
}

extension MobileAppVersion: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, platform
        case appId = "app_id"
        case createdAt = "created_at"
        case createdBy = "created_by"
    }
}

class VersionsData {
    static func requestVersionsData() -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let state = getState() else { return }
            guard let appId = state.appConfig.id else { return }
            
            if !state.versions.isLoading {
                Task { @MainActor in
                    dispatch(SetVersionsLoading(isLoading: true))
                }

                Task {
                    defer {
                        Task { @MainActor in
                            dispatch(SetVersionsLoading(isLoading: false))
                        }
                    }
                    
                    let versions = await VersionsData.fetch(appId: appId)

                    Task { @MainActor in
                        dispatch(SetVersions(payload: versions ?? state.versions.versions))
                        dispatch(SetVersionsLoaded(loaded: true)) // TODO: will this still work loading state from disk?
                    }
                }
            }
        }
    }
    
    static func fetch(appId: String) async -> Dictionary<String, MobileAppVersion>? {
        do {
            let response: MobileAppVersionsResponse = try await Rownd.apiClient.send(Get.Request(url: URL(string: "/applications/\(appId)/automations/mobile/versions")!, method: "get")).value

            let dictionary = response.results.reduce(into: [:]) { accumulator, version in
                accumulator[version.id] = version
            }
            
            return dictionary
        } catch {
            logger.error("Failed to fetch mobile app versions: \(String(describing: error))")
            return nil
        }
    }
}

