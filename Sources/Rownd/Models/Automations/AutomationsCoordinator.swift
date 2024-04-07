//
//  AutomationsCoordinator.swift
//  Rownd
//
//  Created by Michael Murray on 5/22/23.
//

import Foundation
import ReSwift
import Kronos
import AnyCodable

public struct AutomationStoreState {
    var user: UserState
    var automations: [RowndAutomation]?
    var auth: AuthState
    var passkeys: PasskeyState
}

func computeLastRunId(_ automation: RowndAutomation) -> String {
    let lastRunId = "automation_\(automation.id)_last_run"
    logger.log("Last run id: \(lastRunId)")
    return lastRunId
}

func computeLastRunTimestamp(automation: RowndAutomation, meta: Dictionary<String, AnyCodable>?) -> Date? {
    let lastRunId = computeLastRunId(automation)
    if let lastRunDate = meta?[lastRunId] {
        logger.log("Last run date: \(lastRunDate)")
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = dateFormatter.date(from: "\(lastRunDate)")
        return date
    }
    return nil
}

public class AutomationsCoordinator: NSObject, StoreSubscriber {
    private var state: AutomationStoreState?
    public typealias StoreSubscriberStateType = AutomationStoreState
    let debouncer = Debouncer(delay: 0.5) // 500ms
    
    override init() {
        super.init()
        Context.currentContext.store.subscribe(self) {
            $0.select{
                AutomationStoreState(user: $0.user, automations: $0.appConfig.config?.automations, auth: $0.auth, passkeys: $0.passkeys)
            }
        }
    }
    
    public func newState(state: AutomationStoreState) {
        self.state = state
        self.processAutomations()
    }
    
    deinit {
        Context.currentContext.store.unsubscribe(self)
    }

    private func processAutomations(_ state: AutomationStoreState) {
        guard let automations = state.automations else {
            return
        }
    
        for automation in automations {
            processAutomation(automation: automation, state: state)
        }
    }

    public func processAutomations() {
        debouncer.debounce(action: processAutomationsNow)
    }
    
    private func processAutomationsNow() {
        guard let state = self.state else {
            return
        }
        self.processAutomations(state)
    }
    
    public func processAutomation(automation: RowndAutomation, state: AutomationStoreState) {
        logger.log("Processing automation: \(automation.name) (\(automation.id))")
        if automation.platform != .ios {
            logger.log("Automation is not an iOS automation")
            return
        }

        if (automation.state != RowndAutomationState.enabled) {
            logger.log("Automation is disabled: \(automation.name)")
            return
        }
        
        let willAutomationRun = shouldAutomationRun(automation: automation, state: state)
        
        if (!willAutomationRun) {
            logger.log("Automation does not need to run: \(automation.name)")
            return
        }
        
        automation.actions.forEach { (action) in
            invokeAction(type: action.type, args: action.args, automation: automation)
        }
       
    }
    
    public func invokeAction(type: RowndAutomationActionType, args: Dictionary<String, AnyCodable>?, automation: RowndAutomation) {
        guard let actionFn = AutomationActors[type] else {
            logger.log("Automation action function not found for action type \(type.rawValue)")
            return
        }
        
        actionFn(args)
        
        // Save automatino action in meta data
        let lastRunId = computeLastRunId(automation)
        Task { @MainActor in
            let date = Clock.now ?? Date()
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let dateString = AnyCodable(dateFormatter.string(from: date))
            Context.currentContext.store.state.user.setMetaData(field: lastRunId, value: dateString)
        }
    }
    
    public func determineAutomationMetaData(_ state: AutomationStoreState) -> Dictionary<String, AnyCodable> {
        var automationMeta = state.user.meta ?? [:]

        var hasPasskeys = false
        if let passkeyCount = state.passkeys.registration?.count {
            hasPasskeys = passkeyCount > 0
        }
        
        let additionalAutomationMeta: Dictionary<String, AnyCodable> = [
            "is_authenticated": AnyCodable(state.auth.isAccessTokenValid),
            "is_verified": AnyCodable(state.auth.isVerifiedUser ?? false),
            "are_passkeys_initialized": AnyCodable(state.passkeys.isInitialized),
            "has_prompted_for_passkey": AnyCodable(state.user.meta?["last_passkey_registration_prompt"] != nil),
            "has_passkeys": AnyCodable(hasPasskeys)
        ]
        
        additionalAutomationMeta.forEach{ (k,v) in automationMeta[k] = v }
        
        logger.log("Meta data: \(automationMeta)")
        
        return automationMeta
    }
    
    private func processRule(rule: RowndAutomationRuleUnknown, metaData: Dictionary<String, AnyCodable>?) -> Bool {
        switch rule {
        case .rule(let _rule):
            switch _rule.entityType {
            case .metadata, .userData:
                let userData = _rule.entityType == RowndAutomationRuleEntityRule.metadata ? metaData : state?.user.data
                return evaluateRule(userData: userData, rule: _rule)
            }
        case .or(let _rule):
            return processRuleSet(rules: _rule.or, op: .or, metaData: metaData)
        case .unknown:
            logger.warning("Unknown automation rule skipped")
            return false
        }
    }

    private enum RuleSetEvalOperator {
        case and, or
    }

    private func processRuleSet(rules: [RowndAutomationRuleUnknown], op: RuleSetEvalOperator = .and, metaData: Dictionary<String, AnyCodable>?) -> Bool {
        switch op {
        case .and:
            return rules.allSatisfy { rule in processRule(rule: rule, metaData: metaData) }
        case .or:
            return rules.first { rule in processRule(rule: rule, metaData: metaData) } != nil
        }
    }
    
    public func shouldAutomationRun(automation: RowndAutomation, state: AutomationStoreState) -> Bool {
        let automationMetaData = determineAutomationMetaData(state)
        let ruleResult = processRuleSet(rules: automation.rules, op: .and, metaData: automationMetaData)
        
        var triggerResult = true
        if let timeTrigger = automation.triggers.first(where: { $0.type == RowndAutomationTriggerType.time }) {
            let lastRunTimestamp = computeLastRunTimestamp(automation: automation, meta: state.user.meta)
            triggerResult = shouldTrigger(trigger: timeTrigger, lastRunTimestamp: lastRunTimestamp)
            
            let finalResult = ruleResult && triggerResult
            
            return finalResult
        }
        
        return false // Currently only working with time triggers
    }
    
    public func shouldTrigger(trigger: RowndAutomationTrigger, lastRunTimestamp: Date?) -> Bool {
        switch trigger.type {
            case RowndAutomationTriggerType.time:
                guard let lastRunTimestamp = lastRunTimestamp else {
                    return true
                }
            
                guard let triggerFrequency = stringToSeconds(trigger.value) else {
                    return false
                }
            
                let dateOfNextPrompt = lastRunTimestamp.addingTimeInterval(Double(triggerFrequency))
                let currentDate = Clock.now ?? Date()
                return currentDate > dateOfNextPrompt
            default:
                return false
        }
    }
}
