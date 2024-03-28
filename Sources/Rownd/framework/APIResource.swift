//
//  APIResource.swift
//  framework
//
//  Created by Matt Hamann on 6/24/22.
//

import Foundation

protocol APIResource {
    associatedtype ModelType: Decodable
    var methodPath: String { get }
    var headers: Dictionary<String, String>? { get set }
}

extension APIResource {
    var url: URL {
        var components: URLComponents

        if methodPath.starts(with: "http") {
            components = URLComponents(string: methodPath)!
        } else {
            components = URLComponents(string: Rownd.config.apiUrl)!
            components.path = methodPath
        }

        components.queryItems = []
        return components.url!
    }
    
    var combinedHeaders: Dictionary<String, String> {
        var localHeaders = Dictionary<String, String>()
        if let _resourceHeaders = headers {
            localHeaders = _resourceHeaders
        }

        return localHeaders.merging([
            "X-Rownd-App-Key": Rownd.config.appKey,
            "User-Agent": Constants.DEFAULT_API_USER_AGENT
        ]) { (current, _) in current }
    }
}
