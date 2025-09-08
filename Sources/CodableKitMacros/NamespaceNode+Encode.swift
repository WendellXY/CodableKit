//
//  NamespaceNode+Encode.swift
//  CodableKit
//
//  Extracted encode generation from NamespaceNode
//

import SwiftSyntax
import SwiftSyntaxBuilder

extension NamespaceNode {
  var encodeContainersAssignment: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []
    if parent == nil {
      result.append(
        CodeBlockItemSyntax(item: .decl(CodeGenCore.genEncodeContainerDecl(codingKeysName: enumName)))
      )
      if hasTranscodeRawStringInSubtree {
        result.append(
          CodeBlockItemSyntax(item: .decl(CodeGenCore.genJSONEncoderVariableDecl(variableName: "__ckEncoder")))
        )
      }
    }
    for child in children.values.sorted(by: { $0.segment < $1.segment }) {
      result.append(
        CodeBlockItemSyntax(
          item: .decl(
            CodeGenCore.genNestedEncodeContainerDecl(
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
}

extension NamespaceNode {
  private var propertyEncodeAssignment: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []

    // Transformer-based encoding (before normal path and before transcodeRawString)
    for property in properties where property.transformerExpr != nil && !property.options.contains(.ignored) {
      if property.isOptional {
        result.append(
          CodeBlockItemSyntax(
            item: .expr(
              ExprSyntax(
                TryExprSyntax(
                  expression: FunctionCallExprSyntax(
                    calledExpression: type.__ckEncodeTransformedIfPresent,
                    leftParen: .leftParenToken(),
                    rightParen: .rightParenToken()
                  ) {
                    LabeledExprSyntax(label: "transformer", expression: property.transformerExpr!)
                    LabeledExprSyntax(
                      label: "value", expression: DeclReferenceExprSyntax(baseName: .identifier("\(property.name)")))
                    LabeledExprSyntax(
                      label: "into", expression: DeclReferenceExprSyntax(baseName: .identifier("&\(containerName)")))
                    LabeledExprSyntax(label: "forKey", expression: CodeGenCore.genChainingMembers("\(property.name)"))
                    LabeledExprSyntax(
                      label: "explicitNil",
                      expression: ExprSyntax(
                        BooleanLiteralExprSyntax(
                          literal: property.options.contains(.explicitNil) ? .keyword(.true) : .keyword(.false)
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
        result.append(
          CodeBlockItemSyntax(
            item: .expr(
              ExprSyntax(
                TryExprSyntax(
                  expression: FunctionCallExprSyntax(
                    calledExpression: type.__ckEncodeTransformed,
                    leftParen: .leftParenToken(),
                    rightParen: .rightParenToken()
                  ) {
                    LabeledExprSyntax(label: "transformer", expression: property.transformerExpr!)
                    LabeledExprSyntax(
                      label: "value", expression: DeclReferenceExprSyntax(baseName: .identifier("\(property.name)")))
                    LabeledExprSyntax(
                      label: "into", expression: DeclReferenceExprSyntax(baseName: .identifier("&\(containerName)")))
                    LabeledExprSyntax(label: "forKey", expression: CodeGenCore.genChainingMembers("\(property.name)"))
                  }
                )
              )
            )
          )
        )
      }
    }

    result.append(
      contentsOf: properties.filter {
        $0.isNormal && !$0.options.contains(.ignored)
      }.map { property in
        CodeBlockItemSyntax(
          item: .expr(
            CodeGenCore.genContainerEncodeExpr(
              containerName: containerName,
              key: property.name,
              patternName: property.name,
              isOptional: property.isOptional,
              explicitNil: property.options.contains(.explicitNil)
            )
          )
        )
      })

    // Encode lossy properties normally (lossy is decode-only). Skip when also using transcodeRawString.
    for property in properties
    where property.options.contains(.lossy)
      && !property.options.contains(.transcodeRawString)
      && !property.options.contains(.ignored)
    {
      result.append(
        CodeBlockItemSyntax(
          item: .expr(
            CodeGenCore.genContainerEncodeExpr(
              containerName: containerName,
              key: property.name,
              patternName: property.name,
              isOptional: property.isOptional,
              explicitNil: property.options.contains(.explicitNil)
            )
          )
        )
      )
    }

    // Encode as raw JSON string (transcoding). For optionals without `.explicitNil`, omit the key when nil.
    for property in properties where property.options.contains(.transcodeRawString) && !property.options.contains(.ignored) {
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
                    CodeBlockItemSyntax(
                      item: .decl(
                        CodeGenCore.genJSONEncoderEncodeDecl(
                          variableName: property.rawDataName,
                          instance: unwrappedName,
                          encoderVarName: hasTranscodeRawStringInSubtree ? "__ckEncoder" : nil
                        )
                      )
                    )
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
        result.append(contentsOf: [
          CodeBlockItemSyntax(
            item: .decl(
              CodeGenCore.genJSONEncoderEncodeDecl(
                variableName: property.rawDataName,
                instance: property.name,
                encoderVarName: hasTranscodeRawStringInSubtree ? "__ckEncoder" : nil
              )
            )
          ),
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
          ),
        ])
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
