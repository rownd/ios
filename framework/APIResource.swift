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
    var headers: Dictionary<String, String> { get set }
}

extension APIResource {
    var url: URL {
        var components = URLComponents(string: Rownd.config.apiUrl)!
        components.path = methodPath
        components.queryItems = []
        return components.url!
    }
    
    // Default implementation so implementers can provide extra headers or not
    var headers: Dictionary<String, String> {
        get { return [:] }
        set {}
    }
    
    var combinedHeaders: Dictionary<String, String> {
        
        return headers.merging([
            "X-Rownd-App-Key": Rownd.config.appKey
        ]) { (current, _) in current }
    }
}
