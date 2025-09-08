//
//  NamespaceNode+Decode.swift
//  CodableKit
//
//  Extracted decode generation from NamespaceNode
//

import SwiftSyntax
import SwiftSyntaxBuilder

extension NamespaceNode {
  var containerName: String { parent == nil ? "container" : segment + "Container" }

  /// Whether any property in this subtree requires raw string transcoding
  var hasTranscodeRawStringInSubtree: Bool {
    let selfHas = properties.contains {
      !$0.options.contains(.ignored) && $0.options.contains(.transcodeRawString)
    }
    return selfHas || children.values.contains { $0.hasTranscodeRawStringInSubtree }
  }
}

// MARK: - Decoder Generation
extension NamespaceNode {
  var containersAssignment: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []
    if parent == nil {
      result.append(
        CodeBlockItemSyntax(item: .decl(CodeGenCore.genDecodeContainerDecl(codingKeysName: enumName))))
      if hasTranscodeRawStringInSubtree {
        result.append(
          CodeBlockItemSyntax(item: .decl(CodeGenCore.genJSONDecoderVariableDecl(variableName: "__ckDecoder"))))
      }
    }
    for child in children.values.sorted(by: { $0.segment < $1.segment }) {
      result.append(
        CodeBlockItemSyntax(
          item: .decl(
            CodeGenCore.genNestedDecodeContainerDecl(
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
  private var propertyAssignment: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []

    // Transformer-based decoding, decode-only takes precedence, then bidirectional
    for property in properties where property.transformerExpr != nil && !property.options.contains(.ignored) {
      let useDefault = property.options.contains(.useDefaultOnFailure)

      if property.isOptional || property.defaultValue != nil {
        let callExpr = ExprSyntax(
          TryExprSyntax(
            expression: FunctionCallExprSyntax(
              leadingTrivia: .spaces(1),
              calledExpression: type.__ckDecodeTransformedIfPresent,
              leftParen: .leftParenToken(),
              rightParen: .rightParenToken()
            ) {
              LabeledExprSyntax(label: "transformer", expression: property.transformerExpr!)
              LabeledExprSyntax(
                label: "from", expression: DeclReferenceExprSyntax(baseName: .identifier(containerName)))
              LabeledExprSyntax(label: "forKey", expression: CodeGenCore.genChainingMembers("\(property.name)"))
              LabeledExprSyntax(
                label: "useDefaultOnFailure",
                expression: ExprSyntax(
                  BooleanLiteralExprSyntax(literal: useDefault ? .keyword(.true) : .keyword(.false)))
              )
              if let def = property.defaultValue {
                LabeledExprSyntax(label: "defaultValue", expression: def)
              }
            }
          )
        )

        let rhs: ExprSyntax =
          if property.isOptional {
            callExpr
          } else {
            "(\(callExpr)) ?? \(property.defaultValue ?? "nil")"
          }

        result.append(CodeBlockItemSyntax(item: .expr("\(property.name) = \(rhs)")))
        continue
      }

      let callExpr = ExprSyntax(
        TryExprSyntax(
          expression: FunctionCallExprSyntax(
            leadingTrivia: .spaces(1),
            calledExpression: type.__ckDecodeTransformed,
            leftParen: .leftParenToken(),
            rightParen: .rightParenToken()
          ) {
            LabeledExprSyntax(label: "transformer", expression: property.transformerExpr!)
            LabeledExprSyntax(label: "from", expression: DeclReferenceExprSyntax(baseName: .identifier(containerName)))
            LabeledExprSyntax(label: "forKey", expression: CodeGenCore.genChainingMembers("\(property.name)"))
            LabeledExprSyntax(
              label: "useDefaultOnFailure",
              expression: ExprSyntax(
                BooleanLiteralExprSyntax(literal: useDefault ? .keyword(.true) : .keyword(.false))
              )
            )
          }
        )
      )

      result.append(CodeBlockItemSyntax(item: .expr("\(property.name) = \(callExpr)")))
    }

    result.append(
      contentsOf: properties.filter {
        $0.isNormal && !$0.ignored
      }.map { property in
        CodeBlockItemSyntax(
          item: .expr(
            CodeGenCore.genContainerDecodeExpr(
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

    // Lossy decode for arrays, sets, and dictionaries
    for property in properties where property.options.contains(.lossy) && !property.options.contains(.ignored) {
      let isCollection = property.isArrayType || property.isSetType
      let isDict = property.isDictionaryType
      let elementType = property.collectionElementType
      let dictTypes = property.dictionaryKeyAndValueTypes
      guard (isCollection && elementType != nil) || (isDict && dictTypes != nil) else { continue }

      if property.options.contains(.transcodeRawString) {
        // Combined lossy + transcodeRawString: decode raw string, transcode to data, decode LossyArray<Element>, assign .elements (or Set)
        let defaultValueExpr = property.defaultValue ?? (property.isOptional ? "nil" : nil)

        // raw string: let <name>RawString = try? container.decodeIfPresent(String.self, forKey: .name) ?? ""
        result.append(
          CodeBlockItemSyntax(
            item: .decl(
              CodeGenCore.genContainerDecodeVariableDecl(
                variableName: property.rawStringName,
                containerName: containerName,
                patternName: property.name,
                isOptional: true,
                useDefaultOnFailure: property.options.contains(.useDefaultOnFailure),
                defaultValueExpr: ExprSyntax(StringLiteralExprSyntax(content: "")),
                type: TypeSyntax(IdentifierTypeSyntax(name: .identifier("String")))
              )
            )
          )
        )

        // if !rawString.isEmpty, let rawData = rawString.data(using: .utf8) { ... } else { throw or assign default }
        let lossyType: TypeSyntax
        if isDict, let dict = dictTypes {
          lossyType = "LossyDictionary<\(dict.key), \(dict.value)>"
        } else if let elementType {
          lossyType = "LossyArray<\(elementType)>"
        } else {
          continue
        }

        result.append(
          CodeBlockItemSyntax(
            item: .expr(
              ExprSyntax(
                IfExprSyntax(
                  conditions: [
                    ConditionElementSyntax(
                      condition: .expression("!\(property.rawStringName).isEmpty"),
                      trailingComma: .commaToken(trailingTrivia: .spaces(1))
                    ),
                    ConditionElementSyntax(
                      condition: .expression("let \(property.rawDataName) = \(property.rawStringName).data(using: .utf8)"),
                      trailingTrivia: .spaces(1)
                    ),
                  ],
                  body: CodeBlockSyntax {
                    "let \(property.lossyWrapperName) = try __ckDecoder.decode(\(lossyType).self, from: \(property.rawDataName))"

                    if property.isSetType {
                      "\(property.name) = Set(\(property.lossyWrapperName).elements)"
                    } else {
                      "\(property.name) = \(property.lossyWrapperName).elements"
                    }
                  },
                  elseKeyword: .keyword(.else),
                  elseBody: .init(
                    CodeBlockSyntax {
                      if let defaultValueExpr {
                        "\(property.name) = \(defaultValueExpr)"
                      } else if property.isOptional {
                        "\(property.name) = nil"
                      } else {
                        CodeBlockItemSyntax(
                          item: .stmt(
                            CodeGenCore.genValueNotFoundDecodingErrorThrowStmt(
                              type: TypeSyntax(IdentifierTypeSyntax(name: .identifier("String"))),
                              codingPath: codingKeyChain(for: property),
                              message: "Failed to convert raw string to data"
                            )
                          )
                        )
                      }
                    }
                  )
                )
              )
            )
          )
        )

        // Done for combined case
        continue
      }

      let lossyType: TypeSyntax
      if isDict, let dict = dictTypes {
        lossyType = TypeSyntax("LossyDictionary<\(dict.key), \(dict.value)>")
      } else if let elementType {
        lossyType = TypeSyntax("LossyArray<\(elementType)>")
      } else {
        continue
      }

      let shouldUseDecodeIfPresent = property.isOptional || property.defaultValue != nil

      // let <name>LossyWrapper = try? container.decodeIfPresent(LossyArray<Element>.self, forKey: .name)
      let decodeDecl = CodeGenCore.genContainerDecodeVariableDecl(
        variableName: property.lossyWrapperName,
        containerName: containerName,
        patternName: property.name,
        isOptional: shouldUseDecodeIfPresent,
        useDefaultOnFailure: property.options.contains(.useDefaultOnFailure),
        defaultValueExpr: nil,
        type: lossyType
      )

      result.append(CodeBlockItemSyntax(item: .decl(decodeDecl)))

      // Build assignment respecting optionality and defaults
      if shouldUseDecodeIfPresent {
        let unwrappedName: PatternSyntax = "\(property.name)LossyUnwrapped"

        let assignedRHSWhenUnwrapped: ExprSyntax =
          if property.isSetType {
            "Set(\(unwrappedName).elements)"
          } else {
            "\(unwrappedName).elements"
          }

        let defaultExpr: ExprSyntax = property.defaultValue ?? "nil"

        result.append(
          CodeBlockItemSyntax(
            item: .expr(
              ExprSyntax(
                IfExprSyntax(
                  conditions: [
                    ConditionElementSyntax(
                      condition: .expression("let \(unwrappedName) = \(property.lossyWrapperName)"),
                      trailingTrivia: .spaces(1)
                    )
                  ],
                  body: CodeBlockSyntax {
                    "\(property.name) = \(assignedRHSWhenUnwrapped)"
                  },
                  elseKeyword: .keyword(.else),
                  elseBody: .init(
                    CodeBlockSyntax {
                      "\(property.name) = \(defaultExpr)"
                    }
                  )
                )
              )
            )
          )
        )
      } else {
        // Non-optional decode path, wrapper is non-optional here
        let rhs: ExprSyntax =
          if property.isSetType {
            "Set(\(property.lossyWrapperName).elements)"
          } else {
            "\(property.lossyWrapperName).elements"
          }

        result.append(CodeBlockItemSyntax(item: .expr("\(property.name) = \(rhs)")))
      }
    }

    for property in properties
    where property.options.contains(.transcodeRawString) && !property.ignored && !property.options.contains(.lossy) {
      let key = property.name
      let rawKey = property.rawStringName

      let defaultValueExpr = property.defaultValue ?? (property.isOptional ? "nil" : nil)

      result.append(contentsOf: [
        CodeBlockItemSyntax(
          item: .decl(
            CodeGenCore.genContainerDecodeVariableDecl(
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
            CodeGenCore.genRawDataHandleExpr(
              key: property.name,
              rawDataName: property.rawDataName,
              rawStringName: property.rawStringName,
              defaultValueExpr: defaultValueExpr,
              codingPath: codingKeyChain(for: property),
              type: property.type,
              message: "Failed to convert raw string to data",
              decoderVarName: hasTranscodeRawStringInSubtree ? "__ckDecoder" : nil
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
    for child in children.values.sorted(by: { $0.segment < $1.segment }) {
      result.append(contentsOf: child.decodeBlockItem)
    }

    return result
  }
}
