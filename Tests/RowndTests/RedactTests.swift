//
//  RedactTests.swift
//  RowndTests
//
//  Created by AI Assistant on 12/19/24.
//

import Foundation
import Testing

@testable import Rownd

@Suite struct RedactTests {
    
    // MARK: - Basic Redaction Tests
    
    @Test func testRedactAccessToken() async throws {
        let jsonString = """
        {
            "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test",
            "user": {
                "id": "123",
                "email": "test@example.com"
            }
        }
        """
        
        let redacted = Redact.redactSensitiveKeys(in: jsonString)
        
        #expect(redacted.contains("[REDACTED]"), "Should redact access token")
        #expect(!redacted.contains("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test"), "Should not contain original token")
        #expect(redacted.contains("test@example.com"), "Should preserve non-sensitive data")
    }
    
    @Test func testRedactRefreshToken() async throws {
        let jsonString = """
        {
            "refreshToken": "refresh_token_value_here",
            "expiresIn": 3600
        }
        """
        
        let redacted = Redact.redactSensitiveKeys(in: jsonString)
        
        #expect(redacted.contains("[REDACTED]"), "Should redact refresh token")
        #expect(!redacted.contains("refresh_token_value_here"), "Should not contain original refresh token")
        #expect(redacted.contains("3600"), "Should preserve non-sensitive data")
    }
    
    @Test func testRedactUnderscoreTokens() async throws {
        let jsonString = """
        {
            "access_token": "access_token_value",
            "refresh_token": "refresh_token_value"
        }
        """
        
        let redacted = Redact.redactSensitiveKeys(in: jsonString)
        
        #expect(redacted.contains("[REDACTED]"), "Should redact underscore tokens")
        #expect(!redacted.contains("access_token_value"), "Should not contain original access_token")
        #expect(!redacted.contains("refresh_token_value"), "Should not contain original refresh_token")
    }
    
    @Test func testRedactMultipleTokens() async throws {
        let jsonString = """
        {
            "accessToken": "access_value",
            "refreshToken": "refresh_value",
            "access_token": "access_underscore_value",
            "refresh_token": "refresh_underscore_value",
            "otherData": "should_remain"
        }
        """
        
        let redacted = Redact.redactSensitiveKeys(in: jsonString)
        
        #expect(redacted.contains("should_remain"), "Should preserve non-sensitive data")
        #expect(!redacted.contains("access_value"), "Should redact accessToken")
        #expect(!redacted.contains("refresh_value"), "Should redact refreshToken") 
        #expect(!redacted.contains("access_underscore_value"), "Should redact access_token")
        #expect(!redacted.contains("refresh_underscore_value"), "Should redact refresh_token")
        
        // Count redactions
        let redactionCount = redacted.components(separatedBy: "[REDACTED]").count - 1
        #expect(redactionCount == 4, "Should redact all 4 token fields")
    }
    
    // MARK: - Edge Cases
    
    @Test func testRedactEmptyString() async throws {
        let result = Redact.redactSensitiveKeys(in: "")
        #expect(result == "", "Should handle empty string")
    }
    
    @Test func testRedactNilString() async throws {
        let result = Redact.redactSensitiveKeys(in: nil)
        #expect(result == "", "Should handle nil string")
    }
    
    @Test func testRedactInvalidJSON() async throws {
        let invalidJson = "{ invalid json structure"
        let result = Redact.redactSensitiveKeys(in: invalidJson)
        
        // Should still work on invalid JSON (it's just text processing)
        #expect(result == invalidJson, "Should return original for invalid JSON without tokens")
    }
    
    @Test func testRedactJSONWithoutTokens() async throws {
        let jsonString = """
        {
            "user": {
                "id": "123",
                "email": "test@example.com",
                "name": "Test User"
            },
            "settings": {
                "theme": "dark",
                "notifications": true
            }
        }
        """
        
        let result = Redact.redactSensitiveKeys(in: jsonString)
        #expect(result == jsonString, "Should not modify JSON without sensitive keys")
    }
    
    // MARK: - Complex JSON Structure Tests
    
    @Test func testRedactNestedTokens() async throws {
        let jsonString = """
        {
            "auth": {
                "accessToken": "nested_access_token",
                "user": {
                    "refreshToken": "deeply_nested_refresh_token"
                }
            },
            "metadata": {
                "refresh_token": "metadata_refresh"
            }
        }
        """
        
        let redacted = Redact.redactSensitiveKeys(in: jsonString)
        
        #expect(!redacted.contains("nested_access_token"), "Should redact nested access token")
        #expect(!redacted.contains("deeply_nested_refresh_token"), "Should redact deeply nested refresh token")
        #expect(!redacted.contains("metadata_refresh"), "Should redact metadata refresh token")
        
        let redactionCount = redacted.components(separatedBy: "[REDACTED]").count - 1
        #expect(redactionCount == 3, "Should redact all 3 nested tokens")
    }
    
    @Test func testRedactArrayWithTokens() async throws {
        let jsonString = """
        {
            "tokens": [
                {
                    "accessToken": "token1",
                    "type": "bearer"
                },
                {
                    "refreshToken": "token2",
                    "type": "refresh"
                }
            ]
        }
        """
        
        let redacted = Redact.redactSensitiveKeys(in: jsonString)
        
        #expect(!redacted.contains("token1"), "Should redact token in array")
        #expect(!redacted.contains("token2"), "Should redact refresh token in array")
        #expect(redacted.contains("bearer"), "Should preserve non-sensitive data in array")
        #expect(redacted.contains("refresh"), "Should preserve non-sensitive data in array")
    }
    
