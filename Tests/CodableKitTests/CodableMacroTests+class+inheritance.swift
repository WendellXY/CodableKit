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

    assertMacro(
      """
      @Codable
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

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
        """
    )

  }

  @Test func macroWithDefaultValue() throws {

    assertMacro(
      """
      @Codable
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 24
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

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
        """
    )

  }

  @Test func macroWithCodableKeyAndDefaultValue() throws {

    assertMacro(
      """
      @Codable
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 24
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

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
        """
    )

  }

  @Test func macroWithOptionalValue() throws {

    assertMacro(
      """
      @Codable
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int?.self, forKey: .age) ?? 24
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

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
        """
    )

  }

  @Test func macroWithIgnoredCodableKey() throws {

    assertMacro(
      """
      @Codable
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int?.self, forKey: .age) ?? 24
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

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
        """
    )

  }

  @Test func macroWithExplicitNil() throws {

    assertMacro(
      """
      @Codable
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int?.self, forKey: .age) ?? 24
            explicitNil = try container.decodeIfPresent(String?.self, forKey: .explicitNil) ?? nil
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

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
        """
    )

  }

  @Test func macroWithOneCustomKeyGenerated() throws {

    assertMacro(
      """
      @Codable
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

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
        """
    )

  }

  @Test func macroWithTwoCustomKeyGenerated() throws {

    assertMacro(
      """
      @Codable
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

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
        """
    )

  }

  @Test func macroWithDecodingRawString() throws {

    assertMacro(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Codable
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let __ckDecoder = JSONDecoder()
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            let roomRawString = try container.decodeIfPresent(String.self, forKey: .room) ?? ""
            if !roomRawString.isEmpty, let roomRawData = roomRawString.data(using: .utf8) {
              room = try __ckDecoder.decode(Room.self, from: roomRawData)
            } else {
              throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                  codingPath: [CodingKeys.room],
                  debugDescription: "Failed to convert raw string to data"
                )
              )
            }
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            let __ckEncoder = JSONEncoder()
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            let roomRawData = try __ckEncoder.encode(room)
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
        """
    )

  }

  @Test func macroWithDecodingRawStringAndIgnoreError() throws {

    assertMacro(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Codable
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let __ckDecoder = JSONDecoder()
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            let roomRawString = (try? container.decodeIfPresent(String.self, forKey: .room)) ?? ""
            if !roomRawString.isEmpty, let roomRawData = roomRawString.data(using: .utf8) {
              room = try __ckDecoder.decode(Room.self, from: roomRawData)
            } else {
              throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                  codingPath: [CodingKeys.room],
                  debugDescription: "Failed to convert raw string to data"
                )
              )
            }
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            let __ckEncoder = JSONEncoder()
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            let roomRawData = try __ckEncoder.encode(room)
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
      diagnostics: [
        .init(
          message: "Option '.useDefaultOnFailure' has no effect for non-optional property without a default value",
          line: 10,
          column: 3,
          severity: .warning
        )
      ]
    )

  }

  @Test func macroWithDecodingRawStringWithDefaultValueAndIgnoreError() throws {

    assertMacro(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Codable
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let __ckDecoder = JSONDecoder()
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            let roomRawString = (try? container.decodeIfPresent(String.self, forKey: .room)) ?? ""
            if !roomRawString.isEmpty, let roomRawData = roomRawString.data(using: .utf8) {
              room = (try? __ckDecoder.decode(Room.self, from: roomRawData)) ?? Room(id: UUID(), name: "Hello")
            } else {
              room = Room(id: UUID(), name: "Hello")
            }
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            let __ckEncoder = JSONEncoder()
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            let roomRawData = try __ckEncoder.encode(room)
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
        """
    )

  }

  @Test func macroWithSafeTranscodeRawString() throws {

    assertMacro(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Codable
      public class User: MetaUser {
        let id: UUID
        let name: String
        let age: Int
        @CodableKey(options: .safeTranscodeRawString)
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let __ckDecoder = JSONDecoder()
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            let roomRawString = (try? container.decodeIfPresent(String.self, forKey: .room)) ?? ""
            if !roomRawString.isEmpty, let roomRawData = roomRawString.data(using: .utf8) {
              room = try __ckDecoder.decode(Room.self, from: roomRawData)
            } else {
              throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                  codingPath: [CodingKeys.room],
                  debugDescription: "Failed to convert raw string to data"
                )
              )
            }
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            let __ckEncoder = JSONEncoder()
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            let roomRawData = try __ckEncoder.encode(room)
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
      diagnostics: [
        .init(
          message: "Option '.useDefaultOnFailure' has no effect for non-optional property without a default value",
          line: 10,
          column: 3,
          severity: .warning
        )
      ]
    )

  }

  @Test func macroWithSafeTranscodeRawStringWithDefaultValue() throws {

    assertMacro(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Codable
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let __ckDecoder = JSONDecoder()
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            let roomRawString = (try? container.decodeIfPresent(String.self, forKey: .room)) ?? ""
            if !roomRawString.isEmpty, let roomRawData = roomRawString.data(using: .utf8) {
              room = (try? __ckDecoder.decode(Room.self, from: roomRawData)) ?? Room(id: UUID(), name: "Hello")
            } else {
              room = Room(id: UUID(), name: "Hello")
            }
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

          public override func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            let __ckEncoder = JSONEncoder()
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            let roomRawData = try __ckEncoder.encode(room)
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
        """
    )

  }

  @Test func macrosWithOptionUseDefaultOnFailure() throws {

    assertMacro(
      """
      enum Role: UInt8, Codable {
        case unknown = 255
        case admin = 0
        case user = 1
      }
      @Codable
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            role = (try? container.decodeIfPresent(Role.self, forKey: .role)) ?? .unknown
            try super.init(from: decoder)
            try didDecode(from: decoder)
          }

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
        """
    )

  }

  @Test func macrosWithCodableOptionSkipSuperCoding() throws {

    assertMacro(
      """
      @Codable(options: .skipSuperCoding)
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

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            super.init()
            try didDecode(from: decoder)
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
        }
        """
    )

  }
}
