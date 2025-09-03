//
//  CodeGenCore+GenEncode.swift
//  CodableKit
//
//  Created by WendellXY on 2024/5/29
//  Copyright © 2024 WendellXY. All rights reserved.
//

import SwiftSyntax

// MARK: JSONEncoder

extension CodeGenCore {
  fileprivate static func genJSONEncoderEncodeRightOperand(
    instance: PatternSyntax,
    encoderVarName: String? = nil
  ) -> some ExprSyntaxProtocol {
    TryExprSyntax(
      expression: FunctionCallExprSyntax(
        calledExpression: MemberAccessExprSyntax(
          base: encoderVarName == nil
            ? ExprSyntax(
              FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("JSONEncoder")),
                leftParen: .leftParenToken(),
                rightParen: .rightParenToken(),
                argumentsBuilder: {}
              )
            )
            : ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(encoderVarName!))),
          declName: DeclReferenceExprSyntax(baseName: .identifier("encode"))
        ),
        leftParen: .leftParenToken(),
        rightParen: .rightParenToken()
      ) {
        LabeledExprSyntax(
          expression: DeclReferenceExprSyntax(baseName: .identifier("\(instance)"))
        )
      }
    )
  }

  static func genJSONEncoderEncodeDecl(
    bindingSpecifier: TokenSyntax = .keyword(.let),
    variableName: PatternSyntax,
    instance: PatternSyntax,
    encoderVarName: String? = nil
  ) -> DeclSyntax {
    DeclSyntax(
      VariableDeclSyntax(bindingSpecifier: bindingSpecifier) {
        PatternBindingSyntax(
          pattern: variableName,
          initializer: InitializerClauseSyntax(
            value: genJSONEncoderEncodeRightOperand(instance: instance, encoderVarName: encoderVarName)
          )
        )
      }
    )
  }

  static func genJSONEncoderVariableDecl(
    variableName: String = "__ckEncoder"
  ) -> DeclSyntax {
    let initializerExpr = FunctionCallExprSyntax(
      calledExpression: DeclReferenceExprSyntax(baseName: .identifier("JSONEncoder")),
      leftParen: .leftParenToken(),
      rightParen: .rightParenToken(),
      argumentsBuilder: {}
    )
    return DeclSyntax(
      genVariableDecl(
        bindingSpecifier: .keyword(.let),
        name: variableName,
        initializer: ExprSyntax(initializerExpr)
      )
    )
  }
}

// MARK: Container Encode