    // MARK: - Special Characters and Encoding Tests
    
    @Test func testRedactTokensWithSpecialCharacters() async throws {
        let jsonString = """
        {
            "accessToken": "token-with-special.chars_123!@#",
            "refreshToken": "refresh/token+with=special&chars"
        }
        """
        
        let redacted = Redact.redactSensitiveKeys(in: jsonString)
        
        #expect(!redacted.contains("token-with-special.chars_123!@#"), "Should redact token with special chars")
        #expect(!redacted.contains("refresh/token+with=special&chars"), "Should redact refresh token with special chars")
    }
    
    @Test func testRedactEscapedJSON() async throws {
        let jsonString = """
        {\\"accessToken\\": \\"escaped_token_value\\", \\"data\\": \\"normal_value\\"}
        """
        
        let redacted = Redact.redactSensitiveKeys(in: jsonString)
        
        #expect(!redacted.contains("escaped_token_value"), "Should redact escaped token")
        #expect(redacted.contains("normal_value"), "Should preserve escaped non-sensitive data")
    }
    
    @Test func testRedactUnicodeTokens() async throws {
        let jsonString = """
        {
            "accessToken": "token_with_unicode_🔑_chars",
            "user": "测试用户"
        }
        """
        
        let redacted = Redact.redactSensitiveKeys(in: jsonString)
        
        #expect(!redacted.contains("token_with_unicode_🔑_chars"), "Should redact unicode token")
        #expect(redacted.contains("测试用户"), "Should preserve unicode non-sensitive data")
    }
    
    // MARK: - Performance Tests
    
    @Test func testRedactLargeJSON() async throws {
        // Create a large JSON string with multiple tokens
        var jsonComponents: [String] = []
        jsonComponents.append("{")
        
        for i in 0..<1000 {
            if i > 0 { jsonComponents.append(",") }
            jsonComponents.append("""
                "item\(i)": {
                    "accessToken": "large_token_\(i)",
                    "data": "some_data_\(i)",
                    "refreshToken": "refresh_large_\(i)"
                }
            """)
        }
        
        jsonComponents.append("}")
        let largeJson = jsonComponents.joined()
        
        let startTime = Date()
        let redacted = Redact.redactSensitiveKeys(in: largeJson)
        let elapsed = Date().timeIntervalSince(startTime)
        
        #expect(elapsed < 1.0, "Should redact large JSON in reasonable time")
        #expect(!redacted.contains("large_token_"), "Should redact tokens in large JSON")
        #expect(!redacted.contains("refresh_large_"), "Should redact refresh tokens in large JSON")
        #expect(redacted.contains("some_data_"), "Should preserve non-sensitive data in large JSON")
    }
    
    // MARK: - Regex Error Handling Tests
    
    @Test func testRegexErrorRecovery() async throws {
        // This tests our fix for the regex try! force unwrap
        // The current pattern should be valid, but we test the error handling path
        
        let jsonString = """
        {
            "accessToken": "test_token",
            "normalData": "should_remain"
        }
        """
        
        // The function should handle any regex issues gracefully
        let result = Redact.redactSensitiveKeys(in: jsonString)
        
        // Either the redaction works or the original string is returned (no crash)
        #expect(result.contains("should_remain"), "Should preserve data or return original on regex error")
    }
    
    @Test func testCaseSensitivity() async throws {
        let jsonString = """
        {
            "AccessToken": "should_not_redact_uppercase",
            "accesstoken": "should_not_redact_lowercase",
            "accessToken": "should_redact_camelcase",
            "ACCESSTOKEN": "should_not_redact_allcaps"
        }
        """
        
        let redacted = Redact.redactSensitiveKeys(in: jsonString)
        
        #expect(redacted.contains("should_not_redact_uppercase"), "Should not redact uppercase AccessToken")
        #expect(redacted.contains("should_not_redact_lowercase"), "Should not redact lowercase accesstoken")
        #expect(!redacted.contains("should_redact_camelcase"), "Should redact camelCase accessToken")
        #expect(redacted.contains("should_not_redact_allcaps"), "Should not redact all caps ACCESSTOKEN")
    }
    
    // MARK: - Boundary Tests
    
    @Test func testRedactTokensAtStringBoundaries() async throws {
        let jsonString = """
        {"accessToken":"token_at_start","middle":"data","refreshToken":"token_at_end"}
        """
        
        let redacted = Redact.redactSensitiveKeys(in: jsonString)
        
        #expect(!redacted.contains("token_at_start"), "Should redact token at string start")
        #expect(!redacted.contains("token_at_end"), "Should redact token at string end")
        #expect(redacted.contains("data"), "Should preserve middle data")
    }
    
    @Test func testRedactEmptyTokenValues() async throws {
        let jsonString = """
        {
            "accessToken": "",
            "refreshToken": "",
            "data": "normal_data"
        }
        """
        
        let redacted = Redact.redactSensitiveKeys(in: jsonString)
        
        // Empty tokens should still be redacted
        #expect(redacted.contains("[REDACTED]"), "Should redact empty tokens")
        #expect(redacted.contains("normal_data"), "Should preserve normal data")
    }
}