//
//  CodableMacroTests+Diagnostics.swift
//  CodableKit
//
//  Created by WendellXY on 2024/5/27
//  Copyright © 2024 WendellXY. All rights reserved.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class CodableKitDiagnosticsTests: XCTestCase {
  func testMacroWithNoTypeAnnotation() throws {
    assertMacroExpansion(
      """
      @Codable
      public struct User {
        let id: UUID
        let name: String
        var age = 24
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age = 24
        }
        """,
      diagnostics: [
        .init(message: "Properties must have a type annotation", line: 1, column: 1)
      ],
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )
  }

  func testMacroWithIgnoredPropertyTypeAnnotation() throws {

    assertMacroExpansion(
      """
      @Codable
      public struct User {
        let id: UUID
        let name: String
        let age: Int
        @CodableKey(options: .ignored)
        var ignored: String = "Hello World"
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          let age: Int
          var ignored: String = "Hello World"

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try didEncode(to: encoder)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            try didDecode(from: decoder)
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroWithStaticTypeAnnotation() throws {

    assertMacroExpansion(
      """
      @Codable
      public struct User {
        let id: UUID
        let name: String
        let age: Int

        static let staticProperty = "Hello World"
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          let age: Int

          static let staticProperty = "Hello World"

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try didEncode(to: encoder)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            try didDecode(from: decoder)
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroOnComputeProperty() throws {

    assertMacroExpansion(
      """
      @Codable
      public struct User {
        let id: UUID
        let name: String
        var age: Int = 24
        @CodableKey("hello")
        var address: String {
          "A"
        }
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age: Int = 24
          var address: String {
            "A"
          }

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try didEncode(to: encoder)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 24
            try didDecode(from: decoder)
          }
        }
        """,
      diagnostics: [
        .init(message: "Only variable declarations with no accessor block are supported", line: 6, column: 3)
      ],
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroOnStaticComputeProperty() throws {

    assertMacroExpansion(
      """
      @Codable
      public struct User {
        let id: UUID
        let name: String
        var age: Int = 24
        @CodableKey("hello")
        static var address: String {
          "A"
        }
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age: Int = 24
          static var address: String {
            "A"
          }

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try didEncode(to: encoder)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 24
            try didDecode(from: decoder)
          }
        }
        """,
      diagnostics: [
        .init(message: "Only variable declarations with no accessor block are supported", line: 6, column: 3)
      ],
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroOnStaticProperty() throws {

    assertMacroExpansion(
      """
      @Codable
      public struct User {
        let id: UUID
        let name: String
        var age: Int = 24
        @CodableKey("hello")
        static var address: String = "A"
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age: Int = 24
          static var address: String = "A"

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try didEncode(to: encoder)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 24
            try didDecode(from: decoder)
          }
        }
        """,
      diagnostics: [
        .init(message: "Only non-static variable declarations are supported", line: 6, column: 3)
      ],
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }
}
