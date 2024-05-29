//
//  CodeGenCore+GenDecode.swift
//  CodableKit
//
//  Created by WendellXY on 2024/5/29
//  Copyright © 2024 WendellXY. All rights reserved.
//

import SwiftSyntax

// MARK: JSONDecoder

extension CodeGenCore {
  fileprivate func genJSONDecoderDecodeRightOperand(
    type: TypeSyntax,
    data: PatternSyntax
  ) -> some ExprSyntaxProtocol {
    TryExprSyntax(
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
        LabeledExprSyntax(expression: genTypeExpr(typeName: "\(type)"))
        LabeledExprSyntax(
          label: "from",
          expression: DeclReferenceExprSyntax(baseName: .identifier("\(data)"))
        )
      }
    )
  }

  fileprivate func genJSONDecoderDecodeExpr(
    variableName: PatternSyntax,
    type: TypeSyntax,
    data: PatternSyntax
  ) -> ExprSyntax {
    ExprSyntax(
      InfixOperatorExprSyntax(
        leftOperand: DeclReferenceExprSyntax(baseName: .identifier("\(variableName)")),
        operator: AssignmentExprSyntax(equal: .equalToken()),
        rightOperand: genJSONDecoderDecodeRightOperand(type: type, data: data)
      )
    )
  }
}

// MARK: Container Decode

extension CodeGenCore {
  func genDecodeContainerDecl(
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
          expression: genTypeExpr(typeName: codingKeysName)
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

  fileprivate func genContainerDecodeExprRightOperand(
    patternName: PatternSyntax,
    isOptional: Bool,
    useDefaultOnFailure: Bool,
    defaultValueExpr: ExprSyntax?,
    type: TypeSyntax
  ) -> some ExprSyntaxProtocol {
    // determine which decode method to use, `decode` or `decodeIfPresent`
    let decodeIfPresent = isOptional || defaultValueExpr != nil

    // The main function call expression, like `container.decodeIfPresent(Type.self, forKey: .yourEnumCase)`
    let funcCallExpr = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("container")),
        declName: DeclReferenceExprSyntax(baseName: .identifier(decodeIfPresent ? "decodeIfPresent" : "decode"))
      ),
      leftParen: .leftParenToken(),
      rightParen: .rightParenToken()
    ) {
      LabeledExprSyntax(expression: genTypeExpr(typeName: "\(type)"))
      LabeledExprSyntax(label: "forKey", expression: genDotExpr(name: "\(patternName)"))
    }

    // The default option expression, if the expression is optional or has a default value,
    // the expression will be like `... ?? defaultValue`
    let defaultOptionalExpr = InfixOperatorExprSyntax(
      leftOperand: funcCallExpr,
      operator: BinaryOperatorExprSyntax(operator: .binaryOperator("??")),
      rightOperand: defaultValueExpr ?? ExprSyntax(NilLiteralExprSyntax())
    )

    let questionOrExclamationMark: TokenSyntax? = useDefaultOnFailure ? .infixQuestionMarkToken() : nil

    return if defaultValueExpr != nil || isOptional {
      TryExprSyntax(
        questionOrExclamationMark: questionOrExclamationMark,
        expression: defaultOptionalExpr
      )
    } else {
      TryExprSyntax(
        questionOrExclamationMark: questionOrExclamationMark,
        expression: funcCallExpr
      )
    }
  }

  /// Generate the `decode` or `decodeIfPresent` expression for the given condition.
  ///
  ///
  /// The generated expression will be like below:
  ///
  /// ```swift
  /// yourProperty = try? container.decodeIfPresent(Type.self, forKey: .yourEnumCase) ?? defaultValue
  /// ```
  ///
  /// - Parameters:
  ///   - patternName: The pattern name for the property.
  ///   - isOptional: Whether the property is optional. If true, the `decodeIfPresent` method will be used.
  ///   - useDefaultOnFailure: Whether to use the default value on failure.
  ///   - defaultValueExpr: The default value expression. If `nil`, the default value will not be used. If not `nil`,
  ///    the `decodeIfPresent` method will be used.
  ///   - type: The type of the property.
  func genContainerDecodeExpr(
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
  /// let [variableName] = try? container.decodeIfPresent([type].self, forKey: .[patternName]) ?? [defaultValueExpr]
  /// ```
  func genContainerDecodeVariableDecl(
    bindingSpecifier: TokenSyntax = .keyword(.let),
    variableName: PatternSyntax,
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
  /// if let [rawDataName] = [rawStringName].data(using: .utf8) {
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
  func genRawDataHandleExpr(
    key: PatternSyntax,
    rawDataName: PatternSyntax,
    rawStringName: PatternSyntax,
    type: TypeSyntax,
    message: String
  ) -> ExprSyntax {
    ExprSyntax(
      IfExprSyntax(
        conditions: [
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
                      expression: genDotExpr(name: "utf8")
                    )
                  }
                )
              )
            )
          )
        ],
        body: CodeBlockSyntax {
          CodeBlockItemSyntax(
            item: .expr(
              genJSONDecoderDecodeExpr(
                variableName: key,
                type: type,
                data: rawDataName
              )
            )
          )
        },
        elseKeyword: .keyword(.else),
        elseBody: .init(
          CodeBlockSyntax {
            CodeBlockItemSyntax(
              item: .stmt(
                genValueNotFoundDecodingErrorThrowStmt(
                  type: TypeSyntax(IdentifierTypeSyntax(name: .identifier("String"))),
                  codingPath: key,
                  message: message
                )
              )
            )
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
  func genValueNotFoundDecodingErrorThrowStmt(
    type: TypeSyntax,
    codingPath: PatternSyntax,
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
            expression: genTypeExpr(typeName: "\(type)"),
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
                  expressions: [
                    ExprSyntax(
                      MemberAccessExprSyntax(
                        base: DeclReferenceExprSyntax(baseName: .identifier("CodingKeys")),
                        declName: DeclReferenceExprSyntax(baseName: .identifier("\(codingPath)"))
                      )
                    )
                  ]
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
