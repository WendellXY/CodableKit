//
//  CodableMacroTests+derived.swift
//  CodableKitTests
//
//  Expansion and diagnostics tests for @DerivedKey
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite struct DerivedKeyExpansionTests {
  @Test func basicDerivedProperty_noCodingKey_noEncode_tailAssignment() throws {
    assertMacro(
      """
      @Codable
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

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(userConfigValue, forKey: .userConfigValue)
          }
        }

        extension UserCommonConfigInfo: Codable {
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

  @Test func derivedProperty_nonOptionalWithDefault_fallsBackToDefault() throws {
    assertMacro(
      """
      @Codable
      public struct TagBox {
        var tags: [String] = []
        @DerivedKey(from: "tags", transformer: CountTransformer())
        var tagCount: Int = 0
      }
      """,
      expandedSource: """
        public struct TagBox {
          var tags: [String] = []
          var tagCount: Int = 0

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(tags, forKey: .tags)
          }
        }

        extension TagBox: Codable {
          enum CodingKeys: String, CodingKey {
            case tags
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
            tagCount = (try? __ckDecodeDerived(transformer: CountTransformer(), from: tags)) ?? 0
          }
        }
        """
    )
  }

  @Test func derivedProperty_nonOptionalWithoutDefault_propagatesErrors() throws {
    assertMacro(
      """
      @Codable
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

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(tags, forKey: .tags)
          }
        }

        extension TagBox: Codable {
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

  @Test func multipleDerivedProperties_assignedInDeclarationOrder_beforeDidDecodeHook() throws {
    assertMacro(
      """
      @Codable
      public struct UserCommonConfigInfo {
        public var userConfigValue: [String: String]?
        @DerivedKey(from: "userConfigValue", transformer: FrameTransformer())
        public private(set) var avatarFrame: AvatarFrame?
        @DerivedKey(from: "userConfigValue", transformer: BadgeTransformer())
        public private(set) var badge: Badge?

        @CodableHook(.didDecode)
        mutating func didDecode() throws {}
      }
      """,
      expandedSource: """
        public struct UserCommonConfigInfo {
          public var userConfigValue: [String: String]?
          public private(set) var avatarFrame: AvatarFrame?
          public private(set) var badge: Badge?

          @CodableHook(.didDecode)
          mutating func didDecode() throws {}

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(userConfigValue, forKey: .userConfigValue)
          }
        }

        extension UserCommonConfigInfo: Codable {
          enum CodingKeys: String, CodingKey {
            case userConfigValue
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            userConfigValue = try container.decodeIfPresent([String: String]?.self, forKey: .userConfigValue) ?? nil
            avatarFrame = (try? __ckDecodeDerived(transformer: FrameTransformer(), from: userConfigValue)) ?? nil
            badge = (try? __ckDecodeDerived(transformer: BadgeTransformer(), from: userConfigValue)) ?? nil
            try didDecode()
          }
        }
        """
    )
  }

  @Test func derivedProperty_inClassWithoutSuperclass() throws {
    assertMacro(
      """
      @Codable
      public class ConfigClass {
        public var userConfigValue: [String: String]?
        @DerivedKey(from: "userConfigValue", transformer: FrameTransformer())
        public private(set) var avatarFrame: AvatarFrame?
      }
      """,
      expandedSource: """
        public class ConfigClass {
          public var userConfigValue: [String: String]?
          public private(set) var avatarFrame: AvatarFrame?

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            userConfigValue = try container.decodeIfPresent([String: String]?.self, forKey: .userConfigValue) ?? nil
            avatarFrame = (try? __ckDecodeDerived(transformer: FrameTransformer(), from: userConfigValue)) ?? nil
          }

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(userConfigValue, forKey: .userConfigValue)
          }
        }

        extension ConfigClass: Codable {
          enum CodingKeys: String, CodingKey {
            case userConfigValue
          }
        }
        """
    )
  }

  @Test func derivedProperty_inSubclass_assignedBeforeSuperInit() throws {
    assertMacro(
      """
      @Codable
      public class ChildConfig: BaseConfig {
        public var userConfigValue: [String: String]?
        @DerivedKey(from: "userConfigValue", transformer: FrameTransformer())
        public private(set) var avatarFrame: AvatarFrame?
      }
      """,
      expandedSource: """
        public class ChildConfig: BaseConfig {
          public var userConfigValue: [String: String]?
          public private(set) var avatarFrame: AvatarFrame?

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            userConfigValue = try container.decodeIfPresent([String: String]?.self, forKey: .userConfigValue) ?? nil
            avatarFrame = (try? __ckDecodeDerived(transformer: FrameTransformer(), from: userConfigValue)) ?? nil
            try super.init(from: decoder)
          }

          public override func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(userConfigValue, forKey: .userConfigValue)
            try super.encode(to: encoder)
          }
        }

        extension ChildConfig {
          enum CodingKeys: String, CodingKey {
            case userConfigValue
          }
        }
        """
    )
  }
}

