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
  @Test func structDidDecodeHookIncludedWhenPresent() throws {
    assertMacro(
      """
      @Decodable
      public struct User {
        let id: UUID
        let name: String
        var age: Int

        mutating func didDecode(from decoder: any Decoder) throws {
          age += 1
        }
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age: Int

          mutating func didDecode(from decoder: any Decoder) throws {
            age += 1
          }
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
            try didDecode(from: decoder)
          }
        }
        """
    )
  }
}

