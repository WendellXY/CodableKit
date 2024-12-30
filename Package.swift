// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import Foundation
import PackageDescription

let package = Package(
  name: "CodableKit",
  platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
  products: [
    .library(
      name: "CodableKit",
      targets: ["CodableKit"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
  ],
  targets: [
    .target(
      name: "CodableKitShared",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax")
      ]
    ),
    .macro(
      name: "CodableKitMacros",
      dependencies: [
        "CodableKitShared",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
    .target(
      name: "CodableKit",
      dependencies: [
        "CodableKitShared",
        "CodableKitMacros",
      ]
    ),
    .testTarget(
      name: "CodableKitTests",
      dependencies: [
        "CodableKitShared",
        "CodableKitMacros",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "DecodableKitTests",
      dependencies: [
        "CodableKitShared",
        "CodableKitMacros",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "EncodableKitTests",
      dependencies: [
        "CodableKitShared",
        "CodableKitMacros",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
  ]
)
