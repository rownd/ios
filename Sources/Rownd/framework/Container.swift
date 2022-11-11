//
//  DepContainer.swift
//  RowndTests
//
//  Created by Matt Hamann on 11/10/22.
//

import Foundation
import Factory
import Get

extension Container {
    static let tokenApi = Factory<APIClient> { tokenApiFactory() }
}
