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
            var container = encoder.container(keyedBy: EncodeKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
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
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
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
          }
        }
        """
    )
  }

  @Test func test_codable_with_decodable_key_only() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: UUID
        @DecodableKey("name_de")
        let name: String
        let age: Int
        @CodableKey(options: .useDefaultOnFailure)
        let avatar: URL?
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          let age: Int
          let avatar: URL?

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: EncodeKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try container.encodeIfPresent(avatar, forKey: .avatar)
          }
        }

        extension User: Codable {
          enum DecodeKeys: String, CodingKey {
            case id
            case name = "name_de"
            case age
            case avatar
          }
          enum EncodeKeys: String, CodingKey {
            case id
            case name
            case age
            case avatar
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: DecodeKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            avatar = (try? container.decodeIfPresent(URL?.self, forKey: .avatar)) ?? nil
          }
        }
        """
    )
  }

  @Test func test_nested_codable() async throws {
    assertMacro(
      """
      @dynamicMemberLookup
      @Codable public struct ColorDesignToken: DesignToken {
          @Codable public struct ColorValue: Sendable {
              @CodableKey("light") private let lightHex: String
              @CodableKey("dark") private let darkHex: String

              public subscript(_ scheme: ColorScheme) -> String {
                  switch scheme {
                  case .light: lightHex
                  case .dark: darkHex
                  @unknown default: lightHex
                  }
              }

              public init(lightHex: String, darkHex: String) {
                  self.lightHex = lightHex
                  self.darkHex = darkHex
              }
          }
          @CodableKey("light") public let name: String
      }
      """,
      expandedSource:
        """
        @dynamicMemberLookup
        public struct ColorDesignToken: DesignToken {
            public struct ColorValue: Sendable {
                private let lightHex: String
                private let darkHex: String

                public subscript(_ scheme: ColorScheme) -> String {
                    switch scheme {
                    case .light: lightHex
                    case .dark: darkHex
                    @unknown default: lightHex
                    }
                }

                public init(lightHex: String, darkHex: String) {
                    self.lightHex = lightHex
                    self.darkHex = darkHex
                }

              public func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(lightHex, forKey: .lightHex)
                try container.encode(darkHex, forKey: .darkHex)
              }
            }
            public let name: String

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
          }
        }

        extension ColorDesignToken.ColorValue: Codable {
          enum CodingKeys: String, CodingKey {
            case lightHex = "light"
            case darkHex = "dark"
          }
          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            lightHex = try container.decode(String.self, forKey: .lightHex)
            darkHex = try container.decode(String.self, forKey: .darkHex)
          }
        }

        extension ColorDesignToken: Codable {
          enum CodingKeys: String, CodingKey {
            case name = "light"
          }
          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
          }
        }
        """)
  }
}
