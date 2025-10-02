//
//  CodableMacroTests+lossy.swift
//  CodableKitTests
//
//  Created by Assistant on 2025/9/5.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite struct CodableKitLossyEncodeTests {
  @Test func lossyArray_nonOptional_noDefault() throws {
    assertMacro(
      """
      @Encodable
      public struct Model {
        @CodableKey(options: .lossy)
        let values: [Int]
        @CodableKey(options: .lossy)
        let values2: Array<String>
      }
      """,
      expandedSource: """
        public struct Model {
          let values: [Int]
          let values2: Array<String>

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(values, forKey: .values)
            try container.encode(values2, forKey: .values2)
          }
        }

        extension Model: Encodable {
          enum CodingKeys: String, CodingKey {
            case values
            case values2
          }
        }
        """
    )
  }

  @Test func lossyArray_optional() throws {
    assertMacro(
      """
      @Encodable
      public struct Model {
        @CodableKey(options: .lossy)
        let values: [String]?
      }
      """,
      expandedSource: """
        public struct Model {
          let values: [String]?

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(values, forKey: .values)
          }
        }

        extension Model: Encodable {
          enum CodingKeys: String, CodingKey {
            case values
          }
        }
        """
    )
  }

  @Test func lossyArray_nonOptional_withDefault_and_useDefaultOnFailure() throws {
    assertMacro(
      """
      @Encodable
      public struct Model {
        @CodableKey(options: [.lossy, .useDefaultOnFailure])
        var values: [Int] = [1, 2]
      }
      """,
      expandedSource: """
        public struct Model {
          var values: [Int] = [1, 2]

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(values, forKey: .values)
          }
        }

        extension Model: Encodable {
          enum CodingKeys: String, CodingKey {
            case values
          }
        }
        """
    )
  }

  @Test func lossySet_optional() throws {
    assertMacro(
      """
      @Encodable
      public struct Model {
        @CodableKey(options: .lossy)
        let ids: Set<Int>?
      }
      """,
      expandedSource: """
        public struct Model {
          let ids: Set<Int>?

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(ids, forKey: .ids)
          }
        }

        extension Model: Encodable {
          enum CodingKeys: String, CodingKey {
            case ids
          }
        }
        """
    )
  }

  @Test func lossy_combined_with_transcodeRawString() throws {
    assertMacro(
      """
      @Encodable
      public struct Model {
        @CodableKey(options: [.lossy, .transcodeRawString])
        let values: [Int]
      }
      """,
      expandedSource: """
        public struct Model {
          let values: [Int]

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let __ckEncoder = JSONEncoder()
            let valuesRawData = try __ckEncoder.encode(values)
            if let valuesRawString = String(data: valuesRawData, encoding: .utf8) {
              try container.encode(valuesRawString, forKey: .values)
            } else {
              throw EncodingError.invalidValue(
                valuesRawData,
                EncodingError.Context(
                  codingPath: [CodingKeys.values],
                  debugDescription: "Failed to transcode raw data to string"
                )
              )
            }
          }
        }

        extension Model: Encodable {
          enum CodingKeys: String, CodingKey {
            case values
          }
        }
        """
    )
  }

  @Test func lossy_combined_with_safeTranscodeRawString() throws {
    assertMacro(
      """
      @Encodable
      public struct Model {
        @CodableKey(options: [.lossy, .safeTranscodeRawString])
        var values: [Int] = [1, 2]
      }
      """,
      expandedSource: """
        public struct Model {
          var values: [Int] = [1, 2]

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            let __ckEncoder = JSONEncoder()
            let valuesRawData = try __ckEncoder.encode(values)
            if let valuesRawString = String(data: valuesRawData, encoding: .utf8) {
              try container.encode(valuesRawString, forKey: .values)
            } else {
              throw EncodingError.invalidValue(
                valuesRawData,
                EncodingError.Context(
                  codingPath: [CodingKeys.values],
                  debugDescription: "Failed to transcode raw data to string"
                )
              )
            }
          }
        }

        extension Model: Encodable {
          enum CodingKeys: String, CodingKey {
            case values
          }
        }
        """
    )
  }
}
