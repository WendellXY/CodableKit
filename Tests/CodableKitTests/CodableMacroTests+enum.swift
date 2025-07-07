//
//  CodableMacroTests+enum.swift
//  CodableKit
//
//  Created by Wendell Wang on 2024/11/22.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Suite struct CodableKitTestsForEnum {
  @Test func macros() throws {

    assertMacroExpansion(
      """
      @Codable
      public enum TestEnum {
          case string(String)
          case int(Int)
          case none
      }
      """,
      expandedSource: """
        public enum TestEnum {
            case string(String)
            case int(Int)
            case none
        }

        extension TestEnum: Codable {
          enum CodingKeys: String, CodingKey {
            case string
            case int
            case none
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  @Test func macrosWithCodableKey() throws {

    assertMacroExpansion(
      """
      @Codable
      public enum TestEnum {
          @CodableKey("str") case string(String)
          case int(Int)
          @CodableKey("empty") case none
      }
      """,
      expandedSource: """
        public enum TestEnum {
            case string(String)
            case int(Int)
            case none
        }

        extension TestEnum: Codable {
          enum CodingKeys: String, CodingKey {
            case string = "str"
            case int
            case none = "empty"
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  @Test func macrosWithIgnoredCodableKey() throws {

    assertMacroExpansion(
      """
      @Codable
      public enum TestEnum {
          @CodableKey("str") case string(String)
          case int(Int)
          @CodableKey(options: .ignored) case none
      }
      """,
      expandedSource: """
        public enum TestEnum {
            case string(String)
            case int(Int)
            case none
        }

        extension TestEnum: Codable {
          enum CodingKeys: String, CodingKey {
            case string = "str"
            case int
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }

  @Test func macrosWithIndirectCase() throws {

    assertMacroExpansion(
      """
      @Codable
      public enum TestEnum {
          @CodableKey("str") case string(String)
          case int(Int)
          @CodableKey("empty") case none
          indirect case nestedA(TestEnum)
          @CodableKey("b") indirect case nestedB(TestEnum)
      }
      """,
      expandedSource: """
        public enum TestEnum {
            case string(String)
            case int(Int)
            case none
            indirect case nestedA(TestEnum)
            indirect case nestedB(TestEnum)
        }

        extension TestEnum: Codable {
          enum CodingKeys: String, CodingKey {
            case string = "str"
            case int
            case none = "empty"
            case nestedA
            case nestedB = "b"
          }
        }
        """,
      macroSpecs: macroSpecs,
      indentationWidth: .spaces(2)
    )

  }
}
