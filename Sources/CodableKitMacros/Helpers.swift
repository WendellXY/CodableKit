//
//  Helpers.swift
//  CodableKitMacros
//
//  Created by Wendell Wang on 2025/9/10.
//

@resultBuilder
struct ArrayBuilder<T> {
  static func buildBlock() -> [T] { [] }
  static func buildExpression(_ expression: T) -> [T] { [expression] }
  static func buildExpression(_ expression: T?) -> [T] { [expression].compactMap { $0 } }
  static func buildExpression(_ expression: [T]) -> [T] { expression }
  static func buildBlock(_ components: [T]...) -> [T] { components.flatMap { $0 } }
  static func buildArray(_ components: [[T]]) -> [T] { components.flatMap { $0 } }
  static func buildOptional(_ component: [T]?) -> [T] { component ?? [] }
  static func buildEither(first component: [T]) -> [T] { component }
  static func buildEither(second component: [T]) -> [T] { component }
  static func buildLimitedAvailability(_ component: [T]) -> [T] { component }
}

extension Array {
  init(@ArrayBuilder<Element> builder: () -> [Element]) { self = builder() }
}

extension Array {
  mutating func appendContentsOf(@ArrayBuilder<Element> builder: () -> [Element]) { self.append(contentsOf: builder()) }
}
