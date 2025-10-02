//
//  CodableMacroTests+keys.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/9/7.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite struct CodableKitEncodableTestsForDifferentKeys {
  @Test func test_encodable_key_applies_custom_key_for_encodable() throws {
    assertMacro(
      """
      @Encodable
      public struct User {
        let id: UUID
        @EncodableKey("name_en")
        let name: String
        let age: Int
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          let age: Int

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name = "name_en"
            case age
          }
        }
        """
    )
  }

  @Test func test_encodable_key_with_decodable_key() throws {
    assertMacro(
      """
      @Encodable
      public struct User {
        let id: UUID
        @DecodableKey("name_de")
        let name: String
        let age: Int
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          let age: Int
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message:
            "The attached Key macro CodableType(rawValue: 1) does not match the Container macro CodableType(rawValue: 2)",
          line: 1, column: 1
        )
      ]
    )
  }

  @Test func test_encodable_key_with_decodable_key_only() throws {
    assertMacro(
      """
      @Encodable
      public struct User {
        let id: UUID
        let name: String
        let age: Int
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          let age: Int

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }
        }
        """
    )
  }
}
