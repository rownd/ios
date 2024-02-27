//
//  CGRect+IsEqualTolerance.swift
//
//
//  Created by Bobby Radford on 2/2/24.
//

import Foundation

internal extension CGRect {
    func isEqual(to: CGRect, approximate: Bool) -> Bool {
        if approximate {
            let minXMatch = self.minX.rounded(.toNearestOrAwayFromZero).isEqual(to: to.minX.rounded(.toNearestOrAwayFromZero))
            let minYMatch = self.minY.rounded(.toNearestOrAwayFromZero).isEqual(to: to.minY.rounded(.toNearestOrAwayFromZero))
            let widthMatch = self.width.rounded(.toNearestOrAwayFromZero).isEqual(to: to.width.rounded(.toNearestOrAwayFromZero))
            let heightMatch = self.height.rounded(.toNearestOrAwayFromZero).isEqual(to: to.height.rounded(.toNearestOrAwayFromZero))
            return minXMatch && minYMatch && widthMatch && heightMatch
        }
        return self.equalTo(to)
    }
}
