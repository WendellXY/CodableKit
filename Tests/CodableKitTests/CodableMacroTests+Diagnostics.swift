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
        .init(message: "Properties must have a type annotation", line: 1, column: 1),
        .init(message: "Code generation already prepared for declaration but properties not found", line: 1, column: 1),
      ],
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

        static let staticProperty: String = "Hello World"
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          let age: Int

          static let staticProperty: String = "Hello World"
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
          }

          public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
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
