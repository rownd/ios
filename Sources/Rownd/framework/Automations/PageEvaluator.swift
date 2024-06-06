//
//  File.swift
//  
//
//  Created by Michael Murray on 3/29/24.
//

import Foundation
import AnyCodable

/// TODO: This needs dramatic updates in the future. For now, we are only evaluating
/// a page scope based on matching texts found in teh view hierarchy. Eventually, pages should
/// contain a rule set property that declares how they should be identified. For instance, a page could
/// have a ruleset that says, "one specific text must be found" or "my `swiftUIIdentiifier` value
/// AND some specific text must both be foundn on the current page".
internal func evaluateScopeRule(rule: RowndAutomationRule, page: MobileAppPage?) async -> Bool {
    guard let captures = page?.captures else {
        return false
    }
    
    guard let capture = determineCapture(page) else {
        autoLogger.log("Cannot determine the page capture")
        return false
    }
    
    let currentScreen = await RowndTreeSerialization.serializeTree()
    guard let currentScreen = currentScreen else {
        autoLogger.log("Rownd Screen is missing.")
        return false
    }
    
    let jsonPath = capture.ruleSet.jsonPath
    
    let result = evaluatePageRule(rule: jsonPath, screen: currentScreen)
    
    autoLogger.log("Scope result: \(result). JsonPath: \(jsonPath)")
    
    return result
}

internal func determineCapture(_ page: MobileAppPage?) -> MobileAppPageCapture? {
    guard let captures = page?.captures else {
        return nil
    }
    
    guard let releaseVersion = getReleaseVersionNumber() else {
        return nil
    }
    
    guard let releaseVersionNumber = Double(releaseVersion) else {
        return nil
    }
    
    var selectedCapture: MobileAppPageCapture? = nil
    for capture in captures {
        if (capture.platform != "ios" ) {
            continue
        }
        
        guard let appVersion = Double(capture.capturedOnAppVersion) else {
            continue
        }
        
        // Don't use a capture version that is greater than the current build version
        if (appVersion > releaseVersionNumber) {
            continue
        }
        
        guard let newCapture = selectedCapture else {
            selectedCapture = capture
            continue
        }
        
        guard let newAppVersion = Double(newCapture.capturedOnAppVersion) else {
            continue
        }
        
        // Use the closest version possible to the current build version
        if (newAppVersion > appVersion) {
            selectedCapture = capture
        }
        
    }
    
    return selectedCapture
}

internal func evaluatePageRules(screen: RowndScreen, rules: [MobileAppPageRuleUnknown]) -> Bool {
    let result = rules.allSatisfy { rule in evaluatePageRule(rule: rule, screen: screen) }
    return result
}

internal func evaluatePageRule(rule: MobileAppPageRuleUnknown, screen: RowndScreen) -> Bool {
    switch rule {
    case .unknown:
        autoLogger.log("UNKNOWN RULE")
        return false
    case .or(let _rule):
        return evaluatePageRule(rule: _rule, screen: screen)
    case .and(let _rule):
        return evaluatePageRule(rule: _rule, screen: screen)
    case .rule(let _rule):
        return evaluatePageRule(rule: _rule, screen: screen)
    }
}


internal func evaluatePageRule(rule: MobileAppPageRule, screen: RowndScreen) -> Bool {
    autoLogger.log("PAGE RULE \(rule)")
    guard let operand = rule.operand else {
        return false
    }
    
    guard let operation = rule.operation else {
        autoLogger.log("Operation is missing)")
        return false
    }
    
    if (operation == MobileAppPageRuleOperation.unknown) {
        autoLogger.log("Operation type is unknown")
        return false
    }
    
    let value = rule.value
    
    do {
        let jsonData = try JSONEncoder().encode(screen)
        let query = jsonData.query(values: operand)?.first
        guard let pageOperationsFunc = pageOperations[operation] else {
            return false
        }
        let result = pageOperationsFunc(query, value)
        return result
    } catch {
        autoLogger.log("Error encoding RowndScreen \(rule)")
    }
    
    return false
}

internal func evaluatePageRule(rule: MobileAppPageAndRule, screen: RowndScreen) -> Bool {
    let rules = rule.and
    autoLogger.log("AND PAGE RULES \(rules)")
    return evaluatePageRules(screen: screen, rules: rules)
}

internal func evaluatePageRule(rule: MobileAppPageOrRule, screen: RowndScreen) -> Bool {
    let rules = rule.or
    autoLogger.log("OR PAGE RULE \(rules)")
    return rule.or.contains { rule in evaluatePageRule(rule: rule, screen: screen) }
}


let pageOperations: [MobileAppPageRuleOperation: ( JsonAny?, AnyCodable? ) -> Bool] = [
    MobileAppPageRuleOperation.equals: pageOperationsEvalEquals,
    MobileAppPageRuleOperation.notEquals: pageOperationsEvalNotEquals,
    MobileAppPageRuleOperation.exists: pageOperationsEvalExists,
    MobileAppPageRuleOperation.notExists: pageOperationsEvalNotExists,
    MobileAppPageRuleOperation.contains: pageOperationsEvalContains,
    MobileAppPageRuleOperation.notContains: pageOperationsEvalNotContains
]

// Need to handle different types arrays, strings, and numbers
internal func pageOperationsEvalEquals(data: JsonAny?, value: AnyCodable?) -> Bool {
    let dataString = RowndUtils.stringifyJsonAny(data)
    let valueString = RowndUtils.stringifyAnyCodable(value)
    
    
    let isEqual = dataString == valueString
    return isEqual
}

internal func pageOperationsEvalNotEquals(data: JsonAny?, value: AnyCodable?) -> Bool {
    return !pageOperationsEvalEquals(data: data, value: value)
}

internal func pageOperationsEvalNotExists(data: JsonAny?, value: AnyCodable?) -> Bool {
    return data == nil
}

internal func pageOperationsEvalExists(data: JsonAny?, value: AnyCodable?) -> Bool {
    return !pageOperationsEvalNotExists(data: data, value: value)
}

internal func pageOperationsEvalContains(data: JsonAny?, value: AnyCodable?) -> Bool {
    let dataString = RowndUtils.stringifyJsonAny(data)
    let valueString = RowndUtils.stringifyAnyCodable(value)
    
    return dataString.contains(valueString)
}

internal func pageOperationsEvalNotContains(data: JsonAny?, value: AnyCodable?) -> Bool {
    return !pageOperationsEvalContains(data: data, value: value)
}

