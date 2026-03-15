//
//  CodableMacroTests+Diagnostics.swift
//  CodableKit
//
//  Created by WendellXY on 2024/5/27
//  Copyright © 2024 WendellXY. All rights reserved.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite struct CodableKitDiagnosticsTests {
  @Test func macroWithNoTypeAnnotation() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: UUID
        let name: String
        var age = genSomeThing()
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age = genSomeThing()
        }
        """,
      diagnostics: [
        .init(message: "Properties must have a type annotation", line: 1, column: 1)
      ]
    )
  }

  @Test func codableWarnsWhenRedundantlyDeclaringEncodableOrDecodable() throws {
    assertMacro(
      """
      @Codable
      public struct User: Encodable {
        let id: UUID
      }
      """,
      expandedSource:
        "public struct User: Encodable {\n"
        + "  let id: UUID\n"
        + "\n"
        + "  public func encode(to encoder: any Encoder) throws {\n"
        + "    var container = encoder.container(keyedBy: CodingKeys.self)\n"
        + "    try container.encode(id, forKey: .id)\n"
        + "  }\n"
        + "}\n"
        + "\n"
        + "extension User: Codable {\n"
        + "  enum CodingKeys: String, CodingKey {\n"
        + "    case id\n"
        + "  }\n"
        + "\n"
        + "  public init(from decoder: any Decoder) throws {\n"
        + "    let container = try decoder.container(keyedBy: CodingKeys.self)\n"
        + "    id = try container.decode(UUID.self, forKey: .id)\n"
        + "  }\n"
        + "}\n",
      diagnostics: [
        .init(
          message: "Conformance 'Encodable' is redundant when using @Codable",
          line: 1,
          column: 1,
          severity: .warning
        )
      ]
    )
  }

  @Test func macroWithIgnoredPropertyTypeAnnotation() throws {

    assertMacro(
      """
      @Codable
      public struct User {
        let id: UUID
        let name: String
        let age: Int
        @CodableKey(options: .ignored)
        var ignored: String = "Hello World"
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          let age: Int
          var ignored: String = "Hello World"

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
          }
        }

        extension User: Codable {
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
          }
        }
        """
    )

  }

  @Test func macroWarnsWhenLossyUsedOnUnsupportedType() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        @CodableKey(options: .lossy)
        let id: Int
      }
      """,
      expandedSource:
        "public struct User {\n"
        + "  let id: Int\n"
        + "\n"
        + "  public func encode(to encoder: any Encoder) throws {\n"
        + "    var container = encoder.container(keyedBy: CodingKeys.self)\n"
        + "    try container.encode(id, forKey: .id)\n"
        + "  }\n"
        + "}\n"
        + "\n"
        + "extension User: Codable {\n"
        + "  enum CodingKeys: String, CodingKey {\n"
        + "    case id\n"
        + "  }\n"
        + "\n"
        + "  public init(from decoder: any Decoder) throws {\n"
        + "    let container = try decoder.container(keyedBy: CodingKeys.self)\n"
        + "  }\n"
        + "}\n",
      diagnostics: [
        .init(
          message: "Option '.lossy' supports only Array<T>, Set<T>, or Dictionary<K, V> properties",
          line: 3,
          column: 3,
          severity: .warning
        )
      ]
    )
  }

  @Test func macroWarnsOnInvalidCustomKeyPath() throws {
    assertMacro(
      """
      @Codable
      public struct User {
        @CodableKey("data..id")
        let id: Int
      }
      """,
      expandedSource:
        "public struct User {\n"
        + "  let id: Int\n"
        + "\n"
        + "  public func encode(to encoder: any Encoder) throws {\n"
        + "    var container = encoder.container(keyedBy: CodingKeys.self)\n"
        + "    var dataContainer = container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)\n"
        + "    try dataContainer.encode(id, forKey: .id)\n"
        + "  }\n"
        + "}\n"
        + "\n"
        + "extension User: Codable {\n"
        + "  enum CodingKeys: String, CodingKey {\n"
        + "    case data\n"
        + "  }\n"
        + "  enum DataKeys: String, CodingKey {\n"
        + "    case id\n"
        + "  }\n"
        + "\n"
        + "  public init(from decoder: any Decoder) throws {\n"
        + "    let container = try decoder.container(keyedBy: CodingKeys.self)\n"
        + "    let dataContainer = try container.nestedContainer(keyedBy: DataKeys.self, forKey: .data)\n"
        + "    id = try dataContainer.decode(Int.self, forKey: .id)\n"
        + "  }\n"
        + "}\n",
      diagnostics: [
        .init(
          message: "Custom Codable key path 'data..id' is invalid; empty path segments are not allowed",
          line: 3,
          column: 3,
          severity: .warning
        )
      ]
    )
  }

  @Test func macroSuggestsSkipSuperCodingForInheritedTypes() throws {
    assertMacro(
      """
      @Codable
      public class User: NSObject {
        let id: UUID
      }
      """,
      expandedSource: """
        public class User: NSObject {
          let id: UUID

          public required init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            try super.init(from: decoder)
          }

          public override func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try super.encode(to: encoder)
          }
        }

        extension User {
          enum CodingKeys: String, CodingKey {
            case id
          }
        }
        """,
      diagnostics: [
        .init(
          message: "If the inherited type is not Codable, add '.skipSuperCoding' to avoid generating super encode/decode calls",
          line: 1,
          column: 1,
          severity: .warning,
          fixIts: [.init(message: "Add .skipSuperCoding to macro options")]
        )
      ],
      applyFixIts: ["Add .skipSuperCoding to macro options"],
      fixedSource: """
        @Codable(options: .skipSuperCoding)
        public class User: NSObject {
          let id: UUID
        }
        """
    )
  }

  @Test func macroWithStaticTypeAnnotation() throws {

    assertMacro(
      """
      @Codable
      public struct User {
        let id: UUID
        let name: String
        let age: Int

        static let staticProperty = "Hello World"
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          let age: Int

          static let staticProperty = "Hello World"

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
          }
        }

        extension User: Codable {
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
          }
        }
        """
    )

  }

  @Test func macroOnComputeProperty() throws {

    assertMacro(
      """
      @Codable
      public struct User {
        let id: UUID
        let name: String
        var age: Int = 24
        @CodableKey("hello")
        var address: String {
          "A"
        }
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age: Int = 24
          var address: String {
            "A"
          }

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 24
          }
        }
        """,
      diagnostics: [
        .init(message: "Only variable declarations with no accessor block are supported", line: 6, column: 3)
      ]
    )

  }

  @Test func macroOnStaticComputeProperty() throws {

    assertMacro(
      """
      @Codable
      public struct User {
        let id: UUID
        let name: String
        var age: Int = 24
        @CodableKey("hello")
        static var address: String {
          "A"
        }
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age: Int = 24
          static var address: String {
            "A"
          }

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 24
          }
        }
        """,
      diagnostics: [
        .init(message: "Only variable declarations with no accessor block are supported", line: 6, column: 3)
      ]
    )

  }

  @Test func macroOnStaticProperty() throws {

    assertMacro(
      """
      @Codable
      public struct User {
        let id: UUID
        let name: String
        var age: Int = 24
        @CodableKey("hello")
        static var address: String = "A"
      }
      """,
      expandedSource: """
        public struct User {
          let id: UUID
          let name: String
          var age: Int = 24
          static var address: String = "A"

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(age, forKey: .age)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case id
            case name
            case age
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 24
          }
        }
        """,
      diagnostics: [
        .init(message: "Only non-static variable declarations are supported", line: 6, column: 3)
      ]
    )
  }

  @Test func nameKeyConflictA() async throws {
    assertMacro(
      """
      @Codable
      public struct User {
        let id: UUID
        @CodableKey("id") let name: String
      }
      """,
      expandedSource:
        """
        public struct User {
          let id: UUID
          let name: String
        }
        """,
      diagnostics: [
        .init(message: "Key conflict found: id", line: 1, column: 1)
      ]
    )
  }

  @Test func nameKeyConflictB() async throws {
    assertMacro(
      """
      @Codable
      public struct User {
        @CodableKey("expireTime", options: .useDefaultOnFailure) private let _expireTime: Int?
        @CodableKey(options: .ignored) public private(set) var expireTime: Date?
      }
      """,
      expandedSource:
        """
        public struct User {
          private let _expireTime: Int?
          public private(set) var expireTime: Date?

          public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(_expireTime, forKey: ._expireTime)
          }
        }

        extension User: Codable {
          enum CodingKeys: String, CodingKey {
            case _expireTime = "expireTime"
          }

          public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            _expireTime = (try? container.decodeIfPresent(Int?.self, forKey: ._expireTime)) ?? nil
          }
        }
        """
    )
  }
}
