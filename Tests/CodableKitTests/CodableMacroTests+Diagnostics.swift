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
    #if canImport(CodableKitMacros)
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
      macros: macros,
      indentationWidth: .spaces(2)
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }

  func testMacroWithIgnoredPropertyTypeAnnotation() throws {
    #if canImport(CodableKitMacros)
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

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
          }

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }
        }
        """,
      macros: macros,
      indentationWidth: .spaces(2)
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }

  func testMacroWithStaticTypeAnnotation() throws {
    #if canImport(CodableKitMacros)
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

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
          }

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }
        }
        """,
      macros: macros,
      indentationWidth: .spaces(2)
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
}
