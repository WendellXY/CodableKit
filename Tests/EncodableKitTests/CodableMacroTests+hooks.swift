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
          func prepare() throws {}
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
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
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
      ,
      diagnostics: [
        .init(
          message: "Hook method 'willEncode' will not be invoked unless annotated with @CodableHook(.willEncode)",
          line: 7,
          column: 3,
          severity: .error,
          fixIts: [.init(message: "Insert @CodableHook(.willEncode)")]
        ),
        .init(
          message: "Hook method 'didEncode' will not be invoked unless annotated with @CodableHook(.didEncode)",
          line: 8,
          column: 3,
          severity: .error,
          fixIts: [.init(message: "Insert @CodableHook(.didEncode)")]
        ),
      ],
      applyFixIts: ["Insert @CodableHook(.willEncode)", "Insert @CodableHook(.didEncode)"],
      fixedSource: """
        @Encodable
        public class User {
          let id: UUID
          let name: String
          let age: Int

          @CodableHook(.willEncode)
          func willEncode() throws {}
          @CodableHook(.didEncode)
          func didEncode() throws {}
        }
        """
    )
  }

  @Test func invalidAnnotatedEncodeHookMustBeNonmutating() throws {
    assertMacro(
      """
      @Encodable
      public struct User {
        let id: UUID

        @CodableHook(.willEncode)
        mutating func prepare(to encoder: any Encoder) throws {}
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          mutating func prepare(to encoder: any Encoder) throws {}

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
          }
        }

        extension User: Encodable {
          enum CodingKeys: String, CodingKey {
            case id
          }
        }
        """,
      diagnostics: [
        .init(
          message: "encode hooks must be nonmutating",
          line: 5,
          column: 3
        )
      ]
    )
  }
}
