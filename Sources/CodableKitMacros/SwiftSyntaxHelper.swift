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

extension AttributeSyntax {
  internal var macroName: String {
    attributeName.as(IdentifierTypeSyntax.self)?.description ?? ""
  }

  internal var isCodableKeyMacro: Bool {
    switch macroName {
    case "CodableKey", "DecodableKey", "EncodableKey": true
    default: false
    }
  }
}

extension TokenSyntax {
  internal var isAccessModifierKeyword: Bool {
    accessModifiersKeywordSet.contains(text)
  }
}

extension DeclModifierSyntax {
  /// The access modifier to apply to synthesized protocol witnesses (`init(from:)` / `encode(to:)`).
  ///
  /// A `private` member matching a protocol requirement must be "as accessible as its enclosing
  /// type". For a `private` type the enclosing type is effectively `fileprivate`, so a `private`
  /// witness fails to satisfy the `Codable` requirement. Promoting `private` to `fileprivate`
  /// mirrors what the compiler does for its own synthesized `Codable` conformance. All other
  /// access levels are already as accessible as the type and are left unchanged.
  internal var witnessSafe: DeclModifierSyntax {
    guard name.text == TokenSyntax.keyword(.private).text else { return self }
    return with(\.name, .keyword(.fileprivate, leadingTrivia: name.leadingTrivia, trailingTrivia: name.trailingTrivia))
  }
}

extension LabeledExprListSyntax {
  func getExpr(label: String?) -> LabeledExprSyntax? {
    first(where: { $0.label?.text == label })
  }
}
