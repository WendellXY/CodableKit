//
//  CodableMacroTests+hooks.swift
//  CodableKit
//
//  Created by AI on 2025/10/02.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite struct DecodableHooksExpansionTests {
  @Test func staticWillDecodeHookIncludedBeforeDecoding() throws {
    assertMacro(
      """
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        let age: Int

        @CodableHook(.willDecode)
        static func pre(from decoder: any Decoder) throws {}
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          let age: Int

          @CodableHook(.willDecode)
          static func pre(from decoder: any Decoder) throws {}
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            try Self.pre(from: decoder)
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
          }
        }
        """
    )
  }
  @Test func structDidDecodeHookIncludedWhenPresent() throws {
    assertMacro(
      """
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        var age: Int

        @CodableHook(.didDecode)
        mutating func post() throws { age += 1 }
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age: Int

          @CodableHook(.didDecode)
          mutating func post() throws { age += 1 }
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
            try post()
          }
        }
        """
    )
  }

  @Test func staticWillDecodeHookWithoutParamsIncluded() throws {
    assertMacro(
      """
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        let age: Int

        @CodableHook(.willDecode)
        static func pre() throws {}
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          let age: Int

          @CodableHook(.willDecode)
          static func pre() throws {}
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            try Self.pre()
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
          }
        }
        """
    )
  }

  @Test func conventionalDidDecodeWithoutAnnotationParameterless() throws {
    assertMacro(
      """
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        let age: Int

        mutating func didDecode() throws {}
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          let age: Int

          mutating func didDecode() throws {}
        }

        extension User: Decodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decode(Int.self, forKey: .age)
          }
        }
        """
      ,
      diagnostics: [
        .init(
          message: "Hook method 'didDecode' will not be invoked unless annotated with @CodableHook(.didDecode)",
          line: 1,
          column: 1,
          severity: .error
        )
      ]
    )
  }
}
