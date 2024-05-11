// swift-tools-version: 5.10
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
    .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.1.0"),
  ],
  targets: [
    .macro(
      name: "CodableKitMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),
    .target(name: "CodableKit", dependencies: ["CodableKitMacros"]),
    .testTarget(
      name: "CodableKitTests",
      dependencies: [
        "CodableKitMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ]
    ),
  ]
)

let buildForBinary = ProcessInfo.processInfo.environment["BUILD_FOR_BINARY"]?.lowercased() == "true"

if buildForBinary {
  package.products = [
    .executable(
      name: "CodableKitMacros",
      targets: ["CodableKitMacros"]
    )
  ]

  package.targets = package.targets.compactMap { target in
    if target.type == .macro {
      .executableTarget(
        name: target.name,
        dependencies: target.dependencies,
        path: target.path,
        exclude: target.exclude,
        sources: target.sources,
        resources: target.resources,
        publicHeadersPath: target.publicHeadersPath,
        cSettings: target.cSettings,
        cxxSettings: target.cxxSettings,
        swiftSettings: target.swiftSettings,
        linkerSettings: target.linkerSettings,
        plugins: target.plugins
      )
    } else {
      target
    }
  }
}
