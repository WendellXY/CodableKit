//
//  Defines.swift
//  CodableKit
//
//  Created by WendellXY on 2024/5/27
//  Copyright © 2024 WendellXY. All rights reserved.
//

import SwiftSyntaxMacros

#if canImport(CodableKitMacros)
import CodableKitMacros

let macros: [String: any Macro.Type] = [
  "Codable": CodableMacro.self,
  "CodableKey": CodableKeyMacro.self,
]
#endif
