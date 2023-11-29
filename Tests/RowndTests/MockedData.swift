//
//  MockedData.swift
//  RowndTests
//
//  Created by Matt Hamann on 9/21/22.
//

import Foundation

public final class MockedData {
//    public static let botAvatarImageResponseHead: Data = try! Data(contentsOf: Bundle(for: MockedData.self).url(forResource: "Resources/Responses/bot-avatar-image-head", withExtension: "data")!)
//    public static let botAvatarImageFileUrl: URL = Bundle(for: MockedData.self).url(forResource: "wetransfer_bot_avater", withExtension: "png")!
//    public static let refreshTokenResponse: URL = Bundle.module.url(forResource: "auth_refresh_response", withExtension: "json")!
}

extension Bundle {
#if !SWIFT_PACKAGE
    static let module = Bundle(for: MockedData.self)
#endif
}

internal extension URL {
    /// Returns a `Data` representation of the current `URL`. Force unwrapping as it's only used for tests.
    var data: Data {
        return try! Data(contentsOf: self)
    }
}
