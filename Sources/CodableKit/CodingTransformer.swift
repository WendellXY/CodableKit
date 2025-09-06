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

// MARK: - Built-in Transformers

public struct DecodeAtKey<Key: CodingKey, Value: Decodable>: CodingTransformer {
  public typealias Output = Value

  let container: KeyedDecodingContainer<Key>
  let key: Key

  public init(_ container: KeyedDecodingContainer<Key>, for key: Key) {
    self.container = container
    self.key = key
  }

  public func transform(_ input: Result<Void, any Error>) -> Result<Output, any Error> {
    input.flatMap {
      Result {
        try container.decode(Output.self, forKey: key)
      }
    }
  }
}

public struct IdentityTransformer<Value>: CodingTransformer {
  public typealias Input = Value
  public typealias Output = Value

  public init() {}

  public func transform(_ input: Result<Input, any Error>) -> Result<Output, any Error> {
    input
  }
}

public struct DefaultOnFailureTransformer<Value>: BidirectionalCodingTransformer {
  public let defaultValue: Value

  public init(defaultValue: Value) {
    self.defaultValue = defaultValue
  }

  public func transform(_ input: Result<Value, any Error>) -> Result<Value, any Error> {
    switch input {
    case .success(let value): .success(value)
    case .failure: .success(defaultValue)
    }
  }
}

public struct RawStringDecodingTransformer<Value: Decodable>: CodingTransformer {
  public typealias Output = Value

  public let decoder: JSONDecoder

  public init(decoder: JSONDecoder = JSONDecoder()) {
    self.decoder = decoder
  }

  public func transform(_ input: Result<String, any Error>) -> Result<Value, any Error> {
    switch input {
    case .success(let string):
      Result {
        guard let data = string.data(using: .utf8) else {
          throw EncodingError.invalidValue(string, .init(codingPath: [], debugDescription: "Invalid UTF-8 string"))
        }
        return try decoder.decode(Value.self, from: data)
      }
    case .failure(let error):
      .failure(error)
    }
  }
}

public struct RawStringEncodingTransformer<Value: Encodable>: CodingTransformer {
  public let encoder: JSONEncoder

  public init(encoder: JSONEncoder = JSONEncoder()) {
    self.encoder = encoder
  }

  public func transform(_ input: Result<Value, any Error>) -> Result<String, any Error> {
    switch input {
    case .success(let value):
      Result {
        let data = try encoder.encode(value)
        if let string = String(data: data, encoding: .utf8) {
          return string
        } else {
          throw EncodingError.invalidValue(data, .init(codingPath: [], debugDescription: "Invalid UTF-8 data"))
        }
      }
    case .failure(let error):
      .failure(error)
    }
  }
}

public struct RawStringTransformer<Value: Decodable & Encodable>: BidirectionalCodingTransformer {
  private let transformer: Paired<RawStringEncodingTransformer<Value>, RawStringDecodingTransformer<Value>>

  public init(decoder: JSONDecoder = JSONDecoder(), encoder: JSONEncoder = JSONEncoder()) {
    self.transformer = Paired(
      transformer: RawStringEncodingTransformer(encoder: encoder),
      reversedTransformer: RawStringDecodingTransformer(decoder: decoder)
    )
  }

  public func transform(_ input: Result<Value, any Error>) -> Result<String, any Error> {
    transformer.transform(input)
  }

  public func reverseTransform(_ input: Result<String, any Error>) -> Result<Value, any Error> {
    transformer.reverseTransform(input)
  }
}

public struct IntegerToBooleanTransformer<Input: BinaryInteger>: BidirectionalCodingTransformer {
  public typealias Output = Bool

  public func transform(_ input: Result<Input, any Error>) -> Result<Bool, any Error> {
    input.map { $0 == 1 }
  }

  public func reverseTransform(_ input: Result<Bool, any Error>) -> Result<Input, any Error> {
    input.map { $0 ? 1 : 0 }
  }
}

public struct KeyPathTransformer<T, U: Decodable>: CodingTransformer {
  public typealias Input = T
  public typealias Output = U

  let keyPath: KeyPath<T, U>

  public init(keyPath: KeyPath<T, U>) {
    self.keyPath = keyPath
  }

  public func transform(_ input: Result<T, any Error>) -> Result<U, any Error> {
    input.map { $0[keyPath: keyPath] }
  }
}
