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
  static func genJSONDecoderVariableDecl(
    variableName: String = "__ckDecoder"
  ) -> DeclSyntax {
    DeclSyntax(
      genVariableDecl(
        bindingSpecifier: .keyword(.let),
        name: variableName,
        initializer: ExprSyntax("JSONDecoder()")
      )
    )
  }
  fileprivate static func genJSONDecoderDecodeRightOperand(
    type: TypeSyntax,
    data: PatternSyntax,
    withQuestionMark: Bool,
    decoderVarName: String? = nil
  ) -> some ExprSyntaxProtocol {
    TryExprSyntax(
      questionOrExclamationMark: withQuestionMark ? .infixQuestionMarkToken(leadingTrivia: .spaces(0)) : nil,
      expression: FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: decoderVarName == nil
            ? ExprSyntax("JSONDecoder()")
            : ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(decoderVarName!))),
          declName: DeclReferenceExprSyntax(baseName: .identifier("decode"))
        ),
        leftParen: .leftParenToken(),
        rightParen: .rightParenToken()
      ) {
        LabeledExprSyntax(expression: genChainingMembers("\(type)", "self"))
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
    defaultValueExpr: ExprSyntax?,
    decoderVarName: String? = nil
  ) -> ExprSyntax {
    let jsonDecoderExpr = ExprSyntax(
      genJSONDecoderDecodeRightOperand(
        type: type,
        data: data,
        withQuestionMark: defaultValueExpr != nil,
        decoderVarName: decoderVarName
      )
    )

    let defaultExpr: ExprSyntax = "(\(jsonDecoderExpr)) ?? \(defaultValueExpr ?? "nil")"

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
    DeclSyntax(
      genVariableDecl(
        bindingSpecifier: bindingSpecifier,
        name: patternName,
        initializer: ExprSyntax("try decoder.container(keyedBy: \(raw: codingKeysName).self)")
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
        calledExpression: ExprSyntax("\(raw: parentContainer).nestedContainer"),
        leftParen: .leftParenToken(),
        rightParen: .rightParenToken()
      ) {
        LabeledExprSyntax(
          label: "keyedBy",
          expression: genChainingMembers(keyedBy, "self")
        )
        LabeledExprSyntax(
          label: "forKey",
          expression: genChainingMembers(forKey)
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
      LabeledExprSyntax(expression: genChainingMembers("\(type)", "self"))
      LabeledExprSyntax(
        label: "forKey",
        expression: genChainingMembers("\(patternName)")
      )
    }

    guard useDefaultOnFailure else {
      return if defaultValueExpr != nil || isOptional {
        // The default option expression, if the expression is optional or has a default value,
        // the expression will be like `... ?? defaultValue`
        "try \(funcCallExpr) ?? \(defaultValueExpr ?? "nil")"
      } else {
        "try \(funcCallExpr)"
      }
    }

    return if defaultValueExpr != nil || isOptional {
      "(try? \(funcCallExpr)) ?? \(defaultValueExpr ?? "nil")"
    } else {
      "try \(funcCallExpr)"
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
    type: TypeSyntax,
    decoderVarName: String? = nil
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
    message: String,
    decoderVarName: String? = nil
  ) -> ExprSyntax {
    ExprSyntax(
      IfExprSyntax(
        conditions: [
          ConditionElementSyntax(
            condition: .expression("!\(rawStringName).isEmpty"),
            trailingComma: .commaToken(trailingTrivia: .spaces(1))
          ),
          ConditionElementSyntax(
            condition: .expression("let \(rawDataName) = \(rawStringName).data(using: .utf8)"),
            trailingTrivia: .spaces(1)
          ),
        ],
        body: CodeBlockSyntax {
          CodeBlockItemSyntax(
            item: .expr(
              genJSONDecoderDecodeExpr(
                variableName: key,
                type: type,
                data: rawDataName,
                defaultValueExpr: defaultValueExpr,
                decoderVarName: decoderVarName
              )
            )
          )
        },
        elseKeyword: .keyword(.else),
        elseBody: .init(
          CodeBlockSyntax {
            if let defaultValueExpr {
              CodeBlockItemSyntax(item: .expr("\(key) = \(defaultValueExpr)"))
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
          calledExpression: ExprSyntax("DecodingError.valueNotFound"),
          leftParen: .leftParenToken(trailingTrivia: .newline),
          rightParen: .rightParenToken(leadingTrivia: .newline)
        ) {
          LabeledExprSyntax(
            leadingTrivia: .spaces(2),
            expression: genChainingMembers("\(type)", "self"),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
          LabeledExprSyntax(
            expression: FunctionCallExprSyntax(
              calledExpression: ExprSyntax("DecodingError.Context"),
              leftParen: .leftParenToken(),
              rightParen: .rightParenToken(leadingTrivia: .newline)
            ) {
              LabeledExprSyntax(
                leadingTrivia: .newline,
                label: "codingPath",
                colon: .colonToken(),
                expression: ArrayExprSyntax(
                  expressions: codingPath.map { key, value in
                    ExprSyntax(genChainingMembers(key, value))
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
