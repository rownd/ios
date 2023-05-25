//
//  Debouncer.swift
//  Rownd
//
//  Created by Michael Murray on 5/23/23.
//

import Foundation

class Debouncer {
    private var lastFireTime = DispatchTime.now()
    private let delay: Double
    private var workItem: DispatchWorkItem?

    init(delay: Double) {
        self.delay = delay
    }

    func debounce(action: @escaping (() -> Void)) {
        workItem?.cancel()
        lastFireTime = DispatchTime.now()
        workItem = DispatchWorkItem { [weak self] in
            if let strongSelf = self,
                DispatchTime.now() >= strongSelf.lastFireTime + strongSelf.delay {
                action()
            }
        }
        if let workItem = workItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
}

