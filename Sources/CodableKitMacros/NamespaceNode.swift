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

extension NamespaceNode {
  private var containerName: String {
    parent == nil ? "container" : segment + "Container"
  }
}

// MARK: - Decoder Generation
extension NamespaceNode {

  private var containersAssignment: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []

    if parent == nil {
      result.append(
        CodeBlockItemSyntax(item: .decl(core.genDecodeContainerDecl()))
      )
    }

    for child in children.values {
      result.append(
        CodeBlockItemSyntax(
          item: .decl(
            core.genNestedDecodeContainerDecl(
              container: child.containerName,
              parentContainer: containerName,
              keyedBy: child.enumName,
              forKey: child.segment
            )
          )
        )
      )
    }

    return result
  }

  private var propertyAssignment: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []

    result.append(
      contentsOf: properties.filter(\.isNormal).map { property in
        CodeBlockItemSyntax(
          item: .expr(
            core.genContainerDecodeExpr(
              containerName: containerName,
              variableName: property.name,
              patternName: property.name,
              isOptional: property.isOptional,
              useDefaultOnFailure: property.options.contains(.useDefaultOnFailure),
              defaultValueExpr: property.defaultValue,
              type: property.type
            )
          )
        )
      }
    )

    for property in properties where property.options.contains(.transcodeRawString) && !property.ignored {
      let key = property.name
      let rawKey = property.rawStringName

      let defaultValueExpr = property.defaultValue ?? (property.isOptional ? "nil" : nil)

      result.append(contentsOf: [
        CodeBlockItemSyntax(
          item: .decl(
            core.genContainerDecodeVariableDecl(
              variableName: rawKey,
              containerName: containerName,
              patternName: key,
              isOptional: property.isOptional,
              useDefaultOnFailure: property.options.contains(.useDefaultOnFailure),
              defaultValueExpr: ExprSyntax(StringLiteralExprSyntax(content: "")),
              type: TypeSyntax(IdentifierTypeSyntax(name: .identifier("String")))
            )
          )
        ),
        CodeBlockItemSyntax(
          item: .expr(
            core.genRawDataHandleExpr(
              key: property.name,
              rawDataName: property.rawDataName,
              rawStringName: property.rawStringName,
              defaultValueExpr: defaultValueExpr,
              codingPath: codingKeyChain(for: property),
              type: property.type,
              message: "Failed to convert raw string to data"
            )
          )
        ),
      ])
    }

    return result
  }

  var decodeBlockItem: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []

    result.append(contentsOf: containersAssignment)
    result.append(contentsOf: propertyAssignment)
    for child in children.values {
      result.append(contentsOf: child.decodeBlockItem)
    }

    return result
  }
}

// MARK: - Encoder Generation
extension NamespaceNode {
  private var encodeContainersAssignment: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []

    if parent == nil {
      result.append(CodeBlockItemSyntax(item: .decl(core.genEncodeContainerDecl())))
    }

    for child in children.values {
      result.append(
        CodeBlockItemSyntax(
          item: .decl(
            core.genNestedEncodeContainerDecl(
              container: child.containerName,
              parentContainer: containerName,
              keyedBy: child.enumName,
              forKey: child.segment
            )
          )
        )
      )
    }

    return result
  }

  private var propertyEncodeAssignment: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []

    result.append(
      contentsOf: properties.filter(\.isNormal).map { property in
        CodeBlockItemSyntax(
          item: .expr(
            core.genContainerEncodeExpr(
              containerName: containerName,
              key: property.name,
              patternName: property.name,
              isOptional: property.isOptional,
              explicitNil: property.options.contains(.explicitNil)
            )
          )
        )
      })

    // Decode from the rawString.
    for property in properties where property.options.contains(.transcodeRawString) && !property.ignored {
      result.append(contentsOf: [
        CodeBlockItemSyntax(
          item: .decl(
            core.genJSONEncoderEncodeDecl(
              variableName: property.rawDataName,
              instance: property.name
            )
          )
        ),
        CodeBlockItemSyntax(
          item: .expr(
            core.genEncodeRawDataHandleExpr(
              key: property.name,
              rawDataName: property.rawDataName,
              rawStringName: property.rawStringName,
              containerName: containerName,
              codingPath: codingKeyChain(for: property),
              message: "Failed to transcode raw data to string",
              isOptional: property.isOptional,
              explicitNil: property.options.contains(.explicitNil)
            )
          )
        ),
      ])
    }

    return result
  }

  var encodeBlockItem: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []

    result.append(contentsOf: encodeContainersAssignment)
    result.append(contentsOf: propertyEncodeAssignment)
    for child in children.values {
      result.append(contentsOf: child.encodeBlockItem)
    }

    return result
  }
}