extension CodeGenCore {
  static func genEncodeContainerDecl(
    bindingSpecifier: TokenSyntax = .keyword(.var),
    patternName: String = "container",
    codingKeysName: String = "CodingKeys"
  ) -> DeclSyntax {
    let initializerExpr = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier("encoder")),
        declName: DeclReferenceExprSyntax(baseName: .identifier("container"))
      ),
      leftParen: .leftParenToken(),
      rightParen: .rightParenToken()
    ) {
      LabeledExprSyntax(
        label: "keyedBy",
        expression: genChainingMembers(codingKeysName, "self")
      )
    }

    return DeclSyntax(
      genVariableDecl(
        bindingSpecifier: bindingSpecifier,
        name: patternName,
        initializer: ExprSyntax(initializerExpr)
      )
    )
  }

  static func genNestedEncodeContainerDecl(
    bindingSpecifier: TokenSyntax = .keyword(.var),
    container: String,
    parentContainer: String,
    keyedBy: String,
    forKey: String
  ) -> DeclSyntax {
    let initializerExpr = FunctionCallExprSyntax(
      calledExpression: MemberAccessExprSyntax(
        base: DeclReferenceExprSyntax(baseName: .identifier(parentContainer)),
        declName: DeclReferenceExprSyntax(baseName: .identifier("nestedContainer"))
      ),
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

    return DeclSyntax(
      genVariableDecl(
        bindingSpecifier: bindingSpecifier,
        name: container,
        initializer: ExprSyntax(initializerExpr)
      )
    )
  }

  /// Generate the container encode expression.
  ///
  /// The generated expression is like:
  ///
  /// ```swift
  /// try [containerName].encodeIfPresent([patternName], forKey: .[patternName])
  /// ```
  ///
  /// - Parameters:
  ///   - containerName: The name of the container.
  ///   - key: The key of the encoding value.
  ///   - patternName: The name of the pattern.
  ///   - isOptional: Is the variable optional.
  ///   - explicitNil: Should encode nil explicitly.
  static func genContainerEncodeExpr(
    containerName: String,
    key: PatternSyntax,
    patternName: PatternSyntax,
    isOptional: Bool,
    explicitNil: Bool
  ) -> ExprSyntax {
    let encodeFuncName = isOptional && !explicitNil ? "encodeIfPresent" : "encode"
    return ExprSyntax(
      TryExprSyntax(
        expression: FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier(containerName)),
            declName: DeclReferenceExprSyntax(baseName: .identifier(encodeFuncName))
          ),
          leftParen: .leftParenToken(),
          rightParen: .rightParenToken()
        ) {
          LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("\(patternName)")))
          LabeledExprSyntax(label: "forKey", expression: genChainingMembers("\(key)"))
        }
      )
    )
  }

  /// Generate raw data handle expression
  ///
  /// The generated expression will be like below:
  ///
  /// ```swift
  /// if let [rawStringName] = String(data: [rawDataName], encoding: .utf8) {
  ///   try [containerName].encode([rawStringName], forKey: .[key])
  /// } else {
  ///   throw EncodingError.invalidValue(
  ///     [rawDataName],
  ///     EncodingError.Context(
  ///       codingPath: [CodingKeys.[key]],
  ///       debugDescription: [message]
  ///     )
  ///   )
  /// }
  /// ```
  static func genEncodeRawDataHandleExpr(
    key: PatternSyntax,
    rawDataName: PatternSyntax,
    rawStringName: PatternSyntax,
    containerName: String,
    codingPath: [(String, String)],
    message: String,
    isOptional: Bool,
    explicitNil: Bool
  ) -> ExprSyntax {
    ExprSyntax(
      IfExprSyntax(
        conditions: [
          ConditionElementSyntax(
            condition: .optionalBinding(
              OptionalBindingConditionSyntax(
                bindingSpecifier: .keyword(.let),
                pattern: rawStringName,
                initializer: InitializerClauseSyntax(
                  value: FunctionCallExprSyntax(
                    calledExpression: DeclReferenceExprSyntax(baseName: .identifier("String")),
                    leftParen: .leftParenToken(),
                    rightParen: .rightParenToken()
                  ) {
                    LabeledExprSyntax(
                      label: "data",
                      expression: DeclReferenceExprSyntax(baseName: .identifier("\(rawDataName)"))
                    )
                    LabeledExprSyntax(label: "encoding", expression: genChainingMembers("utf8"))
                  }
                )
              )
            )
          )
        ],
        body: CodeBlockSyntax {
          CodeBlockItemSyntax(
            item: .expr(
              genContainerEncodeExpr(
                containerName: containerName,
                key: key,
                patternName: rawStringName,
                isOptional: isOptional,
                explicitNil: explicitNil
              )
            )
          )
        },
        elseKeyword: .keyword(.else),
        elseBody: .init(
          CodeBlockSyntax {
            CodeBlockItemSyntax(
              item: .stmt(
                genInvalidValueEncodingErrorThrowStmt(
                  data: rawDataName,
                  codingPath: codingPath,
                  message: message
                )
              )
            )
          }
        )
      )
    )
  }

  /// Generate a `EncodingError` throwing statement for the value is invalid.
  ///
  /// The generated statement will be like below:
  /// ```swift
  /// throw EncodingError.invalidValue(
  ///   [data],
  ///   EncodingError.Context(
  ///     codingPath: [CodingKeys.[codingPath]],
  ///     debugDescription: [message]
  ///   )
  /// )
  /// ```
  static func genInvalidValueEncodingErrorThrowStmt(
    data: PatternSyntax,
    codingPath: [(String, String)],
    message: String
  ) -> StmtSyntax {
    StmtSyntax(
      ThrowStmtSyntax(
        expression: FunctionCallExprSyntax(
          calledExpression: MemberAccessExprSyntax(
            base: DeclReferenceExprSyntax(baseName: .identifier("EncodingError")),
            declName: DeclReferenceExprSyntax(baseName: .identifier("invalidValue"))
          ),
          leftParen: .leftParenToken(trailingTrivia: .newline),
          rightParen: .rightParenToken(leadingTrivia: .newline)
        ) {
          LabeledExprSyntax(
            leadingTrivia: .spaces(2),
            expression: DeclReferenceExprSyntax(baseName: .identifier("\(data)")),
            trailingComma: .commaToken(trailingTrivia: .newline)
          )
          LabeledExprSyntax(
            expression: FunctionCallExprSyntax(
              calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("EncodingError")),
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
