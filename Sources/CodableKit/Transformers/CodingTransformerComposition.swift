//
//  CodingTransformerComposition.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/9/6.
//

import Foundation

// MARK: - Composed Transformers

/// A composition that feeds the output of the first transformer into the second.
///
/// Use `a.chained(b)` to build a pipeline `a -> b`. Failures are propagated.
struct Chained<T, U>: CodingTransformer
where
  T: CodingTransformer,
  U: CodingTransformer,
  T.Output == U.Input
{
  let transformer1: T
  let transformer2: U

  func transform(_ input: Result<T.Input, any Error>) -> Result<U.Output, any Error> {
    transformer2.transform(transformer1.transform(input))
  }
}

/// Adapts a throwing closure into a one-way transformer.
struct MapTransformer<Input, Output>: CodingTransformer {
  let transformClosure: (Input) throws -> Output

  func transform(_ input: Result<Input, any Error>) -> Result<Output, any Error> {
    input.flatMap { value in
      Result {
        try transformClosure(value)
      }
    }
  }
}

extension Chained: BidirectionalCodingTransformer
where
  T: BidirectionalCodingTransformer,
  U: BidirectionalCodingTransformer
{
  func reverseTransform(_ input: Result<U.Output, any Error>) -> Result<T.Input, any Error> {
    transformer1.reverseTransform(transformer2.reverseTransform(input))
  }
}

/// Adapts a bidirectional transformer into its inverse direction.
///
/// For a transformer `T: BidirectionalCodingTransformer<A, B>`, `Reversed(T)`
/// behaves as `BidirectionalCodingTransformer<B, A>` by swapping directions.
struct Reversed<T>: BidirectionalCodingTransformer
where
  T: BidirectionalCodingTransformer
{
  let transformer: T

  func transform(_ input: Result<T.Output, any Error>) -> Result<T.Input, any Error> {
    transformer.reverseTransform(input)
  }

  func reverseTransform(_ input: Result<T.Input, any Error>) -> Result<T.Output, any Error> {
    transformer.transform(input)
  }
}

/// Couples two one-way transformers into a bidirectional pair.
///
/// Useful when you have independent forward and reverse transformers and want
/// a `BidirectionalCodingTransformer` facade for composition.
struct Paired<T, U>: BidirectionalCodingTransformer
where
  T: CodingTransformer,
  U: CodingTransformer,
  T.Input == U.Output,
  T.Output == U.Input
{
  typealias Input = T.Input
  typealias Output = T.Output

  let transformer: T
  let reversedTransformer: U

  func transform(_ input: Result<Input, any Error>) -> Result<Output, any Error> {
    transformer.transform(input)
  }

  func reverseTransform(_ input: Result<Output, any Error>) -> Result<Input, any Error> {
    reversedTransformer.transform(input)
  }
}

/// Conditionally applies an in-place transformer when `condition` is true.
///
/// When false, the input result is passed through unchanged.
struct Conditionally<T>: CodingTransformer
where
  T: CodingTransformer,
  T.Input == T.Output
{
  let condition: Bool
  let transformer: () -> T

  typealias Input = T.Input
  typealias Output = T.Output

  init(condition: Bool, transformer: @escaping () -> T) {
    self.condition = condition
    self.transformer = transformer
  }

  func transform(_ input: Result<Input, any Error>) -> Result<Output, any Error> {
    if condition {
      transformer().transform(input)
    } else {
      input
    }
  }
}

/// Errors that can be thrown by `Wrapped` when no value or default exists.
enum WrappedError: Error {
  case valueNotFound
}

/// Lifts `Result<T?, Error>` into `Result<T, Error>` with an optional default.
///
/// If the incoming optional is nil and a `defaultValue` is provided, the default
/// is used; otherwise a `.valueNotFound` error is produced.
struct Wrapped<T>: CodingTransformer {
  let defaultValue: T?

  func transform(_ input: Result<T?, any Error>) -> Result<T, any Error> {
    input.flatMap { value in
      if let value {
        .success(value)
      } else if let defaultValue {
        .success(defaultValue)
      } else {
        .failure(WrappedError.valueNotFound)
      }
    }
  }
}

/// Wraps a non-optional value into an optional result for further chaining.
struct Optional<T>: CodingTransformer {
  func transform(_ input: Result<T, any Error>) -> Result<T?, any Error> {
    input.flatMap { value in
      .success(value)
    }
  }
}

/// Lifts a transformer over optional values.
///
/// A nil input passes through as a nil output; a non-nil input runs through
/// the base transformer and its output is wrapped. Failures are forwarded to
/// the base transformer so failure-recovering transformers keep working when
/// lifted.
struct OptionalLifted<T>: CodingTransformer
where
  T: CodingTransformer
{
  typealias Input = T.Input?
  typealias Output = T.Output?

  let transformer: T

  func transform(_ input: Result<T.Input?, any Error>) -> Result<T.Output?, any Error> {
    switch input {
    case .success(.some(let value)):
      transformer.transform(.success(value)).map { $0 as T.Output? }
    case .success(.none):
      .success(nil)
    case .failure(let error):
      transformer.transform(.failure(error)).map { $0 as T.Output? }
    }
  }
}

extension OptionalLifted: BidirectionalCodingTransformer
where
  T: BidirectionalCodingTransformer
{
  func reverseTransform(_ input: Result<T.Output?, any Error>) -> Result<T.Input?, any Error> {
    switch input {
    case .success(.some(let value)):
      transformer.reverseTransform(.success(value)).map { $0 as T.Input? }
    case .success(.none):
      .success(nil)
    case .failure(let error):
      transformer.reverseTransform(.failure(error)).map { $0 as T.Input? }
    }
  }
}

/// Passes results through unchanged while reporting failures to a handler.
///
/// The handler is invoked with the error whenever the transformed result is a
/// failure; it cannot alter the result. Useful for logging malformed payloads
/// that would otherwise be silently swallowed downstream.
struct OnFailure<T>: CodingTransformer
where
  T: CodingTransformer
{
  typealias Input = T.Input
  typealias Output = T.Output

  let transformer: T
  let handler: (any Error) -> Void

  func transform(_ input: Result<Input, any Error>) -> Result<Output, any Error> {
    let output = transformer.transform(input)
    if case .failure(let error) = output {
      handler(error)
    }
    return output
  }
}

extension OnFailure: BidirectionalCodingTransformer
where
  T: BidirectionalCodingTransformer
{
  func reverseTransform(_ input: Result<T.Output, any Error>) -> Result<T.Input, any Error> {
    let output = transformer.reverseTransform(input)
    if case .failure(let error) = output {
      handler(error)
    }
    return output
  }
}
