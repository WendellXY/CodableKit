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
      codableType.insert(from(name))
    }

    return codableType
  }

  static func from(_ macroName: String) -> CodableType {
    switch macroName {
    case "Codable": .codable
    case "Decodable": .decodable
    case "Encodable": .encodable
    case "CodableKey": .codable
    case "DecodableKey": .decodable
    case "EncodableKey": .encodable
    default: .none
    }
  }
}

extension CodableType {
  var __ckDecodeTransformed: DeclReferenceExprSyntax {
    DeclReferenceExprSyntax(
      baseName: .identifier(
        contains(.codable) ? "__ckDecodeTransformed" : "__ckDecodeOneWayTransformed"
      )
    )
  }

  var __ckDecodeTransformedIfPresent: DeclReferenceExprSyntax {
    DeclReferenceExprSyntax(
      baseName: .identifier(
        contains(.codable) ? "__ckDecodeTransformedIfPresent" : "__ckDecodeOneWayTransformedIfPresent"
      )
    )
  }

  var __ckEncodeTransformedIfPresent: DeclReferenceExprSyntax {
    DeclReferenceExprSyntax(
      baseName: .identifier(
        contains(.codable) ? "__ckEncodeTransformedIfPresent" : "__ckEncodeOneWayTransformedIfPresent"
      )
    )
  }

  var __ckEncodeTransformed: DeclReferenceExprSyntax {
    DeclReferenceExprSyntax(
      baseName: .identifier(
        contains(.codable) ? "__ckEncodeTransformed" : "__ckEncodeOneWayTransformed"
      )
    )
  }
}
