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
import XCTest

final class CodableKitTestsForStruct: XCTestCase {
  func testMacros() throws {

    assertMacroExpansion(
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
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try didEncode(to: encoder)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroWithDefaultValue() throws {

    assertMacroExpansion(
      """
      @Encodable
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

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try didEncode(to: encoder)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroWithCodableKeyAndDefaultValue() throws {

    assertMacroExpansion(
      """
      @Encodable
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

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try didEncode(to: encoder)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age = "currentAge"
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroWithOptionalValue() throws {

    assertMacroExpansion(
      """
      @Encodable
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

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(age, forKey: .age)
            try didEncode(to: encoder)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroWithIgnoredCodableKey() throws {

    assertMacroExpansion(
      """
      @Encodable
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

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(age, forKey: .age)
            try didEncode(to: encoder)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroWithExplicitNil() throws {

    assertMacroExpansion(
      """
      @Encodable
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

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(age, forKey: .age)
            try container.encode(explicitNil, forKey: .explicitNil)
            try didEncode(to: encoder)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
            case explicitNil
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroWithOneCustomKeyGenerated() throws {

    assertMacroExpansion(
      """
      @Encodable
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

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try didEncode(to: encoder)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id = "uid"
            case name
            case age
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroWithTwoCustomKeyGenerated() throws {

    assertMacroExpansion(
      """
      @Encodable
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

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try didEncode(to: encoder)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id = "uid"
            case name = "givenName"
            case age
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroWithDecodingRawString() throws {

    assertMacroExpansion(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Encodable
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

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            let roomRawData = try JSONEncoder().encode(room)
            if let roomRawString = String(data: roomRawData, encoding: .utf8) {
              try container.encode(roomRawString, forKey: .room)
            } else {
              throw EncodingError.invalidValue(
                roomRawData,
                EncodingError.Context(
                  codingPath: [CodingKeys.room],
                  debugDescription: "Failed to transcode raw data to string"
                )
              )
            }
            try didEncode(to: encoder)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
            case room
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroWithDecodingRawStringAndIgnoreError() throws {

    assertMacroExpansion(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Encodable
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

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            let roomRawData = try JSONEncoder().encode(room)
            if let roomRawString = String(data: roomRawData, encoding: .utf8) {
              try container.encode(roomRawString, forKey: .room)
            } else {
              throw EncodingError.invalidValue(
                roomRawData,
                EncodingError.Context(
                  codingPath: [CodingKeys.room],
                  debugDescription: "Failed to transcode raw data to string"
                )
              )
            }
            try didEncode(to: encoder)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
            case room
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacroWithDecodingRawStringWithDefaultValueAndIgnoreError() throws {

    assertMacroExpansion(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Encodable
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

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            let roomRawData = try JSONEncoder().encode(room)
            if let roomRawString = String(data: roomRawData, encoding: .utf8) {
              try container.encode(roomRawString, forKey: .room)
            } else {
              throw EncodingError.invalidValue(
                roomRawData,
                EncodingError.Context(
                  codingPath: [CodingKeys.room],
                  debugDescription: "Failed to transcode raw data to string"
                )
              )
            }
            try didEncode(to: encoder)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
            case room
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  func testMacrosWithOptionUseDefaultOnFailure() throws {

    assertMacroExpansion(
      """
      enum Role: UInt8, Codable {
        case unknown = 255
        case admin = 0
        case user = 1
      }
      @Encodable
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

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try container.encode(role, forKey: .role)
            try didEncode(to: encoder)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
            case role
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }
}
