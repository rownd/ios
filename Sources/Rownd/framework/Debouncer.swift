//
//  Debouncer.swift
//  Rownd
//
//  Created by Michael Murray on 5/23/23.
//

import Foundation

class Debouncer {
//    private var debounceWorkItem: DispatchWorkItem?
    private var timer: Timer?

    func debounce(interval: TimeInterval, action: @escaping () -> Void) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            print ("Debounce this...")
            action()
        }

//        // Cancel the previous work item if it exists
//        debounceWorkItem?.cancel()
//
//        // Create a new work item with the specified action
//        let newWorkItem = DispatchWorkItem {
//            action()
//        }
//
//        // Save the new work item
//        debounceWorkItem = newWorkItem

        // Schedule the new work item after the specified interval
//        Task {
//            do {
//                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000)) // Convert seconds to nanoseconds
//                guard let workItem = debounceWorkItem else {
//                    return
//                }
//                if !workItem.isCancelled {
//                    workItem.perform()
//                }
//            }
//        }
    }
}

