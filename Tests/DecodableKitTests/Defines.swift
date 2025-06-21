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
import SwiftSyntaxMacrosTestSupport

let macros: [String: any Macro.Type] = [
  "Codable": CodableMacro.self,
  "CodableKey": CodableKeyMacro.self,
]

let macroSpecs: [String: MacroSpec] = [
  "Decodable": MacroSpec(type: CodableMacro.self, conformances: ["Decodable"]),
  "CodableKey": MacroSpec(type: CodableKeyMacro.self),
]
