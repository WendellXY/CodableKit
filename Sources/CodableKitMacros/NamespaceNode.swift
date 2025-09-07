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
  let segment: String
  let rootBaseName: String
  var children: [String: NamespaceNode] = [:]
  var properties: [CodableProperty] = []  // Track properties at this node (usually leaf)

  weak var parent: NamespaceNode?  // Optional parent node

  init(segment: String, rootBaseName: String) {
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
        let node = NamespaceNode(segment: first, rootBaseName: rootBaseName)
        node.parent = self
        children[first] = node
        return node
      }()
    child.add(property: property, path: path.dropFirst())
  }

  static func buildTree(
    from propertyList: [CodableProperty]
  ) -> NamespaceNode {
    buildTree(
      from: propertyList,
      keyPath: { $0.customCodableKeyPath ?? [$0.name.description] },
      rootBaseName: "CodingKeys"
    )
  }

  static func buildTree(
    from propertyList: [CodableProperty],
    keyPath: (CodableProperty) -> [String],
    rootBaseName: String
  ) -> NamespaceNode {
    let root = NamespaceNode(segment: rootBaseName, rootBaseName: rootBaseName)
    for property in propertyList {
      let path = keyPath(property)
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
