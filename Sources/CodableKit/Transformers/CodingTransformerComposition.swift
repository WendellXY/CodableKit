//
//  CodingTransformerComposition.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/9/6.
//

import Foundation

// MARK: - Composed Transformers

struct Chained<T, U>: CodingTransformer
where
  T: CodingTransformer,
  U: CodingTransformer,
  T.Output == U.Input
{
  let transformer1: T
  let transformer2: U

  init(transformer1: T, transformer2: U) {
    self.transformer1 = transformer1
    self.transformer2 = transformer2
  }

  func transform(_ input: Result<T.Input, any Error>) -> Result<U.Output, any Error> {
    transformer2.transform(transformer1.transform(input))
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

struct Reversed<T>: BidirectionalCodingTransformer
where
  T: BidirectionalCodingTransformer
{
  let transformer: T

  init(transformer: T) {
    self.transformer = transformer
  }

  func transform(_ input: Result<T.Output, any Error>) -> Result<T.Input, any Error> {
    transformer.reverseTransform(input)
  }

  func reverseTransform(_ input: Result<T.Input, any Error>) -> Result<T.Output, any Error> {
    transformer.transform(input)
  }
}

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

  init(transformer: T, reversedTransformer: U) {
    self.transformer = transformer
    self.reversedTransformer = reversedTransformer
  }

  func transform(_ input: Result<Input, any Error>) -> Result<Output, any Error> {
    transformer.transform(input)
  }

  func reverseTransform(_ input: Result<Output, any Error>) -> Result<Input, any Error> {
    reversedTransformer.transform(input)
  }
}

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

enum WrappedError: Error {
  case valueNotFound
}

struct Wrapped<T>: CodingTransformer {
  let defaultValue: T?

  init(defaultValue: T?) {
    self.defaultValue = defaultValue
  }

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

struct Optional<T>: CodingTransformer {
  init() {}

  func transform(_ input: Result<T, any Error>) -> Result<T?, any Error> {
    input.flatMap { value in
      .success(value)
    }
  }
}
