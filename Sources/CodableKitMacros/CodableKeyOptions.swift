//
//  CodableKeyOptions.swift
//  CodableKit
//
//  Created by Wendell on 4/3/24.
//

import CodableKitCore
import SwiftSyntax

extension CodableKeyOptions {
  init(from expr: MemberAccessExprSyntax) {
    self =
      switch expr.declName.baseName.text {
      case "ignored": .ignored
      case "explicitNil": .explicitNil
      case "generateCustomKey": .generateCustomKey
      case "transcodeRawString": .transcodeRawString
      case "useDefaultOnFailure": .useDefaultOnFailure
      case "safeTranscodeRawString": .safeTranscodeRawString
      case "lossy": .lossy
      default: .default
      }
  }
}

extension CodableKeyOptions {
  /// Parse the options from 1a `LabelExprSyntax`. It support parse a single element like `.default`,
  /// or multiple elements like `[.ignored, .explicitNil]`
  static func parse(from labeledExpr: LabeledExprSyntax) -> Self {
    if let memberAccessExpr = labeledExpr.expression.as(MemberAccessExprSyntax.self) {
      Self.init(from: memberAccessExpr)
    } else if let arrayExpr = labeledExpr.expression.as(ArrayExprSyntax.self) {
      arrayExpr.elements
        .compactMap { $0.expression.as(MemberAccessExprSyntax.self) }
        .map { Self.init(from: $0) }
        .reduce(.default) { $0.union($1) }
    } else {
      .default
    }
  }
}

extension LabeledExprSyntax {
  /// Parse the options from a `LabelExprSyntax`. It support parse a single element like .default,
  /// or multiple elements like [.ignored, .explicitNil].
  ///
  /// This is a convenience method to use for chaining.
  func parseOptions() -> CodableKeyOptions {
    CodableKeyOptions.parse(from: self)
  }
}

extension CodableKeyMacro {
  /// Options for customizing the behavior of a `CodableKey`.
  typealias Options = CodableKeyOptions
}

extension DecodableKeyMacro {
  /// Options for customizing the behavior of a `DecodeKey`.
  typealias Options = CodableKeyOptions
}

extension EncodableKeyMacro {
  /// Options for customizing the behavior of an `EncodeKey`.
  typealias Options = CodableKeyOptions
}
