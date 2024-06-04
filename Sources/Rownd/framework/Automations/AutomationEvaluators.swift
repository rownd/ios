//
//  AutomationEvaluators.swift
//  Rownd
//
//  Created by Michael Murray on 5/23/23.
//

import Foundation
import AnyCodable

internal func evaluateRule(userData: Dictionary<String, AnyCodable>, rule: RowndAutomationRule) -> Bool {
    guard let userDataValue = userData[rule.attribute] else {
        logger.log("Attribute not found: \(rule.attribute)")
        return false
    }

    let conditionEvalFun = conditionEvaluators[rule.condition]
    let result = conditionEvalFun?(userData, rule.attribute, rule.value) ?? false
    
    autoLogger.log("Rule (Attribute, attribute value, rule value, and result): \(rule.attribute), \(userDataValue), \(rule.value ?? "N/A"), \(result)")

    return result
}

/// TODO: This needs dramatic updates in the future. For now, we are only evaluating
/// a page scope based on matching texts found in teh view hierarchy. Eventually, pages should
/// contain a rule set property that declares how they should be identified. For instance, a page could
/// have a ruleset that says, "one specific text must be found" or "my `swiftUIIdentiifier` value
/// AND some specific text must both be foundn on the current page".
internal func evaluateScopeRule(rule: RowndAutomationRule, page: MobileAppPage?) async -> Bool {
    return false
//    let currentPage = await RowndTreeSerialization.serializeTree()
//    guard let currentPage = currentPage else {
//        return false
//    }
//    
//    guard let expectedTexts = page?.viewHierarchy.retroactiveScreenData.texts else {
//        return false
//    }
//    
//    return currentPage.retroactiveScreenData.texts.elementsEqual(expectedTexts)
}

func conditionEvaluatorsEquals(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    autoLogger.log("Condition: EQUALS")
    guard let dataValue = data[attribute], let attributeValue = value else {
        return false
    }
    
    return "\(dataValue)" == "\(attributeValue)"
}

func conditionEvaluatorsNotEquals(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    autoLogger.log("Condition: NOT_EQUALS")
    guard let dataValue = data[attribute], let attributeValue = value else {
        return false
    }
    return "\(dataValue)" != "\(attributeValue)"
}

func conditionEvaluatorsContains(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    autoLogger.log("Condition: CONTAINS")
    guard let dataValue = data[attribute] else {
        return false
    }
    return "\(dataValue)".contains(String(describing: value))
}

func conditionEvaluatorsNotContains(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    autoLogger.log("Condition: NOT_CONTAINS")
    guard let dataValue = data[attribute] else {
        return false
    }
    return !"\(dataValue)".contains(String(describing: value))
}

func conditionEvaluatorsIn(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    autoLogger.log("Condition: IN")
    guard let dataValue = data[attribute] else {
        return false
    }
    return String(describing: value).contains("\(dataValue)")
}

func conditionEvaluatorsNotIn(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    autoLogger.log("Condition: NOT_IN")
    guard let dataValue = data[attribute] else {
        return false
    }
    return !String(describing: value).contains("\(dataValue)")
}

func conditionEvaluatorsExists(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    autoLogger.log("Condition: EXISTS")
    return data[attribute] != nil
}

func conditionEvaluatorsNotExists(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    autoLogger.log("Condition: NOT_EXISTS")
    return data[attribute] == nil
}

let conditionEvaluators: [RowndAutomationRuleCondition: ( Dictionary<String, AnyCodable>, String, AnyCodable? ) -> Bool] = [
    RowndAutomationRuleCondition.equals: conditionEvaluatorsEquals,
    RowndAutomationRuleCondition.notEquals: conditionEvaluatorsNotEquals,
    RowndAutomationRuleCondition.contains: conditionEvaluatorsContains,
    RowndAutomationRuleCondition.notContains: conditionEvaluatorsNotContains,
    RowndAutomationRuleCondition.isIn: conditionEvaluatorsIn,
    RowndAutomationRuleCondition.isNotIn: conditionEvaluatorsNotIn,
    RowndAutomationRuleCondition.exists: conditionEvaluatorsExists,
    RowndAutomationRuleCondition.notExists: conditionEvaluatorsNotExists
]
