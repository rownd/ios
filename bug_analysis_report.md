# Bug Analysis Report - Rownd iOS SDK

## Summary
This report identifies potential bugs and issues in the Rownd iOS SDK codebase, categorized by severity and type, along with proposed fixes.

## Critical Issues (High Priority)

### 1. Force Unwrapping Could Cause Crashes

**Location:** `Sources/Rownd/Models/PasskeyCoordinator.swift`
```swift
// Lines 92, 157, 418
let anchor: ASPresentationAnchor = (getWindowScene()?.windows.last?.rootViewController?.view.window)!
```

**Issue:** Multiple force unwraps in the chain could cause crashes if any component is nil.

**Proposed Fix:**
```swift
private func getPresentationAnchor() -> ASPresentationAnchor? {
    guard let windowScene = getWindowScene(),
          let window = windowScene.windows.last,
          let rootViewController = window.rootViewController,
          let presentationWindow = rootViewController.view.window else {
        logger.error("Unable to get presentation anchor for passkey authentication")
        return nil
    }
    return presentationWindow
}

// Usage:
guard let anchor = getPresentationAnchor() else {
    logger.error("Cannot present passkey UI - no valid window anchor")
    return
}
```

### 2. Base64 Decoding Force Unwrap

**Location:** `Sources/Rownd/Models/PasskeyCoordinator.swift`
```swift
// Lines 195, 220
let challenge = Data(base64EncodedURLSafe: challengeResponse.challenge)!
```

**Issue:** Force unwrapping base64 decoding could crash if the challenge string is malformed.

**Proposed Fix:**
```swift
guard let challenge = Data(base64EncodedURLSafe: challengeResponse.challenge) else {
    logger.error("Failed to decode challenge data")
    await hubViewController?.loadNewPage(
        targetPage: .connectPasskey,
        jsFnOptions: RowndConnectPasskeySignInOptions(
            status: .failed,
            biometricType: LAContext().biometricType.rawValue,
            error: "Invalid challenge data"
        )
    )
    return
}
```

### 3. API Response Force Cast

**Location:** `Sources/Rownd/framework/APIClient.swift`
```swift
// Line 34
let response = resp as! HTTPURLResponse
```

**Issue:** Force casting could crash if the response is not an HTTPURLResponse.

**Proposed Fix:**
```swift
guard let response = resp as? HTTPURLResponse else {
    logger.error("Invalid response type received")
    DispatchQueue.main.async { completion(nil) }
    return
}
```

### 4. fatalError in Configuration Encoding

**Location:** `Sources/Rownd/Models/RowndConfig.swift`
```swift
// Line 48
fatalError("Couldn't encode Rownd Config as \(self):\n\(error)")
```

**Issue:** Using `fatalError` will crash the app instead of gracefully handling the error.

**Proposed Fix:**
```swift
logger.error("Failed to encode Rownd Config: \(error)")
// Return a default configuration or throw an error instead
throw RowndError("Configuration encoding failed: \(error.localizedDescription)")
```

## Medium Priority Issues

### 5. Inconsistent Threading Patterns

**Issue:** Mixed usage of `DispatchQueue.main.async` and `Task { @MainActor }` throughout the codebase.

**Examples:**
- `Sources/Rownd/framework/Authenticator.swift:187` uses `DispatchQueue.main.async`
- `Sources/Rownd/Models/PasskeyCoordinator.swift:345` uses `DispatchQueue.main.async`
- Other files use `Task { @MainActor }`

**Proposed Fix:** Standardize on `Task { @MainActor }` for consistency with modern Swift concurrency:

```swift
// Instead of:
DispatchQueue.main.async {
    Context.currentContext.store.dispatch(SetAuthState(...))
}

// Use:
Task { @MainActor in
    Context.currentContext.store.dispatch(SetAuthState(...))
}
```

### 6. Potential Memory Leak in Timer

