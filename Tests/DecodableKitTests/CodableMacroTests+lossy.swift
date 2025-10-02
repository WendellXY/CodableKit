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
          }
        }
        """
    )
  }

  @Test func lossy_combined_with_transcodeRawString() throws {
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
            let valuesRawString = try container.decodeIfPresent(String.self, forKey: .values) ?? ""
            if !valuesRawString.isEmpty, let valuesRawData = valuesRawString.data(using: .utf8) {
              let valuesLossyWrapper = try __ckDecoder.decode(LossyArray<Int>.self, from: valuesRawData)
              values = valuesLossyWrapper.elements
            } else {
              throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                  codingPath: [CodingKeys.values],
                  debugDescription: "Failed to convert raw string to data"
                )
              )
            }
          }
        }
        """
    )
  }

  @Test func lossy_combined_with_safeTranscodeRawString() throws {
    assertMacro(
      """
      @Decodable
      public struct Model {
        @CodableKey(options: [.lossy, .safeTranscodeRawString])
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
            let __ckDecoder = JSONDecoder()
            let valuesRawString = (try? container.decodeIfPresent(String.self, forKey: .values)) ?? ""
            if !valuesRawString.isEmpty, let valuesRawData = valuesRawString.data(using: .utf8) {
              let valuesLossyWrapper = try __ckDecoder.decode(LossyArray<Int>.self, from: valuesRawData)
              values = valuesLossyWrapper.elements
            } else {
              values = [1, 2]
            }
          }
        }
        """
    )
  }

  @Test func lossyDictionary_nonOptional_noDefault() throws {
    assertMacro(
      """
      @Decodable
      public struct Model {
        @CodableKey(options: .lossy)
        let map: [String: Int]
        @CodableKey(options: .lossy)
        let other: Dictionary<String, Int>
      }
      """,
      expandedSource: """
        public struct Model {
          let map: [String: Int]
          let other: Dictionary<String, Int>
        }

        extension Model: Decodable {
          enum CodingKeys: String, CodingKey {
            case map
            case other
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let mapLossyWrapper = try container.decode(LossyDictionary<String, Int>.self, forKey: .map)
            map = mapLossyWrapper.elements
            let otherLossyWrapper = try container.decode(LossyDictionary<String, Int>.self, forKey: .other)
            other = otherLossyWrapper.elements
          }
        }
        """
    )
  }

  @Test func lossyDictionary_optional() throws {
    assertMacro(
      """
      @Decodable
      public struct Model {
        @CodableKey(options: .lossy)
        let map: [String: Int]?
      }
      """,
      expandedSource: """
        public struct Model {
          let map: [String: Int]?
        }

        extension Model: Decodable {
          enum CodingKeys: String, CodingKey {
            case map
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let mapLossyWrapper = try container.decodeIfPresent(LossyDictionary<String, Int>.self, forKey: .map) ?? nil
            if let mapLossyUnwrapped = mapLossyWrapper {
              map = mapLossyUnwrapped.elements
            } else {
              map = nil
            }
          }
        }
        """
    )
  }

  @Test func lossyDictionary_nonOptional_withDefault_and_useDefaultOnFailure() throws {
    assertMacro(
      """
      @Decodable
      public struct Model {
        @CodableKey(options: [.lossy, .useDefaultOnFailure])
        var map: [String: Int] = ["a": 1]
      }
      """,
      expandedSource: """
        public struct Model {
          var map: [String: Int] = ["a": 1]
        }

        extension Model: Decodable {
          enum CodingKeys: String, CodingKey {
            case map
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let mapLossyWrapper = (try? container.decodeIfPresent(LossyDictionary<String, Int>.self, forKey: .map)) ?? nil
            if let mapLossyUnwrapped = mapLossyWrapper {
              map = mapLossyUnwrapped.elements
            } else {
              map = ["a": 1]
            }
          }
        }
        """
    )
  }

  @Test func lossyDictionary_combined_with_transcodeRawString() throws {
    assertMacro(
      """
      @Decodable
      public struct Model {
        @CodableKey(options: [.lossy, .transcodeRawString])
        let map: [String: Int]
      }
      """,
      expandedSource: """
        public struct Model {
          let map: [String: Int]
        }

        extension Model: Decodable {
          enum CodingKeys: String, CodingKey {
            case map
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let __ckDecoder = JSONDecoder()
            let mapRawString = try container.decodeIfPresent(String.self, forKey: .map) ?? ""
            if !mapRawString.isEmpty, let mapRawData = mapRawString.data(using: .utf8) {
              let mapLossyWrapper = try __ckDecoder.decode(LossyDictionary<String, Int>.self, from: mapRawData)
              map = mapLossyWrapper.elements
            } else {
              throw DecodingError.valueNotFound(
                String.self,
                DecodingError.Context(
                  codingPath: [CodingKeys.map],
                  debugDescription: "Failed to convert raw string to data"
                )
              )
            }
          }
        }
        """
    )
  }

  @Test func lossyDictionary_combined_with_safeTranscodeRawString() throws {
    assertMacro(
      """
      @Decodable
      public struct Model {
        @CodableKey(options: [.lossy, .safeTranscodeRawString])
        var map: [String: Int] = [:]
      }
      """,
      expandedSource: """
        public struct Model {
          var map: [String: Int] = [:]
        }

        extension Model: Decodable {
          enum CodingKeys: String, CodingKey {
            case map
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let __ckDecoder = JSONDecoder()
            let mapRawString = (try? container.decodeIfPresent(String.self, forKey: .map)) ?? ""
            if !mapRawString.isEmpty, let mapRawData = mapRawString.data(using: .utf8) {
              let mapLossyWrapper = try __ckDecoder.decode(LossyDictionary<String, Int>.self, from: mapRawData)
              map = mapLossyWrapper.elements
            } else {
              map = [:]
            }
          }
        }
        """
    )
  }
}
