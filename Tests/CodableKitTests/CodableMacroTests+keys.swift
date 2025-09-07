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

@Suite struct CodableKitTestsForDifferentKeys {
  @Test func test_different_coding_keys_with_different_coding_keys() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: UUID
        @DecodableKey("name_de")
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
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: EncodeKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try didEncode(to: encoder)
          }
        }

        extension User: Codable {
          enum DecodeKeys: String, CodingKey {
            case id
            case name = "name_de"
            case age
          }
          enum EncodeKeys: String, CodingKey {
            case id
            case name = "name_en"
            case age
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: DecodeKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            try didDecode(from: decoder)
          }
        }
        """
    )
  }

  @Test func test_different_coding_keys_with_same_coding_keys() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: UUID
        @DecodableKey("name_de")
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
