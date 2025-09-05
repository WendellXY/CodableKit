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

@Suite struct CodableKitLossyDecodeTests {
  @Test func lossyArray_nonOptional_noDefault() throws {
    assertMacro(
      """
      @Decodable
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
        }

        extension Model: Decodable {
          enum CodingKeys: String, CodingKey {
            case values
            case values2
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let valuesLossyWrapper = try container.decode(LossyArray<Int>.self, forKey: .values)
            values = valuesLossyWrapper.elements
            let values2LossyWrapper = try container.decode(LossyArray<String>.self, forKey: .values2)
            values2 = values2LossyWrapper.elements
            try didDecode(from: decoder)
          }
        }
        """
    )
  }

  @Test func lossyArray_optional() throws {
    assertMacro(
      """
      @Decodable
      public struct Model {
        @CodableKey(options: .lossy)
        let values: [String]?
      }
      """,
      expandedSource: """
        public struct Model {
          let values: [String]?
        }

        extension Model: Decodable {
          enum CodingKeys: String, CodingKey {
            case values
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let valuesLossyWrapper = try container.decodeIfPresent(LossyArray<String>.self, forKey: .values) ?? nil
            if let valuesLossyUnwrapped = valuesLossyWrapper {
              values = valuesLossyUnwrapped.elements
            } else {
              values = nil
            }
            try didDecode(from: decoder)
          }
        }
        """
    )
  }

  @Test func lossyArray_nonOptional_withDefault_and_useDefaultOnFailure() throws {
    assertMacro(
      """
      @Decodable
      public struct Model {
        @CodableKey(options: [.lossy, .useDefaultOnFailure])
        var values: [Int] = [1, 2]
      }
      """,
      expandedSource: """
        public struct Model {
          var values: [Int] = [1, 2]
        }

        extension Model: Decodable {
          enum CodingKeys: String, CodingKey {
            case values
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let valuesLossyWrapper = (try? container.decodeIfPresent(LossyArray<Int>.self, forKey: .values)) ?? nil
            if let valuesLossyUnwrapped = valuesLossyWrapper {
              values = valuesLossyUnwrapped.elements
            } else {
              values = [1, 2]
            }
            try didDecode(from: decoder)
          }
        }
        """
    )
  }

  @Test func lossySet_optional() throws {
    assertMacro(
      """
      @Decodable
      public struct Model {
        @CodableKey(options: .lossy)
        let ids: Set<Int>?
      }
      """,
      expandedSource: """
        public struct Model {
          let ids: Set<Int>?
        }

        extension Model: Decodable {
          enum CodingKeys: String, CodingKey {
            case ids
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let idsLossyWrapper = try container.decodeIfPresent(LossyArray<Int>.self, forKey: .ids) ?? nil
            if let idsLossyUnwrapped = idsLossyWrapper {
              ids = Set(idsLossyUnwrapped.elements)
            } else {
              ids = nil
            }
            try didDecode(from: decoder)
          }
        }
        """
    )
  }

  @Test func lossy_conflict_with_transcodeRawString() throws {
    assertMacro(
      """
      @Decodable
      public struct Model {
        @CodableKey(options: [.lossy, .transcodeRawString])
        let values: [Int]
      }
      """,
      expandedSource: """
        public struct Model {
          let values: [Int]
        }

        extension Model: Decodable {
          enum CodingKeys: String, CodingKey {
            case values
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let __ckDecoder = JSONDecoder()
            let valuesLossyWrapper = try container.decode(LossyArray<Int>.self, forKey: .values)
            values = valuesLossyWrapper.elements
            let valuesRawString = try container.decodeIfPresent(String.self, forKey: .values) ?? ""
            if !valuesRawString.isEmpty, let valuesRawData = valuesRawString.data(using: .utf8) {
              values = try __ckDecoder.decode([Int].self, from: valuesRawData)
            } else {
              throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                  codingPath: [CodingKeys.values],
                  debugDescription: "Failed to convert raw string to data"
                )
              )
            }
            try didDecode(from: decoder)
          }
        }
        """,
      diagnostics: [
        .init(
          message: "Options '.lossy' and '.transcodeRawString' cannot be combined on the same property",
          line: 4,
          column: 7,
          severity: .error
        )
      ]
    )
  }
}
