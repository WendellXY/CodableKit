//
//  TypeInferenceTests.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/9/5.
//

import CodableKitMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite("Type Inference Tests")
struct TypeInferenceTests {
  @Test("Type Inference for literals")
  func testTypeInferenceForLiterals() async throws {
    assertMacro(
      """
      @Codable
      public struct User {
        var strLiteral = "Hello"
        var intLiteral = 123
        var doubleLiteral = 123.456
        var boolLiteral = true
      }
      """,
      expandedSource:
        """
        public struct User {
          var strLiteral = "Hello"
          var intLiteral = 123
          var doubleLiteral = 123.456
          var boolLiteral = true

          public func encode(to encoder: any Encoder) throws {
            try willEncode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(strLiteral , forKey: .strLiteral )
            try container.encode(intLiteral , forKey: .intLiteral )
            try container.encode(doubleLiteral , forKey: .doubleLiteral )
            try container.encode(boolLiteral , forKey: .boolLiteral )
            try didEncode(to: encoder)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case strLiteral
            case intLiteral
            case doubleLiteral
            case boolLiteral
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            strLiteral  = try container.decodeIfPresent(String.self, forKey: .strLiteral ) ?? "Hello"
            intLiteral  = try container.decodeIfPresent(Int.self, forKey: .intLiteral ) ?? 123
            doubleLiteral  = try container.decodeIfPresent(Double.self, forKey: .doubleLiteral ) ?? 123.456
            boolLiteral  = try container.decodeIfPresent(Bool.self, forKey: .boolLiteral ) ?? true
            try didDecode(from: decoder)
          }
        }
        """
    )
  }
}
