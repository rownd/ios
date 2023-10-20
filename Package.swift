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
        .iOS(.v14),
        .macOS(.v11)
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
            name: "ReSwiftThunk",
            url: "https://github.com/ReSwift/ReSwift-Thunk",
            .upToNextMajor(from: "2.0.0")
        ),
        .package(
            name: "JWTDecode",
            url: "https://github.com/auth0/JWTDecode.swift",
            .upToNextMajor(from: "2.6.3")
        ),
        .package(
            name: "LBBottomSheet",
            url: "https://github.com/LunabeeStudio/LBBottomSheet",
            .upToNextMajor(from: "1.0.17")
        ),
        .package(
            name: "SwiftKeychainWrapper",
            url: "https://github.com/jrendel/SwiftKeychainWrapper",
            .upToNextMajor(from: "4.0.1")
        ),
        .package(
            name: "Sodium",
            url: "https://github.com/jedisct1/swift-sodium",
            .upToNextMajor(from: "0.9.1")
        ),
        .package(
            name: "CodeScanner_Rownd",
            url: "https://github.com/rownd/CodeScanner_Rownd",
            .upToNextMajor(from: "2.1.2")
        ),
        .package(
            name: "Get",
            url: "https://github.com/rownd/Get",
            .upToNextMajor(from: "2.0.1")
        ),
        .package(
            name: "GoogleSignIn",
            url: "https://github.com/google/GoogleSignIn-iOS.git",
            .upToNextMajor(from: "6.2.4")
        ),
        .package(
            name: "Lottie",
            url: "https://github.com/airbnb/lottie-ios",
            .upToNextMajor(from: "3.4.3")
        ),
        .package(
            name: "Factory",
            url: "https://github.com/hmlongco/Factory",
            .upToNextMajor(from: "1.2.8")
        ),
        .package(
            name: "Kronos",
            url: "https://github.com/MobileNativeFoundation/Kronos",
            .upToNextMajor(from: "4.2.1")
        ),
        .package(
            name: "Mocker",
            url: "https://github.com/WeTransfer/Mocker",
            .upToNextMajor(from: "3.0.1")
        ),
        .package(
            name: "WasmInterpreter",
            url: "https://github.com/shareup/wasm-interpreter-apple.git",
            from: "0.8.1"
        ),
        
    ],
    
    targets: [
        .target(
            name: "Rownd",
            dependencies: [
                "AnyCodable",
                "ReSwift",
                "ReSwiftThunk",
                "JWTDecode",
                "LBBottomSheet",
                "SwiftKeychainWrapper",
                "Sodium",
                "CodeScanner_Rownd",
                "Get",
                "GoogleSignIn",
                "Lottie",
                "Factory",
                "Kronos",
                "WasmInterpreter"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "RowndTests",
            dependencies: [
                "Mocker",
                "AnyCodable",
                "ReSwift",
                "ReSwiftThunk",
                "JWTDecode",
                "LBBottomSheet",
                "SwiftKeychainWrapper",
                "Sodium",
                "CodeScanner_Rownd",
                "Get",
                "GoogleSignIn",
                "Lottie",
                "Factory",
                "Rownd",
                "Kronos",
                "WasmInterpreter"
            ]
        )
    ],
    
    swiftLanguageVersions: [.v5]
)
