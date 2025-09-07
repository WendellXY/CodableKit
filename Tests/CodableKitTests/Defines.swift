//
//  Defines.swift
//  CodableKit
//
//  Created by WendellXY on 2024/5/27
//  Copyright © 2024 WendellXY. All rights reserved.
//

import CodableKitMacros
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import SwiftSyntaxMacrosTestSupport
import Testing

let macros: [String: any Macro.Type] = [
  "Codable": CodableMacro.self,
  "CodableKey": CodableKeyMacro.self,
  "DecodableKey": DecodableKeyMacro.self,
  "EncodableKey": EncodableKeyMacro.self,
]

let macroSpecs: [String: MacroSpec] = [
  "Codable": MacroSpec(type: CodableMacro.self, conformances: ["Codable"]),
  "CodableKey": MacroSpec(type: CodableKeyMacro.self),
  "DecodableKey": MacroSpec(type: DecodableKeyMacro.self),
  "EncodableKey": MacroSpec(type: EncodableKeyMacro.self),
]

func assertMacro(
  _ originalSource: String,
  expandedSource expectedExpandedSource: String,
  diagnostics: [DiagnosticSpec] = [],
  applyFixIts: [String]? = nil,
  fixedSource expectedFixedSource: String? = nil,
  testModuleName: String = "TestModule",
  testFileName: String = "test.swift",
  indentationWidth: Trivia = .spaces(2),
  fileID: StaticString = #fileID,
  file filePath: StaticString = #filePath,
  function: StaticString = #function,
  line: UInt = #line,
  column: UInt = #column
) {
  SwiftSyntaxMacrosGenericTestSupport.assertMacroExpansion(
    originalSource,
    expandedSource: expectedExpandedSource,
    diagnostics: diagnostics,
    macroSpecs: macroSpecs,
    applyFixIts: applyFixIts,
    fixedSource: expectedFixedSource,
    testModuleName: testModuleName,
    testFileName: testFileName,
    indentationWidth: indentationWidth,
    failureHandler: {
      #expect(
        Bool(false),
        .init(stringLiteral: $0.message),
        sourceLocation: .init(
          fileID: String(describing: fileID),
          filePath: String(describing: filePath),
          line: Int(line),
          column: Int(column)
        )
      )
    },
    fileID: fileID,
    // Not used in the failure handler
    filePath: filePath,
    /// MahdiBM comment: requires StaticString so just set it to "" for now.
    line: line,
    column: column  // Not used in the failure handler
  )
}
