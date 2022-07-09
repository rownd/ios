// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

//
//  Package.swift
//  framework
//
//  Created by Matt Hamann on 7/8/22.
//

import PackageDescription

let package = Package(
    name: "Rownd",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "Rownd",
            targets: ["Rownd"]
        )
    ],
    
    dependencies: [],
    
    targets: [
        .target(
            name: "Rownd",
            dependencies: []
        )
    ],
    
    swiftLanguageVersions: [.v5]
)
