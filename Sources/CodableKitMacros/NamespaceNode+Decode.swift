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
    let selfHas = properties.contains { !$0.ignored && $0.options.contains(.transcodeRawString) }
    return selfHas || children.values.contains { $0.hasTranscodeRawStringInSubtree }
  }
}

// MARK: - Decoder Generation
extension NamespaceNode {
  var containersAssignment: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []
    if parent == nil {
      result.append(CodeBlockItemSyntax(item: .decl(CodeGenCore.genDecodeContainerDecl())))
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

    result.append(
      contentsOf: properties.filter(\.isNormal).map { property in
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
    for property in properties where property.options.contains(.lossy) && !property.ignored {
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
          lossyType = TypeSyntax(
            IdentifierTypeSyntax(
              name: .identifier("LossyDictionary"),
              genericArgumentClause: GenericArgumentClauseSyntax(
                leftAngle: .leftAngleToken(),
                arguments: GenericArgumentListSyntax([
                  .init(argument: dict.key, trailingComma: .commaToken(trailingTrivia: .spaces(1))),
                  .init(argument: dict.value),
                ]),
                rightAngle: .rightAngleToken()
              )
            )
          )
        } else if let elementType {
          lossyType = TypeSyntax(
            IdentifierTypeSyntax(
              name: .identifier("LossyArray"),
              genericArgumentClause: GenericArgumentClauseSyntax(
                leftAngle: .leftAngleToken(),
                arguments: GenericArgumentListSyntax([
                  .init(argument: elementType)
                ]),
                rightAngle: .rightAngleToken()
              )
            )
          )
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
                      condition: .expression(
                        ExprSyntax(
                          PrefixOperatorExprSyntax(
                            operator: .prefixOperator("!"),
                            expression: MemberAccessExprSyntax(
                              base: DeclReferenceExprSyntax(baseName: .identifier("\(property.rawStringName)")),
                              declName: DeclReferenceExprSyntax(baseName: .identifier("isEmpty"))
                            )
                          )
                        )
                      ),
                      trailingComma: .commaToken(trailingTrivia: .spaces(1))
                    ),
                    ConditionElementSyntax(
                      condition: .optionalBinding(
                        OptionalBindingConditionSyntax(
                          bindingSpecifier: .keyword(.let),
                          pattern: property.rawDataName,
                          initializer: InitializerClauseSyntax(
                            value: FunctionCallExprSyntax(
                              calledExpression: MemberAccessExprSyntax(
                                base: DeclReferenceExprSyntax(baseName: .identifier("\(property.rawStringName)")),
                                declName: DeclReferenceExprSyntax(baseName: .identifier("data"))
                              ),
                              leftParen: .leftParenToken(),
                              rightParen: .rightParenToken()
                            ) {
                              LabeledExprSyntax(label: "using", expression: CodeGenCore.genChainingMembers("utf8"))
                            }
                          )
                        )
                      )
                    ),
                  ],
                  body: CodeBlockSyntax {
                    // let <name>LossyWrapper = try __ckDecoder.decode(LossyArray<Element>.self, from: <name>RawData)
                    CodeBlockItemSyntax(
                      item: .decl(
                        DeclSyntax(
                          CodeGenCore.genVariableDecl(
                            bindingSpecifier: .keyword(.let),
                            name: "\(property.lossyWrapperName)",
                            initializer: TryExprSyntax(
                              expression: FunctionCallExprSyntax(
                                calledExpression: MemberAccessExprSyntax(
                                  base: DeclReferenceExprSyntax(baseName: .identifier("__ckDecoder")),
                                  declName: DeclReferenceExprSyntax(baseName: .identifier("decode"))
                                ),
                                leftParen: .leftParenToken(),
                                rightParen: .rightParenToken()
                              ) {
                                LabeledExprSyntax(expression: ExprSyntax("\(lossyType).self"))
                                LabeledExprSyntax(
                                  label: "from",
                                  expression: DeclReferenceExprSyntax(baseName: .identifier("\(property.rawDataName)"))
                                )
                              }
                            )
                          )
                        )
                      )
                    )

                    // <name> = <wrapper>.elements or Set(<wrapper>.elements)
                    CodeBlockItemSyntax(
                      item: .expr(
                        ExprSyntax(
                          InfixOperatorExprSyntax(
                            leftOperand: DeclReferenceExprSyntax(baseName: .identifier("\(property.name)")),
                            operator: AssignmentExprSyntax(equal: .equalToken()),
                            rightOperand: {
                              let elementsAccess = ExprSyntax(
                                MemberAccessExprSyntax(
                                  base: DeclReferenceExprSyntax(baseName: .identifier("\(property.lossyWrapperName)")),
                                  declName: DeclReferenceExprSyntax(baseName: .identifier("elements"))
                                )
                              )
                              return property.isSetType
                                ? ExprSyntax(
                                  FunctionCallExprSyntax(
                                    calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Set")),
                                    leftParen: .leftParenToken(),
                                    rightParen: .rightParenToken()
                                  ) {
                                    LabeledExprSyntax(expression: elementsAccess)
                                  }
                                )
                                : elementsAccess
                            }()
                          )
                        )
                      )
                    )
                  },
                  elseKeyword: .keyword(.else),
                  elseBody: .init(
                    CodeBlockSyntax {
                      if let defaultValueExpr {
                        CodeBlockItemSyntax(
                          item: .expr(
                            ExprSyntax(
                              InfixOperatorExprSyntax(
                                leftOperand: DeclReferenceExprSyntax(baseName: .identifier("\(property.name)")),
                                operator: AssignmentExprSyntax(equal: .equalToken()),
                                rightOperand: defaultValueExpr
                              )
                            )
                          )
                        )
                      } else if property.isOptional {
                        CodeBlockItemSyntax(
                          item: .expr(
                            ExprSyntax(
                              InfixOperatorExprSyntax(
                                leftOperand: DeclReferenceExprSyntax(baseName: .identifier("\(property.name)")),
                                operator: AssignmentExprSyntax(equal: .equalToken()),
                                rightOperand: ExprSyntax(NilLiteralExprSyntax())
                              )
                            )
                          )
                        )
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
        lossyType = TypeSyntax(
          IdentifierTypeSyntax(
            name: .identifier("LossyDictionary"),
            genericArgumentClause: GenericArgumentClauseSyntax(
              leftAngle: .leftAngleToken(),
              arguments: GenericArgumentListSyntax([
                .init(argument: dict.key, trailingComma: .commaToken(trailingTrivia: .spaces(1))),
                .init(argument: dict.value),
              ]),
              rightAngle: .rightAngleToken()
            )
          )
        )
      } else if let elementType {
        lossyType = TypeSyntax(
          IdentifierTypeSyntax(
            name: .identifier("LossyArray"),
            genericArgumentClause: GenericArgumentClauseSyntax(
              leftAngle: .leftAngleToken(),
              arguments: GenericArgumentListSyntax([
                .init(argument: elementType)
              ]),
              rightAngle: .rightAngleToken()
            )
          )
        )
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
        let unwrappedName = PatternSyntax(
          IdentifierPatternSyntax(identifier: .identifier("\(property.name)LossyUnwrapped")))

        let assignedRHSWhenUnwrapped: ExprSyntax = {
          let elementsAccess = ExprSyntax(
            MemberAccessExprSyntax(
              base: DeclReferenceExprSyntax(baseName: .identifier("\(unwrappedName)")),
              declName: DeclReferenceExprSyntax(baseName: .identifier("elements"))
            )
          )
          if property.isSetType {
            return ExprSyntax(
              FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Set")),
                leftParen: .leftParenToken(),
                rightParen: .rightParenToken()
              ) {
                LabeledExprSyntax(expression: elementsAccess)
              }
            )
          } else {
            return elementsAccess
          }
        }()

        let defaultExpr: ExprSyntax = property.defaultValue ?? ExprSyntax(NilLiteralExprSyntax())

        result.append(
          CodeBlockItemSyntax(
            item: .expr(
              ExprSyntax(
                IfExprSyntax(
                  conditions: [
                    ConditionElementSyntax(
                      condition: .optionalBinding(
                        OptionalBindingConditionSyntax(
                          bindingSpecifier: .keyword(.let),
                          pattern: unwrappedName,
                          initializer: InitializerClauseSyntax(
                            value: DeclReferenceExprSyntax(baseName: .identifier("\(property.lossyWrapperName)"))
                          )
                        )
                      )
                    )
                  ],
                  body: CodeBlockSyntax {
                    CodeBlockItemSyntax(
                      item: .expr(
                        ExprSyntax(
                          InfixOperatorExprSyntax(
                            leftOperand: DeclReferenceExprSyntax(baseName: .identifier("\(property.name)")),
                            operator: AssignmentExprSyntax(equal: .equalToken()),
                            rightOperand: assignedRHSWhenUnwrapped
                          )
                        )
                      )
                    )
                  },
                  elseKeyword: .keyword(.else),
                  elseBody: .init(
                    CodeBlockSyntax {
                      CodeBlockItemSyntax(
                        item: .expr(
                          ExprSyntax(
                            InfixOperatorExprSyntax(
                              leftOperand: DeclReferenceExprSyntax(baseName: .identifier("\(property.name)")),
                              operator: AssignmentExprSyntax(equal: .equalToken()),
                              rightOperand: defaultExpr
                            )
                          )
                        )
                      )
                    }
                  )
                )
              )
            )
          )
        )
      } else {
        // Non-optional decode path, wrapper is non-optional here
        let elementsAccess = ExprSyntax(
          MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier("\(property.lossyWrapperName)")),
            declName: DeclReferenceExprSyntax(baseName: .identifier("elements"))
          )
        )
        let rhs =
          property.isSetType
          ? ExprSyntax(
            FunctionCallExprSyntax(
              calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Set")),
              leftParen: .leftParenToken(),
              rightParen: .rightParenToken()
            ) {
              LabeledExprSyntax(expression: elementsAccess)
            }
          )
          : elementsAccess

        result.append(
          CodeBlockItemSyntax(
            item: .expr(
              ExprSyntax(
                InfixOperatorExprSyntax(
                  leftOperand: DeclReferenceExprSyntax(baseName: .identifier("\(property.name)")),
                  operator: AssignmentExprSyntax(equal: .equalToken()),
                  rightOperand: rhs
                )
              )
            )
          )
        )
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
