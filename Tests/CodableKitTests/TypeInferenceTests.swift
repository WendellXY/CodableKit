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
        var negativeIntLiteral = -123
        var negativeDoubleLiteral = -123.456
      }
      """,
      expandedSource:
        """
        public struct User {
          var strLiteral = "Hello"
          var intLiteral = 123
          var doubleLiteral = 123.456
          var boolLiteral = true
          var negativeIntLiteral = -123
          var negativeDoubleLiteral = -123.456

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(strLiteral, forKey: .strLiteral)
            try container.encode(intLiteral, forKey: .intLiteral)
            try container.encode(doubleLiteral, forKey: .doubleLiteral)
            try container.encode(boolLiteral, forKey: .boolLiteral)
            try container.encode(negativeIntLiteral, forKey: .negativeIntLiteral)
            try container.encode(negativeDoubleLiteral, forKey: .negativeDoubleLiteral)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case strLiteral
            case intLiteral
            case doubleLiteral
            case boolLiteral
            case negativeIntLiteral
            case negativeDoubleLiteral
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            strLiteral = try container.decodeIfPresent(String.self, forKey: .strLiteral) ?? "Hello"
            intLiteral = try container.decodeIfPresent(Int.self, forKey: .intLiteral) ?? 123
            doubleLiteral = try container.decodeIfPresent(Double.self, forKey: .doubleLiteral) ?? 123.456
            boolLiteral = try container.decodeIfPresent(Bool.self, forKey: .boolLiteral) ?? true
            negativeIntLiteral = try container.decodeIfPresent(Int.self, forKey: .negativeIntLiteral) ?? -123
            negativeDoubleLiteral = try container.decodeIfPresent(Double.self, forKey: .negativeDoubleLiteral) ?? -123.456
          }
        }
        """
    )
  }

  @Test("Type Inference for arrays")
  func testTypeInferenceForArrays() async throws {
    assertMacro(
      """
      @Codable
      public struct User {
        var arrayLiteral = [1, 2, 3]
        var stringArrayLiteral = ["Hello", "World"]
        var boolArrayLiteral = [true, false]
        var doubleArrayLiteral = [1.0, 2.0, 3.0]
        var numberArrayLiteral = [1, 2.0, 3]
      }
      """,
      expandedSource:
        """
        public struct User {
          var arrayLiteral = [1, 2, 3]
          var stringArrayLiteral = ["Hello", "World"]
          var boolArrayLiteral = [true, false]
          var doubleArrayLiteral = [1.0, 2.0, 3.0]
          var numberArrayLiteral = [1, 2.0, 3]

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(arrayLiteral, forKey: .arrayLiteral)
            try container.encode(stringArrayLiteral, forKey: .stringArrayLiteral)
            try container.encode(boolArrayLiteral, forKey: .boolArrayLiteral)
            try container.encode(doubleArrayLiteral, forKey: .doubleArrayLiteral)
            try container.encode(numberArrayLiteral, forKey: .numberArrayLiteral)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case arrayLiteral
            case stringArrayLiteral
            case boolArrayLiteral
            case doubleArrayLiteral
            case numberArrayLiteral
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            arrayLiteral = try container.decodeIfPresent([Int].self, forKey: .arrayLiteral) ?? [1, 2, 3]
            stringArrayLiteral = try container.decodeIfPresent([String].self, forKey: .stringArrayLiteral) ?? ["Hello", "World"]
            boolArrayLiteral = try container.decodeIfPresent([Bool].self, forKey: .boolArrayLiteral) ?? [true, false]
            doubleArrayLiteral = try container.decodeIfPresent([Double].self, forKey: .doubleArrayLiteral) ?? [1.0, 2.0, 3.0]
            numberArrayLiteral = try container.decodeIfPresent([Double].self, forKey: .numberArrayLiteral) ?? [1, 2.0, 3]
          }
        }
        """
    )
  }
}
