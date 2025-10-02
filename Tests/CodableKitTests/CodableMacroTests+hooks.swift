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

@Suite struct CodableHooksExpansionTestsForStruct {
  @Test func combinedAnnotatedHooksRunInOrder() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: UUID
        let name: String

        @CodableHook(.willDecode)
        static func pre1() throws {}
        @CodableHook(.willDecode)
        static func pre2(from decoder: any Decoder) throws {}
        @CodableHook(.didDecode)
        mutating func post1() throws {}
        @CodableHook(.didDecode)
        mutating func post2(from decoder: any Decoder) throws {}
        @CodableHook(.willEncode)
        func start() throws {}
        @CodableHook(.willEncode)
        func ready(to encoder: any Encoder) throws {}
        @CodableHook(.didEncode)
        func finish() throws {}
        @CodableHook(.didEncode)
        func end(to encoder: any Encoder) throws {}
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String

          @CodableHook(.willDecode)
          static func pre1() throws {}
          @CodableHook(.willDecode)
          static func pre2(from decoder: any Decoder) throws {}
          @CodableHook(.didDecode)
          mutating func post1() throws {}
          @CodableHook(.didDecode)
          mutating func post2(from decoder: any Decoder) throws {}
          @CodableHook(.willEncode)
          func start() throws {}
          @CodableHook(.willEncode)
          func ready(to encoder: any Encoder) throws {}
          @CodableHook(.didEncode)
          func finish() throws {}
          @CodableHook(.didEncode)
          func end(to encoder: any Encoder) throws {}

          public func encode(to encoder: any Encoder) throws {
            try start()
            try ready(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try finish()
            try end(to: encoder)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
          }

          public init(from decoder: any Decoder) throws {
            try Self.pre1()
            try Self.pre2(from: decoder)
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            try post1()
            try post2(from: decoder)
          }
        }
        """
    )
  }
}