@Suite struct DerivedKeyDiagnosticsTests {
  @Test func derivedKeyCombinedWithCodableKeyIsAnError() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: Int
        @DerivedKey(from: "id", transformer: StringifyTransformer())
        @CodableKey("display")
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

  @Test func derivedKeyCombinedWithDecodableKeyIsAnError() throws {
    assertMacro(
      """
      @Codable
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

  @Test func derivedKeyCombinedWithEncodableKeyIsAnError() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: Int
        @DerivedKey(from: "id", transformer: StringifyTransformer())
        @EncodableKey("display")
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

  @Test func derivedKeySourcePropertyMustExist() throws {
    assertMacro(
      """
      @Codable
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

  @Test func derivedKeyNamingASuperclassPropertyIsAnError() throws {
    assertMacro(
      """
      @Codable
      public class ChildConfig: BaseConfig {
        var tags: [String] = []
        @DerivedKey(from: "base", transformer: FrameTransformer())
        var derivedValue: String?
      }
      """,
      expandedSource: """
        public class ChildConfig: BaseConfig {
          var tags: [String] = []
          var derivedValue: String?
        }
        """,
      diagnostics: [
        .init(
          message:
            "@DerivedKey source property 'base' does not exist as a stored property of this type; inherited properties are not supported as 'from:' sources",
          line: 4,
          column: 3
        )
      ]
    )
  }

  @Test func derivedKeyWithNonStringLiteralFromIsAnError() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: Int
        @DerivedKey(from: sourceName, transformer: StringifyTransformer())
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
            "@DerivedKey requires a 'from:' argument that is a non-empty string literal naming a sibling stored property",
          line: 4,
          column: 3
        )
      ]
    )
  }

  @Test func derivedKeyOnLetWithInitializerIsAnError() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: Int
        @DerivedKey(from: "id", transformer: StringifyTransformer())
        let display: String = "none"
      }
      """,
      expandedSource: """
        public struct User {
          let id: Int
          let display: String = "none"

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
          }
        }
        """,
      diagnostics: [
        .init(
          message:
            "@DerivedKey cannot be applied to a 'let' property with an initializer; use 'var' or remove the initializer",
          line: 4,
          column: 3
        )
      ]
    )
  }

  @Test func derivedKeyOnStaticPropertyIsAnError() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: Int
        @DerivedKey(from: "id", transformer: StringifyTransformer())
        static var display: String? = nil
      }
      """,
      expandedSource: """
        public struct User {
          let id: Int
          static var display: String? = nil

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
          }
        }
        """,
      diagnostics: [
        .init(message: "Only non-static variable declarations are supported", line: 4, column: 3)
      ]
    )
  }

  @Test func derivedKeyOnComputedPropertyIsAnError() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: Int
        @DerivedKey(from: "id", transformer: StringifyTransformer())
        var display: String {
          "user-\\(id)"
        }
      }
      """,
      expandedSource: """
        public struct User {
          let id: Int
          var display: String {
            "user-\\(id)"
          }

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
          }
        }
        """,
      diagnostics: [
        .init(message: "Only variable declarations with no accessor block are supported", line: 4, column: 3)
      ]
    )
  }

  @Test func derivedKeyInEncodableOnlyTypeIsAnError() throws {
    assertMacro(
      """
      @Encodable
      public struct User {
        let id: Int
        @DerivedKey(from: "id", transformer: StringifyTransformer())
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
            "@DerivedKey is decode-only and cannot be used in an @Encodable-only type; use @Codable or @Decodable",
          line: 4,
          column: 3
        )
      ]
    )
  }

  @Test func derivedKeyFromAnotherDerivedPropertyIsAnError() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: Int
        @DerivedKey(from: "id", transformer: StringifyTransformer())
        var display: String?
        @DerivedKey(from: "display", transformer: CountTransformer())
        var displayLength: Int?
      }
      """,
      expandedSource: """
        public struct User {
          let id: Int
          var display: String?
          var displayLength: Int?
        }
        """,
      diagnostics: [
        .init(
          message:
            "@DerivedKey source property 'display' is itself derived; derived properties may only depend on coded properties",
          line: 6,
          column: 3
        )
      ]
    )
  }

  @Test func derivedKeyFromIgnoredPropertyIsAnError() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: Int
        @CodableKey(options: .ignored)
        var cache: String = ""
        @DerivedKey(from: "cache", transformer: CountTransformer())
        var cacheLength: Int?
      }
      """,
      expandedSource: """
        public struct User {
          let id: Int
          var cache: String = ""
          var cacheLength: Int?
        }
        """,
      diagnostics: [
        .init(
          message:
            "@DerivedKey source property 'cache' is excluded from decoding (.ignored); derived properties may only depend on decoded properties",
          line: 6,
          column: 3
        )
      ]
    )
  }
}
