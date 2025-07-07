//
//  NamespaceNode.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/7/8.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

final class NamespaceNode {
  private let core = CodeGenCore.shared

  let segment: String
  var children: [String: NamespaceNode] = [:]
  var properties: [CodableProperty] = []  // Track properties at this node (usually leaf)

  weak var parent: NamespaceNode?  // Optional parent node

  init(segment: String) {
    self.segment = segment
  }

  // Add a property to the tree based on its full key path
  private func add(property: CodableProperty, path: ArraySlice<String>) {
    guard path.count > 1, let first = path.first else {
      // This node is the property leaf
      properties.append(property)
      return
    }
    let child =
      children[first]
      ?? {
        let node = NamespaceNode(segment: first)
        node.parent = self
        children[first] = node
        return node
      }()
    child.add(property: property, path: path.dropFirst())
  }

  static func buildTree(from propertyList: [CodableProperty]) -> NamespaceNode {
    let root = NamespaceNode(segment: "CodingKeys")
    for property in propertyList {
      let keyPath = property.customCodableKeyPath ?? [property.name.description]
      root.add(property: property, path: keyPath[...])
    }
    return root
  }
}

// MARK: - CodingKeys Enum Generation
extension NamespaceNode {
  private var enumName: String {
    parent == nil ? "CodingKeys" : segment.capitalized + "Keys"
  }

  private var codingKeysEnum: EnumDeclSyntax? {
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
      for child in children.values {
        "case \(raw: child.segment)"
      }
    }
  }

  var allCodingKeysEnums: [EnumDeclSyntax] {
    var result: [EnumDeclSyntax] = []
    if let codingKeysEnum {
      result.append(codingKeysEnum)
    }
    for child in children.values {
      result.append(contentsOf: child.allCodingKeysEnums)
    }
    return result
  }
}

