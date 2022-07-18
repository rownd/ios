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
    fileprivate func load(_ url: URL, method: String?, headers: Dictionary<String, String>?, body: Data?, withCompletion completion: @escaping (ModelType?) -> Void) {
        var request = URLRequest(url: url)
        request.allHTTPHeaderFields = headers ?? [:]
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 10 // seconds
        
        if let body = body {
            logger.trace("API request body: \(String(decoding: body, as: UTF8.self))")
        }
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] (data, resp, error) -> Void in
            guard error == nil else {
                logger.error("Network request failed: \(String(describing: error))")
                return
            }
            
            let response = resp as! HTTPURLResponse
            guard (200...299).contains(response.statusCode) else {
                logger.error("API call failed (\(response.statusCode)): \(String(decoding: data ?? Data(), as: UTF8.self))")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard let data = data, let value = self?.decode(data) else {
                logger.debug("Decoding API response failed: \(String(decoding: data ?? Data(), as: UTF8.self)))")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            logger.trace("Successful API response: \(String(decoding: data, as: UTF8.self))")
            DispatchQueue.main.async { completion(value) }
        }
        task.resume()
    }
}

class APIRequest<Resource: APIResource> {
    let resource: Resource
    
    init(resource: Resource) {
        self.resource = resource
        print("decoding fn:", self.decode)
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
            logger.error("Failed to decode API response: \(String(describing: error))")
            return nil
        }
    }
    
    func execute(withCompletion completion: @escaping (Resource.ModelType?) -> Void) {
        load(resource.url, method: "GET", headers: resource.combinedHeaders, body: nil, withCompletion: completion)
    }
    
    func execute(method: String?, body: Data?, withCompletion completion: @escaping (Resource.ModelType?) -> Void) {
        load(resource.url, method: method, headers: resource.combinedHeaders, body: body, withCompletion: completion)
    }
}
