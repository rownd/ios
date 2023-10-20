//
//  File.swift
//  
//
//  Created by Bobby Radford on 10/4/23.
//

import Foundation
import WasmInterpreter


public struct AutomationEngine {
    private static var wasmUrl = URL(string: "https://5bea-136-54-6-168.ngrok-free.app/build/release.wasm")!

    private let _vm: WasmInterpreter
    
    init() throws {
        _vm = try WasmInterpreter.init(module: AutomationEngine.wasmUrl)
    }
    
    func shouldRun(_ arg: Int) throws -> Bool {
        let result = try _vm.call("shouldRun", Int32(arg)) as Int32
        return result == 1
    }
}
