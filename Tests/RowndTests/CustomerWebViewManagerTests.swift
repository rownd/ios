//
//  CustomerWebViewManagerTests.swift
//  Rownd
//
//  Created by Bobby on 4/14/25.
//

import Testing
import WebKit
import Mockingbird
@testable import Rownd

@Suite(.serialized) struct CustomerWebViewManagerTests {
    /// Register a customer web view and ensure that message handling and script evaluation work correctly
    @Test func registerTest() async throws {
        let mockMessageHandler = mock(CustomerWebViewMessageHandler.self).initialize(customerWebViewId: "wv1")
        let task1 = Task { @MainActor in
            givenSwift(mockMessageHandler.userContentController(any(), didReceive: any())).will { (userContentController: WKUserContentController, message: WKScriptMessage) -> Void in
                logger.info("Received message from web view: \(String(describing: message.body))")
                return
            }
        }
        _ = await task1.result

        let manager = CustomerWebViewManager(wkScriptMessageHandlerProvider: { customerWebViewId in
            return mockMessageHandler
        })
        let wv = await WKWebView()
        let deregister = manager.register(wv)
        
        #expect(manager.webViews.count == 1)
        #expect(manager.webView(id: manager.webViews[0].id) == wv)
        
        try await wv.evaluateJavaScript("""
            var _rphConfig = _rphConfig || [];
            _rphConfig.push(["onLoaded", () => { console.log("loaded"); }]);
        """)
        
        let task2 = Task { @MainActor in
            verify(mockMessageHandler.userContentController(any(), didReceive: any())).wasCalled()
        }
        _ = await task2.result

        deregister()
        #expect(manager.webViews.count == 0)
        
        reset(mockMessageHandler)
        
        try await wv.evaluateJavaScript("""
            var _rphConfig = _rphConfig || [];
            _rphConfig.push(["onLoaded", () => { console.log("loaded"); }]);
        """)
        
        verify(await mockMessageHandler.userContentController(any(), didReceive: any())).wasNeverCalled()
    }
}
