//
//  NestedCodableTests.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/7/8.
//

import CodableKitMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Test("Codable macro expands nested coding key paths as expected")
func testNestedCodable() throws {
  assertMacro(
    """
    @Codable
    struct User {
      @CodableKey("data.uid") let id: Int
      @CodableKey("profile.info.name") let name: String
    }
    """,
    expandedSource:
      """
      struct User {
        let id: Int
        let name: String

        internal func encode(to encoder: any Encoder) throws {
          var container = encoder.container(keyedBy: CodingKeys.self)
          var dataContainer = container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
          var profileContainer = container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profile)
          try dataContainer.encode(id, forKey: .id)
          var infoContainer = profileContainer.nestedContainer(keyedBy: InfoKeys.self, forKey: .info)
          try infoContainer.encode(name, forKey: .name)
        }
      }

      extension User: Codable {
        enum CodingKeys: String, CodingKey {
          case data
          case profile
        }
        enum DataKeys: String, CodingKey {
          case id = "uid"
        }
        enum ProfileKeys: String, CodingKey {
          case info
        }
        enum InfoKeys: String, CodingKey {
          case name
        }
        internal init(from decoder: any Decoder) throws {
          let container = try decoder.container(keyedBy: CodingKeys.self)
          let dataContainer = try container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)
          let profileContainer = try container.nestedContainer(keyedBy: ProfileKeys.self, forKey: .profile)
          id = try dataContainer.decode(Int.self, forKey: .id)
          let infoContainer = try profileContainer.nestedContainer(keyedBy: InfoKeys.self, forKey: .info)
          name = try infoContainer.decode(String.self, forKey: .name)
        }
      }
      """
  )
}
