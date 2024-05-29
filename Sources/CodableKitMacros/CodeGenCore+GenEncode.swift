//
//  CodeGenCore+GenEncode.swift
//  CodableKit
//
//  Created by WendellXY on 2024/5/29
//  Copyright © 2024 WendellXY. All rights reserved.
//

import SwiftSyntax

extension CodeGenCore {
  func genEncodeContainerDecl(
    bindingSpecifier: TokenSyntax = .keyword(.var),
    patternName: String = "container",
    codingKeysName: String = "CodingKeys"
  ) -> VariableDeclSyntax {
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
        expression: genTypeExpr(typeName: codingKeysName)
      )
    }

    return genVariableDecl(
      bindingSpecifier: bindingSpecifier,
      name: patternName,
      initializer: ExprSyntax(initializerExpr)
    )
  }
}
