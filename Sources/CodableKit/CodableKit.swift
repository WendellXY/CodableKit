//
//  CodableKit.swift
//  CodableKit
//
//  Created by Wendell on 3/30/24.
//

@attached(member)
@attached(extension, conformances: Codable)
public macro Codable() = #externalMacro(module: "CodableKitMacros", type: "CodableMacro")

@attached(peer)
public macro CodableKey() = #externalMacro(module: "CodableKitMacros", type: "CodableKeyMacro")
