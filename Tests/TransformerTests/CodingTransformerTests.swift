//
//  CodingTransformerTests.swift
//  CodableKitTests
//
//  Created by Assistant on 2025/9/6.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite struct CodingTransformerMacroTests {
  @Test func transformer_nonOptional_roundTrip() throws {
    assertMacro(
      """
      struct IntFromString: BidirectionalCodingTransformer {
        func transform(_ input: Result<String, any Error>) -> Result<Int, any Error> { input.map { Int($0) ?? 0 } }
        func reverseTransform(_ input: Result<Int, any Error>) -> Result<String, any Error> { input.map(String.init) }
      }
      @Codable
      public struct Model {
        @CodableKey(transformer: IntFromString())
        var count: Int
      }
      """,
      expandedSource: """
        struct IntFromString: BidirectionalCodingTransformer {
          func transform(_ input: Result<String, any Error>) -> Result<Int, any Error> { input.map { Int($0) ?? 0 } }
          func reverseTransform(_ input: Result<Int, any Error>) -> Result<String, any Error> { input.map(String.init) }
        }
        public struct Model {
          var count: Int

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try __ckEncodeTransformed(transformer: IntFromString(), value: count, into: &container, forKey: .count)
          }
        }

        extension Model: Codable {
          enum CodingKeys: String, CodingKey {
            case count
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            count = try __ckDecodeTransformed(transformer: IntFromString(), from: container, forKey: .count, useDefaultOnFailure: false)
          }
        }
        """
    )
  }

  @Test func transformer_optional_encodeIfPresent() throws {
    assertMacro(
      """
      struct IntFromString: BidirectionalCodingTransformer {
        func transform(_ input: Result<String, any Error>) -> Result<Int, any Error> { input.map { Int($0) ?? 0 } }
        func reverseTransform(_ input: Result<Int, any Error>) -> Result<String, any Error> { input.map(String.init) }
      }
      @Codable
      public struct Model {
        @CodableKey(transformer: IntFromString())
        var count: Int?
      }
      """,
      expandedSource: """
        struct IntFromString: BidirectionalCodingTransformer {
          func transform(_ input: Result<String, any Error>) -> Result<Int, any Error> { input.map { Int($0) ?? 0 } }
          func reverseTransform(_ input: Result<Int, any Error>) -> Result<String, any Error> { input.map(String.init) }
        }
        public struct Model {
          var count: Int?

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try __ckEncodeTransformedIfPresent(transformer: IntFromString(), value: count, into: &container, forKey: .count, explicitNil: false)
          }
        }

        extension Model: Codable {
          enum CodingKeys: String, CodingKey {
            case count
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            count = try __ckDecodeTransformedIfPresent(transformer: IntFromString(), from: container, forKey: .count, useDefaultOnFailure: false)
          }
        }
        """
    )
  }

  @Test func transformer_nonOptional_withDefault_and_useDefaultOnFailure() throws {
    assertMacro(
      """
      struct IntFromString: BidirectionalCodingTransformer {
        func transform(_ input: Result<String, any Error>) -> Result<Int, any Error> { input.map { Int($0) ?? 0 } }
        func reverseTransform(_ input: Result<Int, any Error>) -> Result<String, any Error> { input.map(String.init) }
      }
      @Codable
      public struct Model {
        @CodableKey(options: .useDefaultOnFailure, transformer: IntFromString())
        var count: Int = 42
      }
      """,
      expandedSource: """
        struct IntFromString: BidirectionalCodingTransformer {
          func transform(_ input: Result<String, any Error>) -> Result<Int, any Error> { input.map { Int($0) ?? 0 } }
          func reverseTransform(_ input: Result<Int, any Error>) -> Result<String, any Error> { input.map(String.init) }
        }
        public struct Model {
          var count: Int = 42

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try __ckEncodeTransformed(transformer: IntFromString(), value: count, into: &container, forKey: .count)
          }
        }

        extension Model: Codable {
          enum CodingKeys: String, CodingKey {
            case count
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            count = (try __ckDecodeTransformedIfPresent(transformer: IntFromString(), from: container, forKey: .count, useDefaultOnFailure: true, defaultValue: 42)) ?? 42
          }
        }
        """
    )
  }
}
