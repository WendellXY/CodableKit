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
import XCTest

final class CodableKitTestsForEnum: XCTestCase {
  func testMacros() throws {
#if canImport(CodableKitMacros)
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
      macros: macros,
      indentationWidth: .spaces(2)
    )
#else
    throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
  }
  
  func testMacrosWithCodableKey() throws {
#if canImport(CodableKitMacros)
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
      macros: macros,
      indentationWidth: .spaces(2)
    )
#else
    throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
  }
  
  func testMacrosWithIgnoredCodableKey() throws {
#if canImport(CodableKitMacros)
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
      macros: macros,
      indentationWidth: .spaces(2)
    )
#else
    throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
  }
  
  func testMacrosWithIndirectCase() throws {
#if canImport(CodableKitMacros)
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
      macros: macros,
      indentationWidth: .spaces(2)
    )
#else
    throw XCTSkip("macros are only supported when running tests for the host platform")
#endif
  }
}
