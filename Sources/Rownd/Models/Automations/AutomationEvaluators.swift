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
    
    logger.log("Rule (Attribute, attribute value, rule value, and result): \(rule.attribute), \(userDataValue), \(rule.value ?? "N/A"), \(result)")

    return result
}

func conditionEvaluatorsEquals(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    logger.log("Condition: EQUALS")
    guard let dataValue = data[attribute], let attributeValue = value else {
        return false
    }
    
    return "\(dataValue)" == "\(attributeValue)"
}

func conditionEvaluatorsNotEquals(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    logger.log("Condition: NOT_EQUALS")
    guard let dataValue = data[attribute], let attributeValue = value else {
        return false
    }
    return "\(dataValue)" != "\(attributeValue)"
}

func conditionEvaluatorsContains(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    logger.log("Condition: CONTAINS")
    guard let dataValue = data[attribute] else {
        return false
    }
    return "\(dataValue)".contains(String(describing: value))
}

func conditionEvaluatorsNotContains(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    logger.log("Condition: NOT_CONTAINS")
    guard let dataValue = data[attribute] else {
        return false
    }
    return !"\(dataValue)".contains(String(describing: value))
}

func conditionEvaluatorsIn(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    logger.log("Condition: IN")
    guard let dataValue = data[attribute] else {
        return false
    }
    return String(describing: value).contains("\(dataValue)")
}

func conditionEvaluatorsNotIn(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    logger.log("Condition: NOT_IN")
    guard let dataValue = data[attribute] else {
        return false
    }
    return !String(describing: value).contains("\(dataValue)")
}

func conditionEvaluatorsExists(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    logger.log("Condition: EXISTS")
    return data[attribute] != nil
}

func conditionEvaluatorsNotExists(data: Dictionary<String, AnyCodable>, attribute: String, value: AnyCodable?) -> Bool {
    logger.log("Condition: NOT_EXISTS")
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
