//
//  NamespaceNode+Encode.swift
//  CodableKit
//
//  Extracted encode generation from NamespaceNode
//

import SwiftSyntax
import SwiftSyntaxBuilder

extension NamespaceNode {
  @ArrayBuilder<CodeBlockItemSyntax> var encodeContainersAssignment: [CodeBlockItemSyntax] {
    if parent == nil {
      "var container = encoder.container(keyedBy: \(raw: enumName).self)"
      if hasTranscodeRawStringInSubtree {
        "let __ckEncoder = JSONEncoder()"
      }
    }
    for child in children.values.sorted(by: { $0.segment < $1.segment }) {
      "var \(raw: child.containerName) = \(raw: containerName).nestedContainer(keyedBy: \(raw: child.enumName).self, forKey: .\(raw: child.segment))"
    }
  }
}

extension NamespaceNode {
  fileprivate func containerEncodeExpr(property: CodableProperty) -> CodeBlockItemSyntax {
    let encodeFuncName = property.isOptional && !property.options.contains(.explicitNil) ? "encodeIfPresent" : "encode"
    let chainingMembers = CodeGenCore.genChainingMembers("\(property.name)")
    return "try \(raw: containerName).\(raw: encodeFuncName)(\(property.name), forKey: \(chainingMembers))"
  }

  private var propertyEncodeAssignment: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []

    result.appendContentsOf {
      // Transformer-based encoding (before normal path and before transcodeRawString)
      for property in properties where property.transformerExpr != nil && !property.options.contains(.ignored) {
        if property.isOptional {
          "try \(type.__ckEncodeTransformedIfPresent)(transformer: \(property.transformerExpr!), value: \(property.name), into: &\(raw: containerName), forKey: \(CodeGenCore.genChainingMembers("\(property.name)")), explicitNil: \(raw: property.options.contains(.explicitNil) ? "true" : "false"))"
        } else {
          "try \(type.__ckEncodeTransformed)(transformer: \(property.transformerExpr!), value: \(property.name), into: &\(raw: containerName), forKey: \(CodeGenCore.genChainingMembers("\(property.name)")))"
        }
      }

      for property in properties where property.isNormal && !property.options.contains(.ignored) {
        containerEncodeExpr(property: property)
      }

      // Encode lossy properties normally (lossy is decode-only). Skip when also using transcodeRawString.
      for property in properties
      where property.options.contains(.lossy)
        && !property.options.contains(.transcodeRawString)
        && !property.options.contains(.ignored)
      {
        containerEncodeExpr(property: property)
      }
    }

    // Encode as raw JSON string (transcoding). For optionals without `.explicitNil`, omit the key when nil.
    for property in properties
    where property.options.contains(.transcodeRawString) && !property.options.contains(.ignored) {
      if property.isOptional && !property.options.contains(.explicitNil) {
        // if let <name>Unwrapped = <name> { ... encode ... }
        let unwrappedName: PatternSyntax = "\(property.name)Unwrapped"
        result.append(
          CodeBlockItemSyntax(
            item: .expr(
              ExprSyntax(
                IfExprSyntax(
                  conditions: [
                    ConditionElementSyntax(
                      condition: .expression("let \(unwrappedName) = \(property.name)"),
                      trailingTrivia: .spaces(1)
                    )
                  ],
                  body: CodeBlockSyntax {
                    "let \(raw: property.rawDataName) = try \(raw: hasTranscodeRawStringInSubtree ? "__ckEncoder" : "JSONEncoder()").encode(\(raw: unwrappedName))"
                    CodeBlockItemSyntax(
                      item: .expr(
                        CodeGenCore.genEncodeRawDataHandleExpr(
                          key: property.name,
                          rawDataName: property.rawDataName,
                          rawStringName: property.rawStringName,
                          containerName: containerName,
                          codingPath: codingKeyChain(for: property),
                          message: "Failed to transcode raw data to string",
                          isOptional: false,
                          explicitNil: false
                        )
                      )
                    )
                  }
                )
              )
            )
          )
        )
      } else {
        // Non-optional or `.explicitNil` option: encode current value, allowing explicit nil as string
        result.appendContentsOf {
          "let \(raw: property.rawDataName) = try \(raw: hasTranscodeRawStringInSubtree ? "__ckEncoder" : "JSONEncoder()").encode(\(raw: property.name))"
          CodeBlockItemSyntax(
            item: .expr(
              CodeGenCore.genEncodeRawDataHandleExpr(
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
          )
        }
      }
    }

    return result
  }

  var encodeBlockItem: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []

    result.append(contentsOf: encodeContainersAssignment)
    result.append(contentsOf: propertyEncodeAssignment)
    for child in children.values.sorted(by: { $0.segment < $1.segment }) {
      result.append(contentsOf: child.encodeBlockItem)
    }

    return result
  }
}
