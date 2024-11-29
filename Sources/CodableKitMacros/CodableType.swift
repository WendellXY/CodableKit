//
//  CodableType.swift
//  CodableKit
//
//  Created by Wendell Wang on 2024/11/29.
//

import SwiftSyntax

internal struct CodableType: OptionSet {
  let rawValue: Int8
  
  static let none: CodableType = []
  static let codable: CodableType = [.decodable, .encodable]
  static let decodable = CodableType(rawValue: 1 << 0)
  static let encodable = CodableType(rawValue: 1 << 1)
  
  static func from(_ protocols: [TypeSyntax]) -> CodableType {
    var codableType = CodableType.none
    
    for `protocol` in protocols {
      guard let name = `protocol`.as(IdentifierTypeSyntax.self)?.name.trimmed.text else { continue }
      switch name {
      case "Codable":
        codableType.insert(.codable)
      case "Decodable":
        codableType.insert(.decodable)
      case "Encodable":
        codableType.insert(.encodable)
      default:
        break
      }
    }
    
    return codableType
  }
}
