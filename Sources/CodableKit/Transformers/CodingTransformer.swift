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

  /// Lifts this transformer to operate on optional values.
  ///
  /// A nil input produces a nil output without invoking the base transformer.
  /// An upstream failure is forwarded into the base transformer, so
  /// failure-recovering transformers (such as `DefaultOnFailureTransformer`)
  /// recover when lifted, producing `.some(recovered)`; non-recovering
  /// transformers propagate the failure unchanged.
  public func liftOptional() -> some CodingTransformer<Input?, Output?> {
    OptionalLifted(transformer: self)
  }

  /// Taps failures for observability without altering the result.
  ///
  /// The handler is invoked whenever the transformed result is a failure; the
  /// result is passed through unchanged in all cases.
  public func onFailure(
    _ handler: @escaping (any Error) -> Void
  ) -> some CodingTransformer<Input, Output> {
    OnFailure(transformer: self, handler: handler)
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

  /// Lifts this transformer to operate on optional values in both directions.
  ///
  /// Forward and reverse share the same semantics: a nil input produces a nil
  /// output without invoking the base transformer, and an upstream failure is
  /// forwarded into the base transformer, so failure-recovering transformers
  /// (such as `DefaultOnFailureTransformer`) recover when lifted, producing
  /// `.some(recovered)`; non-recovering transformers propagate the failure
  /// unchanged.
  public func liftOptional() -> some BidirectionalCodingTransformer<Input?, Output?> {
    OptionalLifted(transformer: self)
  }

  /// Taps failures for observability without altering the result.
  ///
  /// The handler is invoked whenever the transformed result is a failure in
  /// either direction — both `transform(_:)` and `reverseTransform(_:)` report
  /// their failures — and the result is passed through unchanged in all cases.
  public func onFailure(
    _ handler: @escaping (any Error) -> Void
  ) -> some BidirectionalCodingTransformer<Input, Output> {
    OnFailure(transformer: self, handler: handler)
  }
}

extension BidirectionalCodingTransformer where Input == Output {
  public func reverseTransform(
    _ input: Result<Output, any Error>
  ) -> Result<Input, any Error> {
    transform(input)
  }
}
