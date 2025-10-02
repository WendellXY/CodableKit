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
        func prepare(to encoder: any Encoder) throws {}

        @CodableHook(.didEncode)
        func finish(to encoder: any Encoder) throws {}
      }
      """,
      expandedSource: """
        public class User {
          let id: UUID
          let name: String
          let age: Int

          @CodableHook(.willEncode)
          func prepare(to encoder: any Encoder) throws {}

          @CodableHook(.didEncode)
          func finish(to encoder: any Encoder) throws {}

          public func encode(to encoder: any Encoder) throws {
            try prepare(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
            try finish(to: encoder)
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
