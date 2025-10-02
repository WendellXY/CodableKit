//
//  CodableMacroTests+class_hooks.swift
//  CodableKit
//
//  Created by AI on 2025/10/02.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite struct CodableHooksExpansionTestsForClass {
  @Test func combinedAnnotatedHooksRunInOrder() throws {
    assertMacro(
      """
      @Codable
      public class User {
        let id: UUID
        let name: String

        @CodableHook(.willDecode)
        class func preA() throws {}
        @CodableHook(.willDecode)
        static func preB(from decoder: any Decoder) throws {}

        @CodableHook(.didDecode)
        func postA() throws {}
        @CodableHook(.didDecode)
        func postB(from decoder: any Decoder) throws {}

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
        public class User {
          let id: UUID
          let name: String

          @CodableHook(.willDecode)
          class func preA() throws {}
          @CodableHook(.willDecode)
          static func preB(from decoder: any Decoder) throws {}

          @CodableHook(.didDecode)
          func postA() throws {}
          @CodableHook(.didDecode)
          func postB(from decoder: any Decoder) throws {}

          @CodableHook(.willEncode)
          func start() throws {}
          @CodableHook(.willEncode)
          func ready(to encoder: any Encoder) throws {}

          @CodableHook(.didEncode)
          func finish() throws {}
          @CodableHook(.didEncode)
          func end(to encoder: any Encoder) throws {}

          public required init(from decoder: any Decoder) throws {
            try Self.preA()
            try Self.preB(from: decoder)
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            try postA()
            try postB(from: decoder)
          }

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
        }
        """
    )
  }

  @Test func annotatedOverridesConventionalForClass() throws {
    assertMacro(
      """
      @Codable
      public class User {
        let id: UUID
        let name: String

        func willEncode() throws {}
        func didEncode() throws {}
        func didDecode() throws {}

        @CodableHook(.willEncode)
        func start() throws {}
        @CodableHook(.didEncode)
        func finish() throws {}
        @CodableHook(.didDecode)
        func post() throws {}
      }
      """,
      expandedSource: """
        public class User {
          let id: UUID
          let name: String

          func willEncode() throws {}
          func didEncode() throws {}
          func didDecode() throws {}

          @CodableHook(.willEncode)
          func start() throws {}
          @CodableHook(.didEncode)
          func finish() throws {}
          @CodableHook(.didDecode)
          func post() throws {}

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            try post()
          }

          public func encode(to encoder: any Encoder) throws {
            try start()
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try finish()
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
          }
        }
        """
    )
  }
}
