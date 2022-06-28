//
//  APIClient.swift
//  framework
//
//  Created by Matt Hamann on 6/23/22.
//

import Foundation

protocol NetworkRequest: AnyObject {
    associatedtype ModelType
    func decode(_ data: Data) -> ModelType?
    func execute(withCompletion completion: @escaping (ModelType?) -> Void)
}

extension NetworkRequest {
    fileprivate func load(_ url: URL, headers: Dictionary<String, String>?, withCompletion completion: @escaping (ModelType?) -> Void) {
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers ?? [:]
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, _ , _) -> Void in
            guard let data = data, let value = self?.decode(data) else {
                print(String(decoding: data ?? Data(), as: UTF8.self))
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async { completion(value) }
        }
        task.resume()
    }
}

class APIRequest<Resource: APIResource> {
    let resource: Resource
    
    init(resource: Resource) {
        self.resource = resource
        print(self.decode)
    }
}
 
extension APIRequest: NetworkRequest {
    func decode(_ data: Data) -> Resource.ModelType? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let model = try decoder.decode(Resource.ModelType.self, from: data)
            return model
        } catch {
            logger.error("Failed to decode API response:")
            print(error)
            return nil
        }
    }
    
    func execute(withCompletion completion: @escaping (Resource.ModelType?) -> Void) {
        load(resource.url, headers: resource.combinedHeaders, withCompletion: completion)
    }
}
