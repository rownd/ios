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
            name: "AnyCodable",
            url: "https://github.com/Flight-School/AnyCodable",
            .upToNextMajor(from: "0.6.0")
        ),
        .package(
            name: "ReSwift",
            url: "https://github.com/ReSwift/ReSwift",
            .upToNextMajor(from: "6.1.0")
        ),
        .package(
            name: "ReSwift-Thunk",
            url: "https://github.com/ReSwift/ReSwift-Thunk",
            .upToNextMajor(from: "2.0.0")
        ),
        .package(
            name: "JWTDecode",
            url: "https://github.com/auth0/JWTDecode.swift",
            .upToNextMajor(from: "2.6.3")
        )
    ],
    
    targets: [
        .target(
            name: "Rownd",
            dependencies: ["AnyCodable", "ReSwift", "ReSwift-Thunk", "JWTDecode"]
        )
    ],
    
    swiftLanguageVersions: [.v5]
)
