//
//  SwiftSyntaxHelper.swift
//  CodableKit
//
//  Created by Wendell Wang on 2024/8/19.
//

import SwiftSyntax

private let typePropertyKeywordSet: Set<String> = [
  TokenSyntax.keyword(.static).text,
  TokenSyntax.keyword(.class).text,
]

extension TokenSyntax {
  internal var isTypePropertyKeyword: Bool {
    typePropertyKeywordSet.contains(text)
  }
}

internal let accessModifiersKeywordSet: Set<String> = [
  TokenSyntax.keyword(.open).text,
  TokenSyntax.keyword(.public).text,
  TokenSyntax.keyword(.package).text,
  TokenSyntax.keyword(.internal).text,
  TokenSyntax.keyword(.private).text,
  TokenSyntax.keyword(.fileprivate).text,
]

extension TokenSyntax {
  internal var isAccessModifierKeyword: Bool {
    accessModifiersKeywordSet.contains(text)
  }
}

extension LabeledExprListSyntax {
  func getExpr(label: String?) -> LabeledExprSyntax? {
    first(where: { $0.label?.text == label })
  }
}
