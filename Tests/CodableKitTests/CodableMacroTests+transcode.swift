//
//  CodableMacroTests+transcode.swift
//  CodableKitTests
//
//  Verifies optional transcode behavior and shared codec variables.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite struct CodableKitTranscodeTests {
  @Test func optionalTranscode_omitsKey_whenNil() throws {
    assertMacroExpansion(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Codable
      public struct User {
        @CodableKey(options: .transcodeRawString)
        var room: Room?
      }
      """,
      expandedSource: """
        struct Room: Codable {
          let id: UUID
          let name: String
        }
        public struct User {
          var room: Room?

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            let __ckEncoder = JSONEncoder()
            if let roomUnwrapped = room {
              let roomRawData = try __ckEncoder.encode(roomUnwrapped)
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
            }
            try didEncode(to: encoder)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case room
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let __ckDecoder = JSONDecoder()
            let roomRawString = (try? container.decodeIfPresent(String.self, forKey: .room)) ?? ""
            if !roomRawString.isEmpty, let roomRawData = roomRawString.data(using: .utf8) {
              room = (try? __ckDecoder.decode(Room?.self, from: roomRawData)) ?? nil
            } else {
              room = nil
            }
            try didDecode(from: decoder)
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )
  }

  @Test func optionalTranscode_explicitNil_encodesNullString() throws {
    assertMacroExpansion(
      """
      struct Room: Codable {
        let id: UUID
        let name: String
      }
      @Codable
      public struct User {
        @CodableKey(options: [.transcodeRawString, .explicitNil])
        var room: Room?
      }
      """,
      expandedSource: """
        struct Room: Codable {
          let id: UUID
          let name: String
        }
        public struct User {
          var room: Room?

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            let __ckEncoder = JSONEncoder()
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
            try didEncode(to: encoder)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case room
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let __ckDecoder = JSONDecoder()
            let roomRawString = (try? container.decodeIfPresent(String.self, forKey: .room)) ?? ""
            if !roomRawString.isEmpty, let roomRawData = roomRawString.data(using: .utf8) {
              room = (try? __ckDecoder.decode(Room?.self, from: roomRawData)) ?? nil
            } else {
              room = nil
            }
            try didDecode(from: decoder)
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )
  }
}


