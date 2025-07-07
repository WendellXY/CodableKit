//
//  CodableMacroTests.swift
//  CodableKitTests
//
//  Created by Wendell on 3/30/24.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite struct CodableKitTestsForStruct {
  @Test func macros() throws {

    assertMacroExpansion(
      """
      @Decodable
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
        }

        extension User: Decodable {
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

  @Test func macroWithDefaultValue() throws {

    assertMacroExpansion(
      """
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        var age: Int = 24
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age: Int = 24
        }

        extension User: Decodable {
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
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  @Test func macroWithCodableKeyAndDefaultValue() throws {

    assertMacroExpansion(
      """
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        @CodableKey("currentAge")
        var age: Int = 24
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age: Int = 24
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age = "currentAge"
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
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  @Test func macroWithOptionalValue() throws {

    assertMacroExpansion(
      """
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        var age: Int? = 24
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age: Int? = 24
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int?.self, forKey: .age) ?? 24
            try didDecode(from: decoder)
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  @Test func macroWithIgnoredCodableKey() throws {

    assertMacroExpansion(
      """
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        var age: Int? = 24
        @CodableKey(options: .ignored)
        let thisPropertyWillBeIgnored: String
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age: Int? = 24
          let thisPropertyWillBeIgnored: String
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int?.self, forKey: .age) ?? 24
            try didDecode(from: decoder)
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  @Test func macroWithExplicitNil() throws {

    assertMacroExpansion(
      """
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        var age: Int? = 24
        @CodableKey(options: .explicitNil)
        let explicitNil: String?
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age: Int? = 24
          let explicitNil: String?
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
            case explicitNil
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int?.self, forKey: .age) ?? 24
            explicitNil = try container.decodeIfPresent(String?.self, forKey: .explicitNil) ?? nil
            try didDecode(from: decoder)
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  @Test func macroWithOneCustomKeyGenerated() throws {

    assertMacroExpansion(
      """
      @Decodable
      public struct User {
        @CodableKey("uid", options: .generateCustomKey)
        let id: UUID
        let name: String
        let age: Int
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID

          internal var uid: UUID {
            id
          }
          let name: String
          let age: Int
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id = "uid"
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

  @Test func macroWithTwoCustomKeyGenerated() throws {

    assertMacroExpansion(
      """
      @Decodable
      public struct User {
        @CodableKey("uid", options: .generateCustomKey)
        let id: UUID
        @CodableKey("givenName", options: .generateCustomKey)
        let name: String
        let age: Int
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID

          internal var uid: UUID {
            id
          }
          let name: String

          internal var givenName: String {
            name
          }
          let age: Int
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id = "uid"
            case name = "givenName"
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

  @Test func macroWithDecodingRawString() throws {

    assertMacroExpansion(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        let age: Int
        @CodableKey(options: .transcodeRawString)
        let room: Room
      }
      """,
      expandedSource: """
        struct Room: Codable {
          let id: UUID
          let name: String
        }
        public struct User {
          let id: UUID
          let name: String
          let age: Int
          let room: Room
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
            case room
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            let roomRawString = try container.decodeIfPresent(String.self, forKey: .room) ?? ""
            if !roomRawString.isEmpty, let roomRawData = roomRawString.data(using: .utf8) {
              room = try JSONDecoder().decode(Room.self, from: roomRawData)
            } else {
              throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                  codingPath: [CodingKeys.room],
                  debugDescription: "Failed to convert raw string to data"
                )
              )
            }
            try didDecode(from: decoder)
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  @Test func macroWithDecodingRawStringAndIgnoreError() throws {

    assertMacroExpansion(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        let age: Int
        @CodableKey(options: [.useDefaultOnFailure, .transcodeRawString])
        let room: Room
      }
      """,
      expandedSource: """
        struct Room: Codable {
          let id: UUID
          let name: String
        }
        public struct User {
          let id: UUID
          let name: String
          let age: Int
          let room: Room
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
            case room
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            let roomRawString = (try? container.decodeIfPresent(String.self, forKey: .room)) ?? ""
            if !roomRawString.isEmpty, let roomRawData = roomRawString.data(using: .utf8) {
              room = try JSONDecoder().decode(Room.self, from: roomRawData)
            } else {
              throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                  codingPath: [CodingKeys.room],
                  debugDescription: "Failed to convert raw string to data"
                )
              )
            }
            try didDecode(from: decoder)
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  @Test func macroWithDecodingRawStringWithDefaultValueAndIgnoreError() throws {

    assertMacroExpansion(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        let age: Int
        @CodableKey(options: [.useDefaultOnFailure, .transcodeRawString])
        var room: Room = Room(id: UUID(), name: "Hello")
      }
      """,
      expandedSource: """
        struct Room: Codable {
          let id: UUID
          let name: String
        }
        public struct User {
          let id: UUID
          let name: String
          let age: Int
          var room: Room = Room(id: UUID(), name: "Hello")
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
            case room
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            let roomRawString = (try? container.decodeIfPresent(String.self, forKey: .room)) ?? ""
            if !roomRawString.isEmpty, let roomRawData = roomRawString.data(using: .utf8) {
              room = (try? JSONDecoder().decode(Room.self, from: roomRawData)) ?? Room(id: UUID(), name: "Hello")
            } else {
              room = Room(id: UUID(), name: "Hello")
            }
            try didDecode(from: decoder)
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  @Test func macrosWithOptionUseDefaultOnFailure() throws {

    assertMacroExpansion(
      """
      enum Role: UInt8, Codable {
        case unknown = 255
        case admin = 0
        case user = 1
      }
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        let age: Int
        @CodableKey(options: .useDefaultOnFailure)
        var role: Role = .unknown
      }
      """,
      expandedSource: """
        enum Role: UInt8, Codable {
          case unknown = 255
          case admin = 0
          case user = 1
        }
        public struct User {
          let id: UUID
          let name: String
          let age: Int
          var role: Role = .unknown
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
            case role
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            role = (try? container.decodeIfPresent(Role.self, forKey: .role)) ?? .unknown
            try didDecode(from: decoder)
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }
}
