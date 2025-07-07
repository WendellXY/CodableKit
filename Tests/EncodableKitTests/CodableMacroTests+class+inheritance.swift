//
//  CodableKitTestsForStruct.swift
//  CodableKit
//
//  Created by Wendell Wang on 2024/8/16.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite struct CodableKitTestsForSubClass {
  @Test func macros() throws {

    assertMacroExpansion(
      """
      @Encodable
      public class User: MetaUser {
        let id: UUID
        let name: String
        let age: Int
      }
      """,
      expandedSource: """
        public class User: MetaUser {
          let id: UUID
          let name: String
          let age: Int

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try super.encode(to: encoder)
            try didEncode(to: encoder)
          }
        }

        extension User {
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

  @Test func macroWithDefaultValue() throws {

    assertMacroExpansion(
      """
      @Encodable
      public class User: MetaUser {
        let id: UUID
        let name: String
        var age: Int = 24
      }
      """,
      expandedSource: """
        public class User: MetaUser {
          let id: UUID
          let name: String
          var age: Int = 24

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try super.encode(to: encoder)
            try didEncode(to: encoder)
          }
        }

        extension User {
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

  @Test func macroWithCodableKeyAndDefaultValue() throws {

    assertMacroExpansion(
      """
      @Encodable
      public class User: MetaUser {
        let id: UUID
        let name: String
        @CodableKey("currentAge")
        var age: Int = 24
      }
      """,
      expandedSource: """
        public class User: MetaUser {
          let id: UUID
          let name: String
          var age: Int = 24

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try super.encode(to: encoder)
            try didEncode(to: encoder)
          }
        }

        extension User {
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

  @Test func macroWithOptionalValue() throws {

    assertMacroExpansion(
      """
      @Encodable
      public class User: MetaUser {
        let id: UUID
        let name: String
        var age: Int? = 24
      }
      """,
      expandedSource: """
        public class User: MetaUser {
          let id: UUID
          let name: String
          var age: Int? = 24

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(age, forKey: .age)
            try super.encode(to: encoder)
            try didEncode(to: encoder)
          }
        }

        extension User {
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

  @Test func macroWithIgnoredCodableKey() throws {

    assertMacroExpansion(
      """
      @Encodable
      public class User: MetaUser {
        let id: UUID
        let name: String
        var age: Int? = 24
        @CodableKey(options: .ignored)
        let thisPropertyWillBeIgnored: String
      }
      """,
      expandedSource: """
        public class User: MetaUser {
          let id: UUID
          let name: String
          var age: Int? = 24
          let thisPropertyWillBeIgnored: String

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(age, forKey: .age)
            try super.encode(to: encoder)
            try didEncode(to: encoder)
          }
        }

        extension User {
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

  @Test func macroWithExplicitNil() throws {

    assertMacroExpansion(
      """
      @Encodable
      public class User: MetaUser {
        let id: UUID
        let name: String
        var age: Int? = 24
        @CodableKey(options: .explicitNil)
        let explicitNil: String?
      }
      """,
      expandedSource: """
        public class User: MetaUser {
          let id: UUID
          let name: String
          var age: Int? = 24
          let explicitNil: String?

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(age, forKey: .age)
            try container.encode(explicitNil, forKey: .explicitNil)
            try super.encode(to: encoder)
            try didEncode(to: encoder)
          }
        }

        extension User {
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

  @Test func macroWithOneCustomKeyGenerated() throws {

    assertMacroExpansion(
      """
      @Encodable
      public class User: MetaUser {
        @CodableKey("uid", options: .generateCustomKey)
        let id: UUID
        let name: String
        let age: Int
      }
      """,
      expandedSource: """
        public class User: MetaUser {
          let id: UUID

          internal var uid: UUID {
            id
          }
          let name: String
          let age: Int

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try super.encode(to: encoder)
            try didEncode(to: encoder)
          }
        }

        extension User {
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

  @Test func macroWithTwoCustomKeyGenerated() throws {

    assertMacroExpansion(
      """
      @Encodable
      public class User: MetaUser {
        @CodableKey("uid", options: .generateCustomKey)
        let id: UUID
        @CodableKey("givenName", options: .generateCustomKey)
        let name: String
        let age: Int
      }
      """,
      expandedSource: """
        public class User: MetaUser {
          let id: UUID

          internal var uid: UUID {
            id
          }
          let name: String

          internal var givenName: String {
            name
          }
          let age: Int

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try super.encode(to: encoder)
            try didEncode(to: encoder)
          }
        }

        extension User {
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

  @Test func macroWithDecodingRawString() throws {

    assertMacroExpansion(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Encodable
      public class User: MetaUser {
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
        public class User: MetaUser {
          let id: UUID
          let name: String
          let age: Int
          let room: Room

          public override func encode(to encoder: any Encoder) throws {
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
            try super.encode(to: encoder)
            try didEncode(to: encoder)
          }
        }

        extension User {
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

  @Test func macroWithDecodingRawStringAndIgnoreError() throws {

    assertMacroExpansion(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Encodable
      public class User: MetaUser {
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
        public class User: MetaUser {
          let id: UUID
          let name: String
          let age: Int
          let room: Room

          public override func encode(to encoder: any Encoder) throws {
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
            try super.encode(to: encoder)
            try didEncode(to: encoder)
          }
        }

        extension User {
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

  @Test func macroWithDecodingRawStringWithDefaultValueAndIgnoreError() throws {

    assertMacroExpansion(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Encodable
      public class User: MetaUser {
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
        public class User: MetaUser {
          let id: UUID
          let name: String
          let age: Int
          var room: Room = Room(id: UUID(), name: "Hello")

          public override func encode(to encoder: any Encoder) throws {
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
            try super.encode(to: encoder)
            try didEncode(to: encoder)
          }
        }

        extension User {
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

  @Test func macrosWithOptionUseDefaultOnFailure() throws {

    assertMacroExpansion(
      """
      enum Role: UInt8, Codable {
        case unknown = 255
        case admin = 0
        case user = 1
      }
      @Encodable
      public class User: MetaUser {
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
        public class User: MetaUser {
          let id: UUID
          let name: String
          let age: Int
          var role: Role = .unknown

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try container.encode(role, forKey: .role)
            try super.encode(to: encoder)
            try didEncode(to: encoder)
          }
        }

        extension User {
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

  @Test func macrosWithCodableOptionSkipSuperCoding() throws {

    assertMacroExpansion(
      """
      @Encodable(options: .skipSuperCoding)
      public class User: NSObject {
        let id: UUID
        let name: String
        let age: Int
      }
      """,
      expandedSource: """
        public class User: NSObject {
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
}
