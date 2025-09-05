//
//  NamespaceNode+CodingKeys.swift
//  CodableKit
//
//  Extracted coding keys enum generation from NamespaceNode
//

import SwiftSyntax
import SwiftSyntaxBuilder

extension NamespaceNode {
  var enumName: String {
    parent == nil ? "CodingKeys" : segment.capitalized + "Keys"
  }

  var codingKeysEnum: EnumDeclSyntax? {
    guard !properties.isEmpty || !children.isEmpty else { return nil }
    return EnumDeclSyntax(
      name: .identifier(enumName),
      inheritanceClause: .init(
        inheritedTypesBuilder: {
          InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("String")))
          InheritedTypeSyntax(type: IdentifierTypeSyntax(name: .identifier("CodingKey")))
        }
      )
    ) {
      for property in properties where !property.ignored {
        if let customCodableKey = property.customCodableKey,
          customCodableKey.description != property.name.description
        {
          "case \(property.name) = \"\(customCodableKey)\""
        } else {
          "case \(property.name)"
        }
      }
      for child in children.values.sorted(by: { $0.segment < $1.segment }) {
        "case \(raw: child.segment)"
      }
    }
  }

  var allCodingKeysEnums: [EnumDeclSyntax] {
    var result: [EnumDeclSyntax] = []
    if let codingKeysEnum {
      result.append(codingKeysEnum)
    }
    for child in children.values.sorted(by: { $0.segment < $1.segment }) {
      result.append(contentsOf: child.allCodingKeysEnums)
    }
    return result
  }
}