**Location:** `Sources/Rownd/Rownd.swift`
```swift
// Line 38
internal var automationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    Rownd.automationsCoordinator.processAutomations()
}
```

**Issue:** Timer is not properly invalidated, could cause memory leaks.

**Proposed Fix:**
```swift
internal var automationTimer: Timer?

private func startAutomationTimer() {
    automationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        Rownd.automationsCoordinator.processAutomations()
    }
}

deinit {
    automationTimer?.invalidate()
    automationTimer = nil
}
```

### 7. Weak Reference Missing in Async Tasks

**Location:** `Sources/Rownd/framework/Authenticator.swift`
```swift
// Lines 240, 252
group.addTask { @MainActor [weak self] in
    // ...
    Task { [weak self] in
        await self?.storeCancellable(cancellable)
    }
}
```

**Issue:** Good practice is followed here, but similar patterns in other files miss weak references.

**Recommendation:** Review all async task closures for potential retain cycles.

### 8. Force Unwrap in Regular Expression

**Location:** `Sources/Rownd/framework/Redact.swift`
```swift
// Line 20
let regex = try! NSRegularExpression(pattern: pattern, options: [])
```

**Issue:** Force unwrapping `try!` could crash if the regex pattern is invalid.

**Proposed Fix:**
```swift
do {
    let regex = try NSRegularExpression(pattern: pattern, options: [])
    return regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count), withTemplate: replacement)
} catch {
    logger.error("Invalid regex pattern: \(pattern)")
    return text // Return original text if regex fails
}
```

## Low Priority Issues

### 9. Unused TODO Comments

**Location:** `Sources/Rownd/Rownd.swift:382`
```swift
// TODO: Eventually, replace this with native iOS 15+ sheetPresentationController
```

**Recommendation:** Since iOS 15+ adoption is now widespread, consider implementing this improvement.

### 10. Debug Code in Production

**Location:** `Sources/Rownd/Rownd.swift:286-304`
```swift
@available(*, deprecated, message: "Internal test use only. This method may change any time without warning.")
public static func _refreshToken() {
    // Internal test function...
}
```

**Recommendation:** Consider removing or better protecting this debug function.

### 11. Hardcoded Magic Numbers

**Examples:**
- Clock sync timeout: 500ms (line 261 in Authenticator.swift)
- UI delays: 1.0s, 1.5s, 6.0s in various files

**Recommendation:** Extract to constants with descriptive names:

```swift
private enum TimeConstants {
    static let clockSyncTimeout: UInt64 = 500_000_000 // 500ms in nanoseconds
    static let hubLoadDelay: TimeInterval = 1.0
    static let uiAnimationDelay: TimeInterval = 1.5
    static let webViewTimeout: TimeInterval = 6.0
}
```

## Testing Gaps

### 12. Missing Error Handling Tests

**Recommendation:** Add tests for:
- Network failure scenarios in PasskeyCoordinator
- Malformed API responses
- Threading edge cases
- Memory pressure scenarios

### 13. Force Unwrap Testing

Many force unwraps in the codebase are not covered by tests that could trigger the nil scenarios.

## Implementation Priority

1. **Immediate (Critical):** Fix all force unwrapping issues (#1, #2, #3)
2. **Next Sprint:** Address fatalError usage (#4) and timer memory leak (#6)
3. **Technical Debt:** Standardize threading patterns (#5) and add missing tests (#12, #13)
4. **Future:** Address TODOs and hardcoded values (#9, #10, #11)

## Additional Recommendations

1. **Code Review Process:** Implement automated checks for force unwrapping and fatalError usage
2. **Static Analysis:** Use SwiftLint rules to catch potential issues
3. **Crash Reporting:** Ensure comprehensive crash reporting to catch force unwrap crashes in production
4. **Unit Testing:** Increase test coverage for error scenarios and edge cases
5. **Documentation:** Add inline documentation for complex async/threading patterns

This analysis should help prioritize bug fixes and improve the overall stability and maintainability of the Rownd iOS SDK.