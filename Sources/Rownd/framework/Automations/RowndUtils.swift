//
//  File.swift
//  
//
//  Created by Bobby Radford on 1/29/24.
//

import Foundation
import SwiftUI
import AnyCodable

internal class RowndUtils {
    static func rownd_debug(obj: AnyObject) -> Void {
        let mirror = Mirror(reflecting: obj)
        
        print("Type: \(mirror.subjectType)")

        for child in mirror.children {
            print("Field: \(child.label ?? "") Value: \(child.value)")
            
//            if child.label == "attachmentsStorage" {
//                rownd_debug(obj: (child.value as! [AnyObject]).first!)
////                let attachmentsStorageMirror = Mirror(reflecting: (child.value as! [Any]).first!)
////                for attachmentsStorageMirrorChild in attachmentsStorageMirror.children {
////                    print("Field: \(attachmentsStorageMirrorChild.label ?? "") Value: \(attachmentsStorageMirrorChild.value)")
////                }
//            }
//            
//            if child.label == "cachedCombinedAttachment" {
//                rownd_debug(obj: child.value as AnyObject)
//            }
//            
//            if child.label == "properties" {
//                rownd_debug(obj: child.value as AnyObject)
//            }
        }
    }
    
    static func printMethods(of aClass: AnyClass) {
        var methodCount: UInt32 = 0
        let methods: UnsafeMutablePointer<Method>? = class_copyMethodList(aClass, &methodCount)
        
        guard let methods = methods else {
            return
        }
        
        for i in 0 ..< Int(methodCount) {
            let method: Method = methods[i]
            print(String(cString: sel_getName(method_getName(method))))
        }
        
        free(methods)
    }
    
    static func textContainers(in view: UIView) {
        print(view.value(forKey: "textFromSwiftUIView") ?? "unknown")

        for subview in view.subviews {
            textContainers(in: subview)
        }
    }
    
    static func stringifyJsonAny(_ any: JsonAny?) -> String {
        var string = ""
        
        guard let any = any else {
            return ""
        }
        
        if let dataString = any as? String {
            string = dataString
        }
        else if JSONSerialization.isValidJSONObject(any) {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: any)
                string = String(decoding: jsonData, as: UTF8.self)
            } catch {
                autoLogger.warning("Unable to convert AnyCodable to json string")
            }
        }
        
        return string
    }

    static func stringifyAnyCodable(_ any: AnyCodable?) -> String {
        var string = ""
        
        guard let any = any else {
            return ""
        }
        
        if let any = any.isString() {
            string = any
        }
        else {
            do {
                string = try any.asJsonString()
            } catch {
                autoLogger.warning("Unable to convert AnyCodable to json string")
            }
        }

        
        return string
    }
}


func computeLastRunId(_ automation: RowndAutomation, trigger: RowndAutomationTrigger?) -> String {
    var lastRunId = "automation_\(automation.id)_last_run"
    
    if (trigger != nil && trigger?.type == RowndAutomationTriggerType.timeOnce) {
        lastRunId = lastRunId + "_\(RowndAutomationTriggerType.timeOnce.rawValue.lowercased())"
    }
    
    autoLogger.log("Last run id: \(lastRunId)")
    return lastRunId
}

func computeLastRunTimestamp(automation: RowndAutomation, meta: Dictionary<String, AnyCodable>, trigger: RowndAutomationTrigger?) -> DateOrString? {
    
    let lastRunId = computeLastRunId(automation, trigger: trigger)
    if let lastRunDate = meta[lastRunId] {
        autoLogger.log("Last run date: \(lastRunDate)")
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: "\(lastRunDate)") {
            return date
        }
        return String(describing: lastRunDate) // Return string if date wasn't found
    }
    return nil
}
