//
//  Pages.swift
//
//
//  Created by Bobby Radford on 3/4/24.
//

import Foundation
import Get
import ReSwift
import ReSwiftThunk
import AnyCodable

public struct PagesState: Hashable, Codable {
    var loaded: Bool = false
    var isLoading: Bool = false
    var pages: Dictionary<String, MobileAppPage> = [:]
    
    enum CodingKeys: String, CodingKey {
        case loaded, isLoading, pages
    }
}


internal struct SetPagesLoading: Action {
    var isLoading: Bool
}

internal struct SetPages: Action {
    var payload: Dictionary<String, MobileAppPage>
}

internal struct SetPagesLoaded: Action {
    var loaded: Bool
}

func pagesReducer(action: Action, state: PagesState?) -> PagesState {
    var state = state ?? PagesState()
    
    switch action {
    case let action as SetPagesLoading:
        state.isLoading = action.isLoading;
    case let action as SetPages:
        state.pages = action.payload
    case let action as SetPagesLoaded:
        state.loaded = action.loaded
    default:
        break
    }
    
    return state
}

struct MobileAppPagesResponse: Decodable {
    var results: [MobileAppPage]
}

struct MobileAppPage: Hashable {
    public var id: String
    public var name: String
    public var platform: String
    public var viewHierarchy: RowndScreen
    public var appId: String
    public var createdAt: String
    public var createdBy: String
    public var rules: [MobileAppPageRuleUnknown]?
}

extension MobileAppPage: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, platform
        case viewHierarchy = "view_hierarchy"
        case appId = "app_id"
        case createdAt = "created_at"
        case createdBy = "created_by"
    }
}

protocol MobileAppPageRuleProto {}

public enum MobileAppPageRuleUnknown: MobileAppPageRuleProto {
    case or(MobileAppPageOrRule)
    case rule(MobileAppPageRule)
    case and(MobileAppPageAndRule)
    case unknown
}

extension MobileAppPageRuleUnknown: Hashable, Codable {
    enum CodingKeys: CodingKey {
        case or, rule, and
    }

    public init(from decoder: Decoder) throws {
        if let r = try? MobileAppPageOrRule(from: decoder) {
            self = .or(r)
        } else if let r = try? MobileAppPageAndRule(from: decoder) {
            self = .and(r)
        } else if let r = try? MobileAppPageRule(from: decoder) {
            self = .rule(r)
        } else {
            self = .unknown
        }
    }
}

public struct MobileAppPageOrRule: MobileAppPageRuleProto, Hashable, Codable {
    public var or: [MobileAppPageRuleUnknown]

    enum CodingKeys: String, CodingKey {
        case or = "$or"
    }
}

public struct MobileAppPageAndRule: MobileAppPageRuleProto, Hashable, Codable {
    public var and: [MobileAppPageRuleUnknown]

    enum CodingKeys: String, CodingKey {
        case and = "$and"
    }
}

public struct MobileAppPageRule: MobileAppPageRuleProto, Hashable, Codable {
    public var value: AnyCodable?
    public var _operator: String?
    public var operand: String?

    enum CodingKeys: String, CodingKey {
        case value, operand
        case _operator = "operator"
    }
}

class PagesData {
    static func requestPagesData() -> Thunk<RowndState> {
        return Thunk<RowndState> { dispatch, getState in
            guard let state = getState() else { return }
            guard let appId = state.appConfig.id else { return }
            
            if !state.pages.isLoading {
                Task { @MainActor in
                    dispatch(SetPagesLoading(isLoading: true))
                }

                Task {
                    defer {
                        Task { @MainActor in
                            dispatch(SetPagesLoading(isLoading: false))
                        }
                    }
                    
                    let pages = await PagesData.fetch(appId: appId)

                    Task { @MainActor in
                        dispatch(SetPages(payload: pages ?? state.pages.pages))
                        dispatch(SetPagesLoaded(loaded: true)) // TODO: will this still work loading state from disk?
                    }
                }
            }
        }
    }
    
    static func fetch(appId: String) async -> Dictionary<String, MobileAppPage>? {
        do {
            let response: MobileAppPagesResponse = try await Rownd.apiClient.send(Get.Request(url: URL(string: "/applications/\(appId)/automations/mobile/pages")!, method: "get")).value

            let dictionary = response.results.reduce(into: [:]) { accumulator, page in
                accumulator[page.id] = page
            }
            
            return dictionary
        } catch {
            logger.error("Failed to fetch mobile app pages: \(String(describing: error))")
            return nil
        }
    }
}

