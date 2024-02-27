//
//  RowndTreeSerialization.swift
//
//
//  Created by Bobby Radford on 1/26/24.
//

import Foundation
import AnyCodable
import SwiftUI

struct RowndScreen: Codable {
    var retroactiveScreenData: RowndRetroScreenData
    var tree: [UIViewMetadata]
}

struct RowndRetroScreenData: Codable {
    var swiftUIIdentifier: String?
    var texts: [String]
    var retroactiveScreenId: String
    var name: String
}

internal class RowndTreeSerialization {
    static func serializeTree() async -> RowndScreen? {
        let task = Task { @MainActor () -> RowndScreen? in
            do {
                let rootView = try await RowndDeviceUtils.mainWindow()
                guard let rootView = rootView else {
                    return nil
                }
                var texts: [String] = []
                RowndAutoHelper.extractTextsFrom(rootView, into: &texts)
                
                let retroScreenData = RowndRetroScreenData(
                    swiftUIIdentifier: "todo",
                    texts: texts,
                    retroactiveScreenId: "todo",
                    name: "todo"
                )
                
                let tree = tree(from: rootView)
                
                return RowndScreen(retroactiveScreenData: retroScreenData, tree: tree)
            } catch {
                logger.error("Failed to serialize view tree: \(String(describing: error))")
                return nil
            }
        }
        return await task.value
    }
    
    static func tree(from: UIView) -> [UIViewMetadata] {
        var tree = [UIViewMetadata]()
        
        from.traverseHierarchy { responder, level in
            if let view = responder as? UIView {
                tree.append(view.rownd_metadata)
            }
        }
        
        return tree
    }
}
