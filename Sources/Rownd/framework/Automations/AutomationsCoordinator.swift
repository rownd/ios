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
    var pages: Dictionary<String, MobileAppPage>
    var auth: AuthState
    var passkeys: PasskeyState
}

func computeLastRunId(_ automation: RowndAutomation) -> String {
    let lastRunId = "automation_\(automation.id)_last_run"
    autoLogger.log("Last run id: \(lastRunId)")
    return lastRunId
}

func computeLastRunTimestamp(automation: RowndAutomation, meta: Dictionary<String, AnyCodable>) -> Date? {
    let lastRunId = computeLastRunId(automation)
    if let lastRunDate = meta[lastRunId] {
        autoLogger.log("Last run date: \(lastRunDate)")
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
        store.subscribe(self) {
            $0.select{
                AutomationStoreState(
                    user: $0.user,
                    automations: $0.appConfig.config?.automations,
                    pages: $0.pages.pages,
                    auth: $0.auth,
                    passkeys: $0.passkeys
                )
            }
        }
    }
    
    public func newState(state: AutomationStoreState) {
        self.state = state
        self.processAutomations()
    }
    
    deinit {
       store.unsubscribe(self)
    }

    private func processAutomations(_ state: AutomationStoreState) {
        guard let automations = state.automations else {
            return
        }
    
        for automation in automations {
            Task {
                await processAutomation(automation: automation, state: state)
            }
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
        
    public func processAutomation(automation: RowndAutomation, state: AutomationStoreState) async {
        autoLogger.log("Processing automation: \(automation.name) (\(automation.id))")
        if automation.platform != .ios {
            autoLogger.log("Automation is not an iOS automation")
            return
        }

        if (automation.state != RowndAutomationState.enabled) {
            autoLogger.log("Automation is disabled: \(automation.name) (\(automation.id))")
            return
        }
        
        let willAutomationRun = await shouldAutomationRun(automation: automation, state: state)
        
        if (!willAutomationRun) {
            autoLogger.log("Automation does not need to run: \(automation.name) (\(automation.id))")
            return
        }
        
        automation.actions.forEach { (action) in
            invokeAction(type: action.type, args: action.args, automation: automation)
        }
       
    }
    
    public func invokeAction(type: RowndAutomationActionType, args: Dictionary<String, AnyCodable>?, automation: RowndAutomation) {
        guard let actionFn = AutomationActors[type] else {
            autoLogger.log("Automation action function not found for action type \(type.rawValue)")
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
            store.state.user.setMetaData(field: lastRunId, value: dateString)
        }
    }
    
    public func determineAutomationMetaData(_ state: AutomationStoreState) -> Dictionary<String, AnyCodable> {
        var automationMeta = state.user.meta

        var hasPasskeys = false
        if let passkeyCount = state.passkeys.registration?.count {
            hasPasskeys = passkeyCount > 0
        }
        
        let additionalAutomationMeta: Dictionary<String, AnyCodable> = [
            "is_authenticated": AnyCodable(state.auth.isAccessTokenValid),
            "is_verified": AnyCodable(state.auth.isVerifiedUser ?? false),
            "are_passkeys_initialized": AnyCodable(state.passkeys.isInitialized),
            "has_prompted_for_passkey": AnyCodable(state.user.meta["last_passkey_registration_prompt"] != nil),
            "has_passkeys": AnyCodable(hasPasskeys)
        ]
        
        additionalAutomationMeta.forEach{ (k,v) in automationMeta[k] = v }
        
        autoLogger.log("Meta data: \(automationMeta)")
        
        return automationMeta
    }
    
    private func processRule(rule: RowndAutomationRuleUnknown, metaData: Dictionary<String, AnyCodable>?) async -> Bool {
        switch rule {
        case .rule(let _rule):
            switch _rule.entityType {
            case .metadata, .userData:
                let userData = _rule.entityType == RowndAutomationRuleEntityRule.metadata ? metaData : state?.user.data
                guard let userData = userData else {
                    autoLogger.warning("User data not available during automation rule evaluation")
                    return false
                }
                return evaluateRule(userData: userData, rule: _rule)
            case .scope:
                var page: MobileAppPage?
                if _rule.attribute == "mobile_page" {
                    guard let pageId = _rule.value else {
                        autoLogger.warning("Automation rule for mobile_page scope missing page ID value")
                        return false
                    }
                    guard let p = state?.pages["\(pageId)"] else {
                        autoLogger.warning("Automation rule references page ID that is unknown: \(pageId)")
                        return false
                    }
                    page = p
                }
                return await evaluateScopeRule(rule: _rule, page: page)
            }
        case .or(let _rule):
            return await processRuleSet(rules: _rule.or, op: .or, metaData: metaData)
        case .unknown:
            autoLogger.warning("Unknown automation rule skipped")
            return false
        }
    }

    private enum RuleSetEvalOperator {
        case and, or
    }

    private func processRuleSet(rules: [RowndAutomationRuleUnknown], op: RuleSetEvalOperator = .and, metaData: Dictionary<String, AnyCodable>?) async -> Bool {
        switch op {
        case .and:
            return await withTaskGroup(of: Bool.self) { group in
                do {
                    for rule in rules {
                        group.addTask {
                            await self.processRule(rule: rule, metaData: metaData)
                        }
                    }
                
                    var results = [Bool]()
                    for try await result in group {
                        results.append(result)
                    }

                    return results.allSatisfy { $0 }
                } catch {
                    return false
                }
            }
            
        case .or:
            return await withTaskGroup(of: Bool.self) { group in
                do {
                    for rule in rules {
                        group.addTask {
                            await self.processRule(rule: rule, metaData: metaData)
                        }
                    }
                
                    var results = [Bool]()
                    for try await result in group {
                        if result {
                            // Return true on the first true result
                            return true
                        }
                    }

                    return false
                } catch {
                    return false
                }
            }
        }
    }
    
    public func shouldAutomationRun(automation: RowndAutomation, state: AutomationStoreState) async -> Bool {
        let automationMetaData = determineAutomationMetaData(state)
        let ruleResult = await processRuleSet(rules: automation.rules, op: .and, metaData: automationMetaData)
        
        var triggerResult = true
        if let timeTrigger = automation.triggers.first(where: { $0.type == .time }) {
            let lastRunTimestamp = computeLastRunTimestamp(automation: automation, meta: state.user.meta)
            triggerResult = shouldTrigger(trigger: timeTrigger, lastRunTimestamp: lastRunTimestamp)
            
            let finalResult = ruleResult && triggerResult
            
            return finalResult
        }
        
        /// For now, always accept  `MOBILE_EVENT` `"page_visit"` triggers
        if let pageVisitTrigger = automation.triggers.first(where: { $0.type == .mobileEvent }) {
            let lastRunTimestamp = computeLastRunTimestamp(automation: automation, meta: state.user.meta)
            triggerResult = shouldTrigger(trigger: pageVisitTrigger, lastRunTimestamp: lastRunTimestamp)
            
            let finalResult = ruleResult && triggerResult
            
            return finalResult
        }
        
        return false // Currently only working with time triggers
    }
    
    public func shouldTrigger(trigger: RowndAutomationTrigger, lastRunTimestamp: Date?) -> Bool {
        switch trigger.type {
        case .time:
            guard let lastRunTimestamp = lastRunTimestamp else {
                return true
            }
        
            guard let triggerFrequency = stringToSeconds(trigger.value) else {
                return false
            }
        
            let dateOfNextPrompt = lastRunTimestamp.addingTimeInterval(Double(triggerFrequency))
            let currentDate = Clock.now ?? Date()
            return currentDate > dateOfNextPrompt
        case .mobileEvent:
            /// For now, always accept  `MOBILE_EVENT` `"page_visit"` triggers
            return trigger.value == "page_visit"
        default:
            return false
        }
    }
}
