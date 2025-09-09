//
//  CodeGenCore+GenEncode.swift
//  CodableKit
//
//  Created by WendellXY on 2024/5/29
//  Copyright © 2024 WendellXY. All rights reserved.
//

import SwiftSyntax

extension CodeGenCore {
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
            condition: .expression("let \(rawStringName) = String(data: \(rawDataName), encoding: .utf8)"),
            trailingTrivia: .spaces(1)
          )
        ],
        body: CodeBlockSyntax {
          "try \(raw: containerName).\(raw: isOptional && !explicitNil ? "encodeIfPresent" : "encode")(\(raw: rawStringName), forKey: \(genChainingMembers("\(key)")))"
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
          calledExpression: ExprSyntax("EncodingError.invalidValue"),
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
              calledExpression: ExprSyntax("EncodingError.Context"),
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
