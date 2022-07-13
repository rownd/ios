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
    
    dependencies: [
        .package(
            url: "https://github.com/Flight-School/AnyCodable",
            from: "0.6.0"
        ),
        .package(
            url: "https://github.com/ReSwift/ReSwift",
            from: "6.1.0"
        ),
        .package(
            url: "https://github.com/auth0/JWTDecode.swift",
            from: "2.6.3"
        )
    ],
    
    targets: [
        .target(
            name: "Rownd",
            dependencies: []
        )
    ],
    
    swiftLanguageVersions: [.v5]
)
