//
//  Date.swift
//  Rownd
//
//  Created by Michael Murray on 5/24/23.
//

import Foundation
import Kronos
import AnyCodable


internal func stringToSeconds(_ str: String) -> Int? {
    let numberString = str.dropLast()
    let timeUnit = str.suffix(1)
    
    guard let number = Int(numberString) else {
        return nil
    }
    
    switch timeUnit {
    case "s": // seconds
        return number
    case "m": // minutes
        return number * 60
    case "h": // hours
        return number * 3600
    case "d": // days
        return number * 86400
    case "w": // weeks
        return number * 604800
    case "y": // years
        return number * 31536000
    default:
        return nil
    }
}

internal protocol DateOrString {}

extension String: DateOrString {}
extension Date: DateOrString {}


func currentDate() -> Date {
    return Clock.now ?? Date()
}

func currentDateString() -> AnyCodable {
    let date = currentDate()
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return AnyCodable(dateFormatter.string(from: date))
}

