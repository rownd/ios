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

internal let CompletedAutomationMetaData = "complete"

public struct AutomationStoreState {
    var user: UserState
    var automations: [RowndAutomation]?
    var pages: Dictionary<String, MobileAppPage>
    var auth: AuthState
    var passkeys: PasskeyState
}

public class AutomationsCoordinator: NSObject, StoreSubscriber {
    private var state: AutomationStoreState?
    public typealias StoreSubscriberStateType = AutomationStoreState
    let debouncer = Debouncer(delay: 0.5) // 500ms
    let counter = Counter()
    
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

        // Save automation action in meta data
        let lastRunId = computeLastRunId(automation, trigger: nil)
        let onceTimeTrigger = automation.triggers.first(where: { $0.type == .timeOnce })
        Task { @MainActor in
            let dateString = currentDateString()
            var meta = state?.user.meta ?? [:]
            meta[lastRunId] = dateString
            if (onceTimeTrigger != nil) {
                meta[computeLastRunId(automation, trigger: onceTimeTrigger)] = AnyCodable(CompletedAutomationMetaData)
            }
            store.state.user.setMetaData(meta)
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
            "has_passkeys": AnyCodable(hasPasskeys),
            "app_duration": AnyCodable(counter.getCount())
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
        
        if (!ruleResult) {
            return false
        }
        
        var triggerResult = processTriggers(automation, state: state)
        
        return triggerResult
    }
    
    public func processTriggers(_ automation: RowndAutomation, state: AutomationStoreState) -> Bool {
        return automation.triggers.contains {
            let trigger = $0
            return processTrigger(automation, trigger: trigger, state: state)
        }
    }
    
    public func processTrigger(_ automation: RowndAutomation, trigger: RowndAutomationTrigger, state: AutomationStoreState) -> Bool {
        let lastRunTimestamp = computeLastRunTimestamp(automation: automation, meta: state.user.meta, trigger: trigger)
        switch trigger.type {
        case .time:
            
            let onceTimeTrigger = automation.triggers.first(where: { $0.type == .timeOnce })
            let lastRunTimestampOnceTrigger = computeLastRunTimestamp(automation: automation, meta: state.user.meta, trigger: onceTimeTrigger)
            if let lastRunTimestampOnceTrigger = lastRunTimestampOnceTrigger as? String {
                // Prevent time trigger if TIME_ONCE hasn't completed yet
                if (lastRunTimestampOnceTrigger != CompletedAutomationMetaData) {
                    return false
                }
            }
            
            guard let triggerFrequency = stringToSeconds(trigger.value) else {
                return false
            }
            
            guard let lastRunTimestamp = lastRunTimestamp as? Date else {
                return false
            }
        
            let dateOfNextPrompt = lastRunTimestamp.addingTimeInterval(Double(triggerFrequency))
            let currentDate = currentDate()
            return currentDate > dateOfNextPrompt
        case .timeOnce:
            guard let lastRunTimestamp = lastRunTimestamp else {
                // Set the intial time if timestamp has not been set
                setAutomationTime(automation, trigger: trigger)
                return false
            }
            
            if let lastRunTimestamp = lastRunTimestamp as? String {
                if (lastRunTimestamp == CompletedAutomationMetaData) {
                    return false
                }
            }
            
            guard let triggerFrequency = stringToSeconds(trigger.value) else {
                return false
            }
            
            guard let lastRunTimestamp = lastRunTimestamp as? Date else {
                return false
            }
            
            let dateOfNextPrompt = lastRunTimestamp.addingTimeInterval(Double(triggerFrequency))
            let currentDate = currentDate()
            return currentDate > dateOfNextPrompt
        case .mobileEvent:
            /// For now, always accept  `MOBILE_EVENT` `"page_visit"` triggers
            return trigger.value == "page_visit"
        default:
            return false
        }
    }
    
    internal func setAutomationTime(_ automation: RowndAutomation, trigger: RowndAutomationTrigger?) {
        let lastRunId = computeLastRunId(automation, trigger: trigger)
        store.state.user.setMetaData(field: lastRunId, value: currentDateString())
    }
}
