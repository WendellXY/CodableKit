//
//  Plugin.swift
//  CodableKit
//
//  Created by Wendell on 3/30/24.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct CodableKitPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    CodableMacro.self
  ]
}
