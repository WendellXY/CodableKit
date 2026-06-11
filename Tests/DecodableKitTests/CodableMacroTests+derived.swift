//
//  CodableMacroTests+derived.swift
//  DecodableKitTests
//
//  Expansion tests for @DerivedKey under @Decodable
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite struct DecodableDerivedKeyExpansionTests {
  @Test func basicDerivedProperty_noCodingKey_tailAssignment() throws {
    assertMacro(
      """
      @Decodable
      public struct UserCommonConfigInfo {
        public var userConfigValue: [String: String]?
        @DerivedKey(from: "userConfigValue", transformer: FrameTransformer())
        public private(set) var avatarFrame: AvatarFrame?
      }
      """,
      expandedSource: """
        public struct UserCommonConfigInfo {
          public var userConfigValue: [String: String]?
          public private(set) var avatarFrame: AvatarFrame?
        }

        extension UserCommonConfigInfo: Decodable {
          enum CodingKeys: String, CodingKey {
            case userConfigValue
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            userConfigValue = try container.decodeIfPresent([String: String]?.self, forKey: .userConfigValue) ?? nil
            avatarFrame = (try? __ckDecodeDerived(transformer: FrameTransformer(), from: userConfigValue)) ?? nil
          }
        }
        """
    )
  }

  @Test func derivedProperty_nonOptionalWithoutDefault_propagatesErrors() throws {
    assertMacro(
      """
      @Decodable
      public struct TagBox {
        var tags: [String] = []
        @DerivedKey(from: "tags", transformer: CountTransformer())
        var tagCount: Int
      }
      """,
      expandedSource: """
        public struct TagBox {
          var tags: [String] = []
          var tagCount: Int
        }

        extension TagBox: Decodable {
          enum CodingKeys: String, CodingKey {
            case tags
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
            tagCount = try __ckDecodeDerived(transformer: CountTransformer(), from: tags)
          }
        }
        """
    )
  }

  @Test func multipleDerivedProperties_assignedInDeclarationOrder() throws {
    assertMacro(
      """
      @Decodable
      public struct UserCommonConfigInfo {
        public var userConfigValue: [String: String]?
        @DerivedKey(from: "userConfigValue", transformer: FrameTransformer())
        public private(set) var avatarFrame: AvatarFrame?
        @DerivedKey(from: "userConfigValue", transformer: BadgeTransformer())
        public private(set) var badge: Badge?
      }
      """,
      expandedSource: """
        public struct UserCommonConfigInfo {
          public var userConfigValue: [String: String]?
          public private(set) var avatarFrame: AvatarFrame?
          public private(set) var badge: Badge?
        }

        extension UserCommonConfigInfo: Decodable {
          enum CodingKeys: String, CodingKey {
            case userConfigValue
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            userConfigValue = try container.decodeIfPresent([String: String]?.self, forKey: .userConfigValue) ?? nil
            avatarFrame = (try? __ckDecodeDerived(transformer: FrameTransformer(), from: userConfigValue)) ?? nil
            badge = (try? __ckDecodeDerived(transformer: BadgeTransformer(), from: userConfigValue)) ?? nil
          }
        }
        """
    )
  }
}

@Suite struct DecodableDerivedKeyDiagnosticsTests {
  @Test func derivedKeySourcePropertyMustExist() throws {
    assertMacro(
      """
      @Decodable
      public struct User {
        let id: Int
        @DerivedKey(from: "missing", transformer: StringifyTransformer())
        var display: String?
      }
      """,
      expandedSource: """
        public struct User {
          let id: Int
          var display: String?
        }
        """,
      diagnostics: [
        .init(
          message:
            "@DerivedKey source property 'missing' does not exist as a stored property of this type; inherited properties are not supported as 'from:' sources",
          line: 4,
          column: 3
        )
      ]
    )
  }

  @Test func derivedKeyCombinedWithDecodableKeyIsAnError() throws {
    assertMacro(
      """
      @Decodable
      public struct User {
        let id: Int
        @DerivedKey(from: "id", transformer: StringifyTransformer())
        @DecodableKey("display")
        var display: String?
      }
      """,
      expandedSource: """
        public struct User {
          let id: Int
          var display: String?
        }
        """,
      diagnostics: [
        .init(
          message:
            "@DerivedKey cannot be combined with @CodableKey, @DecodableKey, or @EncodableKey on the same property",
          line: 4,
          column: 3
        )
      ]
    )
  }
}
