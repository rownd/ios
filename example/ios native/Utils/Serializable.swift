//
//  Serializable.swift
//  rownd_ios_example
//
//  Created by Matt Hamann on 3/25/24.
//

import Foundation

public protocol Serializable: Codable, Hashable {
    init?(dictionary: [String: Any])
    init?(jsonString: String)
    func serialize() -> Data?
    func serializeToDictionary() -> [String: Any]?
}

extension Serializable {
    public init?(dictionary: [String: Any]) {
        guard let theJSONData = try? JSONSerialization.data(withJSONObject: dictionary, options: []),
              let theJSONText = String(data: theJSONData, encoding: .utf8),
              let data = theJSONText.data(using: .utf8)
        else {
            return nil
        }

        self.init(data: data)
    }

    public init?(jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        self.init(data: data)
    }

    public init?(data: Data) {
        do {
            self = try JSONDecoder().decode(Self.self, from: data)
        } catch {
            debugPrint(error)
            return nil
        }
    }

    public func serialize() -> Data? {
        do {
            return try JSONEncoder().encode(self)
        } catch {
            return nil
        }
    }

    public func serializeToDictionary() -> [String: Any]? {
        guard let serialize = self.serialize(),
              let JSON = (try? JSONSerialization.jsonObject(with: serialize, options: []))
                as? [String: AnyObject]
        else {
            return nil
        }
        return JSON
    }
}
