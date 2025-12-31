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
  let type: CodableType
  let segment: String
  let rootBaseName: String
  var children: [String: NamespaceNode] = [:]
  var properties: [CodableProperty] = []  // Track properties at this node (usually leaf)

  weak var parent: NamespaceNode?  // Optional parent node

  init(_ type: CodableType, segment: String, rootBaseName: String) {
    self.type = type
    self.segment = segment
    self.rootBaseName = rootBaseName
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
        let node = NamespaceNode(type, segment: first, rootBaseName: rootBaseName)
        node.parent = self
        children[first] = node
        return node
      }()
    child.add(property: property, path: path.dropFirst())
  }

  static func buildTree(
    _ type: CodableType,
    from propertyList: [CodableProperty]
  ) -> NamespaceNode {
    let rootBaseName =
      switch type {
      case .decodable: "DecodeKeys"
      case .encodable: "EncodeKeys"
      default: "CodingKeys"
      }

    let root = NamespaceNode(type, segment: rootBaseName, rootBaseName: rootBaseName)

    let propertyList = propertyList.map {
      $0.generateProperty(for: type)
    }

    for property in propertyList {
      let path = property.customCodableKeyPath ?? [property.name.description]
      root.add(property: property, path: path[...])
    }
    return root
  }

  func codingKeyChain(for property: CodableProperty) -> [(String, String)] {
    var chain: [(String, String)] = []
    chain.append((enumName, property.name.description))
    var node = self
    while let parent = node.parent {
      let key = parent.enumName
      let value = node.segment
      chain.append((key, value))
      node = parent
    }
    // Reverse the chain to have the root first
    return chain.reversed()
  }
}
