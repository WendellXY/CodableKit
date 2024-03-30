import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(CodableKitMacros)
import CodableKitMacros

let testMacros: [String: Macro.Type] = [
  "Codable": CodableMacro.self
]
#endif

final class CodableKitTests: XCTestCase {
  func testMacro() throws {
    #if canImport(CodableKitMacros)
    assertMacroExpansion(
      """
      @Codable
      struct User {
          let id: UUID
          let name: String
          var age: Int = 24
      }
      """,
      expandedSource: """
        struct User {
            let id: UUID
            let name: String
            var age: Int = 24
        }

        extension User: Codable {
            enum CodingKeys: String, CodingKey {
                case id
                case name
                case age
            }
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(UUID.self, forKey: .id)
                name = try container.decode(String.self, forKey: .name)
                age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 24
            }
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(id, forKey: .id)
                try container.encode(name, forKey: .name)
                try container.encode(age, forKey: .age)
            }
        }
        """,
      macros: testMacros
    )
    #else
    throw XCTSkip("macros are only supported when running tests for the host platform")
    #endif
  }
}
