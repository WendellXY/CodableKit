//
//  CodeGenCore+GenDecode.swift
//  CodableKit
//
//  Created by WendellXY on 2024/5/29
//  Copyright © 2024 WendellXY. All rights reserved.
//

import SwiftSyntax
import SwiftSyntaxBuilder

// MARK: JSONDecoder

extension CodeGenCore {
  fileprivate static func genJSONDecoderDecodeRightOperand(
    type: TypeSyntax,
    data: PatternSyntax,
    withQuestionMark: Bool
  ) -> some ExprSyntaxProtocol {
    TryExprSyntax(
      questionOrExclamationMark: withQuestionMark ? .infixQuestionMarkToken(leadingTrivia: .spaces(0)) : nil,
      expression: FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("JSONDecoder")),
            leftParen: .leftParenToken(),
            rightParen: .rightParenToken(),
            argumentsBuilder: {}
          ),
          declName: DeclReferenceExprSyntax(baseName: .identifier("decode"))
        ),
        leftParen: .leftParenToken(),
        rightParen: .rightParenToken()
      ) {
        LabeledExprSyntax(expression: genChaningMembers("\(type)", "self"))
        LabeledExprSyntax(
          label: "from",
          expression: DeclReferenceExprSyntax(baseName: .identifier("\(data)"))
        )
      }
    )
  }

  fileprivate static func genJSONDecoderDecodeExpr(
    variableName: PatternSyntax,
    type: TypeSyntax,
    data: PatternSyntax,
    defaultValueExpr: ExprSyntax?
  ) -> ExprSyntax {
    let jsonDecoderExpr = ExprSyntax(
      genJSONDecoderDecodeRightOperand(type: type, data: data, withQuestionMark: defaultValueExpr != nil)
    )

    let defaultExpr = ExprSyntax(
      InfixOperatorExprSyntax(
        leftOperand: TupleExprSyntax(elements: LabeledExprListSyntax([LabeledExprSyntax(expression: jsonDecoderExpr)])),
        operator: BinaryOperatorExprSyntax(operator: .binaryOperator("??")),
        rightOperand: defaultValueExpr ?? ExprSyntax(NilLiteralExprSyntax())
      )
    )

    return ExprSyntax(
      InfixOperatorExprSyntax(
        leftOperand: DeclReferenceExprSyntax(baseName: .identifier("\(variableName)")),
        operator: AssignmentExprSyntax(equal: .equalToken()),
        rightOperand: defaultValueExpr == nil ? jsonDecoderExpr : defaultExpr
      )
    )
  }
}

// MARK: Container Decode

