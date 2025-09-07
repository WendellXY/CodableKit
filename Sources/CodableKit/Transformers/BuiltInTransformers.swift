//
//  BuiltInTransformers.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/9/6.
//

import Foundation

/// Decodes a concrete `Value` at a given `CodingKey` from a keyed container.
///
/// Start a pipeline with `Result.success(())` and use this transformer to fetch
/// the field as the first step when building manual chains.
public struct DecodeAtKey<Key: CodingKey, Value: Decodable>: CodingTransformer {
  let container: KeyedDecodingContainer<Key>
  let key: Key

  public init(_ container: KeyedDecodingContainer<Key>, for key: Key) {
    self.container = container
    self.key = key
  }

  public func transform(_ input: Result<Void, any Error>) -> Result<Value, any Error> {
    input.flatMap {
      Result {
        try container.decode(Output.self, forKey: key)
      }
    }
  }
}

/// Decodes an optional `Value` if present at a given `CodingKey`.
///
/// Produces `nil` when the key is absent or explicitly `null`.
public struct DecodeAtKeyIfPresent<Key: CodingKey, Value: Decodable>: CodingTransformer {
  let container: KeyedDecodingContainer<Key>
  let key: Key

  public init(_ container: KeyedDecodingContainer<Key>, for key: Key) {
    self.container = container
    self.key = key
  }

  public func transform(_ input: Result<Void, any Error>) -> Result<Value?, any Error> {
    input.flatMap {
      Result {
        try container.decodeIfPresent(Value.self, forKey: key)
      }
    }
  }
}

/// Pass-through transformer. Useful as a placeholder or for API symmetry.
public struct IdentityTransformer<Value>: CodingTransformer {
  public typealias Input = Value
  public typealias Output = Value

  public init() {}

  public func transform(_ input: Result<Input, any Error>) -> Result<Output, any Error> {
    input
  }
}

/// Converts any failure into a success with `defaultValue` when provided.
///
/// The reverse direction is identical to the forward direction for same-type
/// defaults, so only `transform(_)` is implemented.
public struct DefaultOnFailureTransformer<Value>: BidirectionalCodingTransformer {
  public let defaultValue: Value?

  public init(defaultValue: Value?) {
    self.defaultValue = defaultValue
  }

  public func transform(_ input: Result<Value, any Error>) -> Result<Value, any Error> {
    switch input {
    case .success(let value): .success(value)
    case .failure(let error):
      if let defaultValue {
        .success(defaultValue)
      } else {
        .failure(error)
      }
    }
  }
}

/// Decodes a `Value` from a JSON string that contains serialized JSON.
///
/// Useful for APIs that nest objects as raw JSON strings.
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

/// Encodes a `Value` into a JSON string containing its serialized representation.
///
/// Useful for APIs that expect objects as stringified JSON.
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

/// Bidirectional wrapper combining raw-string encode and decode transforms.
public struct RawStringTransformer<Value: Decodable & Encodable>: BidirectionalCodingTransformer {
  // Forward (transform): String -> Value; Reverse (reverseTransform): Value -> String
  private let transformer: Paired<RawStringDecodingTransformer<Value>, RawStringEncodingTransformer<Value>>

  public init(decoder: JSONDecoder = JSONDecoder(), encoder: JSONEncoder = JSONEncoder()) {
    self.transformer = Paired(
      transformer: RawStringDecodingTransformer(decoder: decoder),
      reversedTransformer: RawStringEncodingTransformer(encoder: encoder)
    )
  }

  public func transform(_ input: Result<String, any Error>) -> Result<Value, any Error> {
    transformer.transform(input)
  }

  public func reverseTransform(_ input: Result<Value, any Error>) -> Result<String, any Error> {
    transformer.reverseTransform(input)
  }
}

/// Maps `0/1` integers to booleans and back.
public struct IntegerToBooleanTransformer<Input: BinaryInteger>: BidirectionalCodingTransformer {
  public typealias Output = Bool

  public init() {}

  public func transform(_ input: Result<Input, any Error>) -> Result<Bool, any Error> {
    input.map { $0 == 1 }
  }

  public func reverseTransform(_ input: Result<Bool, any Error>) -> Result<Input, any Error> {
    input.map { $0 ? 1 : 0 }
  }
}

/// Projects a property via key path from an input value.
///
/// Useful to extract a sub-value before applying subsequent transforms.
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
