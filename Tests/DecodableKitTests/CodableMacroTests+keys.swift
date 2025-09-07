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

@Suite struct CodableKitDecodableTestsForDifferentKeys {
  @Test func test_decodable_key_applies_custom_key_for_decodable() throws {
    assertMacro(
      """
      @Decodable
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

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name = "name_de"
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
        """
    )
  }

  @Test func test_decodable_key_with_encodable_key() throws {
    assertMacro(
      """
      @Decodable
      public struct User {
        let id: UUID
        @EncodableKey("name_de")
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
            "The attached Key macro CodableType(rawValue: 2) does not match the Container macro CodableType(rawValue: 1)",
          line: 1, column: 1)
      ]
    )
  }

  @Test func test_decodable_key_with_decodable_key_only() throws {
    assertMacro(
      """
      @Decodable
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

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name = "name_de"
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
        """
    )
  }
}