extension CodeGenCore {
  static func genDecodeContainerDecl(
    bindingSpecifier: TokenSyntax = .keyword(.let),
    patternName: String = "container",
    codingKeysName: String = "CodingKeys"
  ) -> DeclSyntax {
    let initializerExpr = TryExprSyntax(
      expression: FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .identifier("decoder")),
          declName: DeclReferenceExprSyntax(baseName: .identifier("container"))
        ),
        leftParen: .leftParenToken(),
        rightParen: .rightParenToken()
      ) {
        LabeledExprSyntax(
          label: "keyedBy",
          expression: genChaningMembers(codingKeysName, "self")
        )
      }
    )

    return DeclSyntax(
      genVariableDecl(
        bindingSpecifier: bindingSpecifier,
        name: patternName,
        initializer: ExprSyntax(initializerExpr)
      )
    )
  }

  static func genNestedDecodeContainerDecl(
    bindingSpecifier: TokenSyntax = .keyword(.let),
    container: String,
    parentContainer: String,
    keyedBy: String,
    forKey: String
  ) -> DeclSyntax {
    let initializerExpr = TryExprSyntax(
      expression: FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: DeclReferenceExprSyntax(baseName: .identifier(parentContainer)),
          declName: DeclReferenceExprSyntax(baseName: .identifier("nestedContainer"))
        ),
        leftParen: .leftParenToken(),
        rightParen: .rightParenToken()
      ) {
        LabeledExprSyntax(
          label: "keyedBy",
          expression: genChaningMembers(keyedBy, "self")
        )
        LabeledExprSyntax(
          label: "forKey",
          expression: genChaningMembers(forKey)
        )
      }
    )

    return DeclSyntax(
      genVariableDecl(
        bindingSpecifier: bindingSpecifier,
        name: container,
        initializer: ExprSyntax(initializerExpr)
      )
    )
  }

  fileprivate static func genContainerDecodeExprRightOperand(
    containerName: String,
    patternName: PatternSyntax,
    isOptional: Bool,
    useDefaultOnFailure: Bool,
    defaultValueExpr: ExprSyntax?,
    type: TypeSyntax
  ) -> ExprSyntax {
    // determine which decode method to use, `decode` or `decodeIfPresent`
    let decodeIfPresent = isOptional || defaultValueExpr != nil

    // The main function call expression, like `container.decodeIfPresent(Type.self, forKey: .yourEnumCase)`
    let funcCallExpr = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier(containerName)),
        declName: DeclReferenceExprSyntax(baseName: .identifier(decodeIfPresent ? "decodeIfPresent" : "decode"))
      ),
      leftParen: .leftParenToken(),
      rightParen: .rightParenToken()
    ) {
      LabeledExprSyntax(expression: genChaningMembers("\(type)", "self"))
      LabeledExprSyntax(
        label: "forKey",
        expression: genChaningMembers("\(patternName)")
      )
    }

    guard useDefaultOnFailure else {
      return if defaultValueExpr != nil || isOptional {
        // The default option expression, if the expression is optional or has a default value,
        // the expression will be like `... ?? defaultValue`
        ExprSyntax(
          TryExprSyntax(
            expression: InfixOperatorExprSyntax(
              leftOperand: funcCallExpr,
              operator: BinaryOperatorExprSyntax(operator: .binaryOperator("??")),
              rightOperand: defaultValueExpr ?? ExprSyntax(NilLiteralExprSyntax())
            )
          )
        )
      } else {
        ExprSyntax(TryExprSyntax(expression: funcCallExpr))
      }
    }

    return if defaultValueExpr != nil || isOptional {
      ExprSyntax(
        InfixOperatorExprSyntax(
          leftOperand: TupleExprSyntax(
            leftParen: .leftParenToken(),
            elements: [
              LabeledExprSyntax(
                expression: TryExprSyntax(
                  questionOrExclamationMark: .infixQuestionMarkToken(leadingTrivia: .spaces(0)),
                  expression: funcCallExpr
                )
              )
            ],
            rightParen: .rightParenToken()
          ),
          operator: BinaryOperatorExprSyntax(operator: .binaryOperator("??")),
          rightOperand: defaultValueExpr ?? ExprSyntax(NilLiteralExprSyntax())
        )
      )
    } else {
      ExprSyntax(TryExprSyntax(expression: funcCallExpr))
    }
  }

  /// Generate the `decode` or `decodeIfPresent` expression for the given condition.
  ///
  ///
  /// The generated expression will be like below:
  ///
  /// ```swift
  /// yourProperty = try? [containerName].decodeIfPresent(Type.self, forKey: .yourEnumCase) ?? defaultValue
  /// ```
  ///
  /// - Parameters:
  ///   - patternName: The pattern name for the property.
  ///   - isOptional: Whether the property is optional. If true, the `decodeIfPresent` method will be used.
  ///   - useDefaultOnFailure: Whether to use the default value on failure.
  ///   - defaultValueExpr: The default value expression. If `nil`, the default value will not be used. If not `nil`,
  ///    the `decodeIfPresent` method will be used.
  ///   - type: The type of the property.
  static func genContainerDecodeExpr(
    containerName: String,
    variableName: PatternSyntax,
    patternName: PatternSyntax,
    isOptional: Bool,
    useDefaultOnFailure: Bool,
    defaultValueExpr: ExprSyntax?,
    type: TypeSyntax
  ) -> ExprSyntax {
    ExprSyntax(
      InfixOperatorExprSyntax(
        leftOperand: DeclReferenceExprSyntax(baseName: .identifier("\(variableName)")),
        operator: AssignmentExprSyntax(equal: .equalToken()),
        rightOperand: genContainerDecodeExprRightOperand(
          containerName: containerName,
          patternName: patternName,
          isOptional: isOptional,
          useDefaultOnFailure: useDefaultOnFailure,
          defaultValueExpr: defaultValueExpr,
          type: type
        )
      )
    )
  }

  /// Generate a variable declaration for the `decode` or `decodeIfPresent` expression.
  ///
  /// The generated declaration will be like below:
  /// ```swift
  /// let [variableName] = try? [containerName].decodeIfPresent([type].self, forKey: .[patternName]) ?? [defaultValueExpr]
  /// ```
  static func genContainerDecodeVariableDecl(
    bindingSpecifier: TokenSyntax = .keyword(.let),
    variableName: PatternSyntax,
    containerName: String,
    patternName: PatternSyntax,
    isOptional: Bool,
    useDefaultOnFailure: Bool,
    defaultValueExpr: ExprSyntax?,
    type: TypeSyntax
  ) -> DeclSyntax {
    DeclSyntax(
      genVariableDecl(
        bindingSpecifier: bindingSpecifier,
        name: "\(variableName)",
        initializer: genContainerDecodeExprRightOperand(
          containerName: containerName,
          patternName: patternName,
          isOptional: isOptional,
          useDefaultOnFailure: useDefaultOnFailure,
          defaultValueExpr: defaultValueExpr,
          type: type
        )
      )
    )
  }

  /// Generate raw data handle expression
  ///
  /// The generated expression will be like below:
  ///
  /// ```swift
  /// if ![rawStringName].isEmpty, let [rawDataName] = [rawStringName].data(using: .utf8) {
  ///   [key] = try JSONDecoder().decode([type].self, from: [rawDataName])
  /// } else {
  ///   throw DecodingError.valueNotFound(
  ///     String.self,
  ///     DecodingError.Context(
  ///       codingPath: [CodingKeys.[key]],
  ///       debugDescription: [message]
  ///     )
  ///   )
  /// }
  /// ```
  ///
  /// If the default value expression is not nil, the generated expression will be like below:
  ///
  /// ```swift
  /// if ![rawStringName].isEmpty, let [rawDataName] = [rawStringName].data(using: .utf8) {
  ///   [key] = (try? JSONDecoder().decode([type].self, from: [rawDataName])) ?? [defaultValueExpr]
  /// } else {
  ///   [key] = [defaultValueExpr]
  /// }
  /// ```
  static func genRawDataHandleExpr(
    key: PatternSyntax,
    rawDataName: PatternSyntax,
    rawStringName: PatternSyntax,
    defaultValueExpr: ExprSyntax?,
    codingPath: [(String, String)],
    type: TypeSyntax,
    message: String
  ) -> ExprSyntax {
    ExprSyntax(
      IfExprSyntax(
        conditions: [
          ConditionElementSyntax(
            condition: .expression(
              ExprSyntax(
                PrefixOperatorExprSyntax(
                  operator: .prefixOperator("!"),
                  expression: MemberAccessExprSyntax(
                    base: DeclReferenceExprSyntax(baseName: .identifier("\(rawStringName)")),
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
                pattern: rawDataName,
                initializer: InitializerClauseSyntax(
                  value: FunctionCallExprSyntax(
                    calledExpression: MemberAccessExprSyntax(
                      base: DeclReferenceExprSyntax(baseName: .identifier("\(rawStringName)")),
                      declName: DeclReferenceExprSyntax(baseName: .identifier("data"))
                    ),
                    leftParen: .leftParenToken(),
                    rightParen: .rightParenToken()
                  ) {
                    LabeledExprSyntax(
                      label: "using",
                      expression: genChaningMembers("utf8")
                    )
                  }
                )
              )
            )
          ),
        ],
        body: CodeBlockSyntax {
          CodeBlockItemSyntax(
            item: .expr(
              genJSONDecoderDecodeExpr(
                variableName: key,
                type: type,
                data: rawDataName,
                defaultValueExpr: defaultValueExpr
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
                      leftOperand: DeclReferenceExprSyntax(baseName: .identifier("\(key)")),
                      operator: AssignmentExprSyntax(equal: .equalToken()),
                      rightOperand: defaultValueExpr
                    )
                  )
                )
              )
            } else {
              CodeBlockItemSyntax(
                item: .stmt(
                  genValueNotFoundDecodingErrorThrowStmt(
                    type: TypeSyntax(IdentifierTypeSyntax(name: .identifier("String"))),
                    codingPath: codingPath,
                    message: message
                  )
                )
              )
            }
          }
        )
      )
    )
  }

  /// Generate a `DecodingError` throwing statement for the value not found error.
  ///
  /// The generated statement will be like below:
  /// ```swift
  /// throw DecodingError.valueNotFound(
  ///   [type].self,
  ///   DecodingError.Context(
  ///     codingPath: [CodingKeys.[codingPath]],
  ///     debugDescription: [message]
  ///   )
  /// )
  /// ```
  static func genValueNotFoundDecodingErrorThrowStmt(
    type: TypeSyntax,
    codingPath: [(String, String)],
    message: String
  ) -> StmtSyntax {
    StmtSyntax(
      ThrowStmtSyntax(
        expression: FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier("DecodingError")),
            declName: DeclReferenceExprSyntax(baseName: .identifier("valueNotFound"))
          ),
          leftParen: .leftParenToken(trailingTrivia: .newline),
          rightParen: .rightParenToken(leadingTrivia: .newline)
        ) {
          LabeledExprSyntax(
            leadingTrivia: .spaces(2),
            expression: genChaningMembers("\(type)", "self"),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
          LabeledExprSyntax(
            expression: FunctionCallExprSyntax(
              calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("DecodingError")),
                declName: DeclReferenceExprSyntax(baseName: .identifier("Context"))
              ),
              leftParen: .leftParenToken(),
              rightParen: .rightParenToken(leadingTrivia: .newline)
            ) {
              LabeledExprSyntax(
                leadingTrivia: .newline,
                label: "codingPath",
                colon: .colonToken(),
                expression: ArrayExprSyntax(
                  expressions: codingPath.map { key, value in
                    ExprSyntax(genChaningMembers(key, value))
                  }
                ),
                trailingComma: .commaToken(trailingTrivia: .newline)
              )
              LabeledExprSyntax(
                label: "debugDescription",
                colon: .colonToken(),
                expression: StringLiteralExprSyntax(content: message)
              )
            }
          )
        }
      )
    )
  }
}
