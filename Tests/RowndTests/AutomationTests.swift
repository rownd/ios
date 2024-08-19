//
//  AutomationTests.swift
//  
//
//  Created by Michael Murray on 8/19/24.
//

import XCTest

@testable import Rownd

final class AutomationTests: XCTestCase {

    func testDecodingAppConfigAutomation() {
        do {
            let automationString = "{\"id\":\"cm010byrj007lcrws2mfnsesy\",\"state\":\"enabled\",\"platform\":\"web\",\"actions\":[{\"type\":\"REQUIRE_AUTHENTICATION\",\"args\":{\"prevent_closing\":true}}],\"template\":\"sign_in\",\"triggers\":[{\"type\":\"TIME\",\"value\":\"3h\"}],\"name\":\"Untitled automation\",\"rules\":[{\"$or\":[{\"value\":false,\"attribute\":\"is_authenticated\",\"condition\":\"EQUALS\",\"entity_type\":\"metadata\"},{\"value\":\"instant\",\"attribute\":\"auth_level\",\"condition\":\"EQUALS\",\"entity_type\":\"metadata\"}]}]}"
            let decoder = JSONDecoder()
            let automation = try decoder.decode(
                RowndAutomation.self,
                from: (automationString.data(using: .utf8) ?? Data())
            )
            
            let hasOrRule = automation.rules.contains { rule in
                if case .or(_) = rule {
                    return true
                } else {
                    return false
                }
            }
            
            XCTAssertTrue(hasOrRule, "Rule contains a valid Automation OR rule")
            XCTAssertTrue(automation.triggers.first?.type == RowndAutomationTriggerType.time, "TIME is the expected trigger type")
            
            do {
                let encoded = try automation.toDictionary()
            } catch {
                XCTFail("Failed to encode app config string \(error)")
            }
            
        } catch {
            XCTFail("Failed to decode app config string \(error)")
        }
        
    }
    
    
    func testDecodingAppConfigAutomation2() {
        do {
            let automationString = """
            {"rules":[{"entity_type":"metadata","attribute":"auth_level","condition":"EQUALS","value":"instant"}],"triggers":[{"type":"TIME","value":"3h"}],"actions":[{"type":"REQUIRE_AUTHENTICATION","args":{"prevent_closing":true}}],"id":"cm01d98qv008wcrwszrb2gmt5","app_id":"406650865825350227","platform":"web","template":"sign_in","name":"Untitled automation","created_at":"2024-08-19T19:05:42.535Z","updated_at":"2024-08-19T19:05:42.535Z","state":"enabled","order":20}
            """
            let decoder = JSONDecoder()
            let automation = try decoder.decode(
                RowndAutomation.self,
                from: (automationString.data(using: .utf8) ?? Data())
            )
            
            var automationRule: RowndAutomationRule? = nil
            automation.rules.forEach { rule in
                if case let .rule(Rule) = rule {
                    automationRule = Rule
                }
            }
            
            XCTAssertTrue(automationRule?.condition == RowndAutomationRuleCondition.equals)
            XCTAssertTrue(automation.triggers.first?.value == "3h")
            
            do {
                let encoded = try automation.toDictionary()
            } catch {
                XCTFail("Failed to encode app config string \(error)")
            }
            
        } catch {
            XCTFail("Failed to decode app config string \(error)")
        }
        
    }
    
    func testFailedDecodingAppConfigAutomationFallback() {
        do {
            let automationString = """
            {"random":"randy"}
            """
            let decoder = JSONDecoder()
            let automation = try decoder.decode(
                RowndAutomation.self,
                from: (automationString.data(using: .utf8) ?? Data())
            )
            
            XCTAssertTrue(automation.state == .disabled)
        } catch {
            XCTFail("Failed to decode app config string \(error)")
        }
        
    }
}
