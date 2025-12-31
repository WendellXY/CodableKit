// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import Foundation
import PackageDescription

let package = Package(
  name: "CodableKit",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .macCatalyst(.v13),
    .visionOS(.v1),
  ],
  products: [
    .library(
      name: "CodableKit",
      targets: ["CodableKit"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"603.0.0")
  ],
  targets: [
    .target(
      name: "CodableKitCore"
    ),
    .macro(
      name: "CodableKitMacros",
      dependencies: [
        "CodableKitCore",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
    .target(
      name: "CodableKit",
      dependencies: [
        "CodableKitCore",
        "CodableKitMacros"
      ]
    ),
    .testTarget(
      name: "CodableKitTests",
      dependencies: [
        "CodableKit",
        "CodableKitMacros",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "DecodableKitTests",
      dependencies: [
        "CodableKit",
        "CodableKitMacros",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "EncodableKitTests",
      dependencies: [
        "CodableKit",
        "CodableKitMacros",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
    .testTarget(
      name: "TransformerTests",
      dependencies: [
        "CodableKit",
        "CodableKitMacros",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
  ]
)
