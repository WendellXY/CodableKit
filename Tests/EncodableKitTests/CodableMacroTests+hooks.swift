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

@Suite struct EncodableHooksExpansionTests {
  @Test func classWillAndDidEncodeHooksIncludedWhenPresent() throws {
    assertMacro(
      """
      @Encodable
      public class User {
        let id: UUID
        let name: String
        let age: Int

        @CodableHook(.willEncode)
        func prepare() throws {}

        @CodableHook(.didEncode)
        func finish() throws {}
      }
      """,
      expandedSource: """
        public class User {
          let id: UUID
          let name: String
          let age: Int

          @CodableHook(.willEncode)
          func prepare() throws {}

          @CodableHook(.didEncode)
          func finish() throws {}

          public func encode(to encoder: any Encoder) throws {
            try prepare()
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try finish()
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }
        }
        """
    )
  }

  @Test func conventionalWillAndDidEncodeWithoutAnnotationsParameterless() throws {
    assertMacro(
      """
      @Encodable
      public class User {
        let id: UUID
        let name: String
        let age: Int

        func willEncode() throws {}
        func didEncode() throws {}
      }
      """,
      expandedSource: """
        public class User {
          let id: UUID
          let name: String
          let age: Int

          func willEncode() throws {}
          func didEncode() throws {}

          public func encode(to encoder: any Encoder) throws {
            try willEncode()
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try didEncode()
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }
        }
        """
    )
  }
}
