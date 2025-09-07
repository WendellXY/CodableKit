//
//  CodingTransformerEncodeTests.swift
//  Encodable macro expansion tests for transformer encode paths
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite struct CodingTransformerEncodeMacroTests {
  @Test func transformer_nonOptional_encodes_via_helper() throws {
    assertMacro(
      """
      struct IntFromString: BidirectionalCodingTransformer {
        func transform(_ input: Result<String, any Error>) -> Result<Int, any Error> { input.map { Int($0) ?? 0 } }
        func reverseTransform(_ input: Result<Int, any Error>) -> Result<String, any Error> { input.map(String.init) }
      }
      @Encodable
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
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try __ckEncodeTransformed(transformer: IntFromString(), value: count, into: &container, forKey: .count)
            try didEncode(to: encoder)
          }
        }

        extension Model: Encodable {
          enum CodingKeys: String, CodingKey {
            case count
          }
        }
        """
    )
  }

  @Test func transformer_optional_encodes_if_present_and_explicitNil_false() throws {
    assertMacro(
      """
      struct IntFromString: BidirectionalCodingTransformer {
        func transform(_ input: Result<String, any Error>) -> Result<Int, any Error> { input.map { Int($0) ?? 0 } }
        func reverseTransform(_ input: Result<Int, any Error>) -> Result<String, any Error> { input.map(String.init) }
      }
      @Encodable
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
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try __ckEncodeTransformedIfPresent(transformer: IntFromString(), value: count, into: &container, forKey: .count, explicitNil: false)
            try didEncode(to: encoder)
          }
        }

        extension Model: Encodable {
          enum CodingKeys: String, CodingKey {
            case count
          }
        }
        """
    )
  }

  @Test func transformer_optional_encodes_explicit_nil_when_enabled() throws {
    assertMacro(
      """
      struct IntFromString: BidirectionalCodingTransformer {
        func transform(_ input: Result<String, any Error>) -> Result<Int, any Error> { input.map { Int($0) ?? 0 } }
        func reverseTransform(_ input: Result<Int, any Error>) -> Result<String, any Error> { input.map(String.init) }
      }
      @Encodable
      public struct Model {
        @CodableKey(options: .explicitNil, transformer: IntFromString())
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
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try __ckEncodeTransformedIfPresent(transformer: IntFromString(), value: count, into: &container, forKey: .count, explicitNil: true)
            try didEncode(to: encoder)
          }
        }

        extension Model: Encodable {
          enum CodingKeys: String, CodingKey {
            case count
          }
        }
        """
    )
  }
}
