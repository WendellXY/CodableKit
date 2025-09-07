//
//  CodingTransformer.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/9/6.
//

import Foundation

public protocol CodingTransformer<Input, Output> {
  associatedtype Input
  associatedtype Output

  func transform(_ input: Result<Input, any Error>) -> Result<Output, any Error>
}

extension CodingTransformer {
  public func chained<T>(
    _ next: some CodingTransformer<Output, T>
  ) -> some CodingTransformer<Input, T> {
    Chained(transformer1: self, transformer2: next)
  }

  public func paired<T>(
    _ reversed: some CodingTransformer<Output, Input>
  ) -> some BidirectionalCodingTransformer<Input, Output> {
    Paired(transformer: self, reversedTransformer: reversed)
  }

  public func conditionally(
    condition: Bool,
    transformer: @escaping () -> some CodingTransformer<Output, Output>
  ) -> some CodingTransformer<Input, Output> {
    self.chained(
      Conditionally(condition: condition, transformer: transformer)
    )
  }

  public func wrapped<T>(
    defaultValue: T? = nil
  ) -> some CodingTransformer<Input, T> where Self.Output == T? {
    self.chained(
      Wrapped(defaultValue: defaultValue)
    )
  }

  public func optional() -> some CodingTransformer<Input, Output?> {
    self.chained(Optional())
  }
}

public protocol BidirectionalCodingTransformer<Input, Output>: CodingTransformer {
  func reverseTransform(_ input: Result<Output, any Error>) -> Result<Input, any Error>
}

extension BidirectionalCodingTransformer {
  public func chained<T>(
    _ next: some BidirectionalCodingTransformer<Output, T>
  ) -> some BidirectionalCodingTransformer<Input, T> {
    Chained(transformer1: self, transformer2: next)
  }

  public var reversed: some BidirectionalCodingTransformer<Output, Input> {
    Reversed(transformer: self)
  }
}

extension BidirectionalCodingTransformer where Input == Output {
  public func reverseTransform(
    _ input: Result<Output, any Error>
  ) -> Result<Input, any Error> {
    transform(input)
  }
}
