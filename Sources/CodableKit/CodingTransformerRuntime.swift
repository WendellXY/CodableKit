//
//  CodingTransformerRuntime.swift
//  CodableKit
//
//  Created by Assistant on 2025/9/6.
//

@inline(__always)
public func __ckDecodeTransformed<T, K>(
  transformer: T,
  from container: KeyedDecodingContainer<K>,
  forKey key: K,
  useDefaultOnFailure: Bool,
  defaultValue: T.Output? = nil
) throws -> T.Output where T: BidirectionalCodingTransformer, T.Input: Decodable {
  try DecodeAtKey(container, for: key)
    .chained(transformer)
    .conditionally(condition: useDefaultOnFailure) {
      DefaultOnFailureTransformer(defaultValue: defaultValue)
    }
    .transform(.success(()))
    .get()
}

@inline(__always)
public func __ckDecodeTransformedIfPresent<T, K>(
  transformer: T,
  from container: KeyedDecodingContainer<K>,
  forKey key: K,
  useDefaultOnFailure: Bool,
  defaultValue: T.Output? = nil
) throws -> T.Output? where T: BidirectionalCodingTransformer, T.Input: Decodable {
  try DecodeAtKeyIfPresent(container, for: key)
    .wrapped()
    .chained(transformer)
    .conditionally(condition: useDefaultOnFailure) {
      DefaultOnFailureTransformer(defaultValue: defaultValue)
    }
    .optional()
    .transform(.success(()))
    .flatMapError { error -> Result<T.Output?, any Error> in
      if let error = error as? WrappedError, error == .valueNotFound {
        .success(defaultValue)
      } else {
        .failure(error)
      }
    }
    .get()
}

@inline(__always)
public func __ckEncodeTransformed<T, K>(
  transformer: T,
  value: T.Output,
  into container: inout KeyedEncodingContainer<K>,
  forKey key: K
) throws where T: BidirectionalCodingTransformer, T.Input: Encodable {
  let input = try transformer.reverseTransform(.success(value)).get()
  try container.encode(input, forKey: key)
}

@inline(__always)
public func __ckEncodeTransformedIfPresent<T, K>(
  transformer: T,
  value: T.Output?,
  into container: inout KeyedEncodingContainer<K>,
  forKey key: K,
  explicitNil: Bool
) throws where T: BidirectionalCodingTransformer, T.Input: Encodable {
  if let value {
    let input = try transformer.reverseTransform(.success(value)).get()
    try container.encode(input, forKey: key)
  } else if explicitNil {
    try container.encodeNil(forKey: key)
  }
}

// MARK: - Derived property support

/// Runtime helper for `@DerivedKey`: feeds an already-decoded sibling value through a
/// one-directional transformer pipeline and returns its output.
///
/// Unlike the key-based helpers above, the input is not read from a decoding container — it is
/// the value of a sibling property that has already been assigned earlier in `init(from:)`.
@inline(__always)
public func __ckDecodeDerived<T>(
  transformer: T,
  from input: T.Input
) throws -> T.Output where T: CodingTransformer {
  try transformer.transform(.success(input)).get()
}

// MARK: - One-way transformer support

@inline(__always)
public func __ckDecodeOneWayTransformed<T, K>(
  transformer: T,
  from container: KeyedDecodingContainer<K>,
  forKey key: K,
  useDefaultOnFailure: Bool,
  defaultValue: T.Output? = nil
) throws -> T.Output where T: CodingTransformer, T.Input: Decodable {
  try DecodeAtKey<K, T.Input>(container, for: key)
    .chained(transformer)
    .conditionally(condition: useDefaultOnFailure) {
      DefaultOnFailureTransformer(defaultValue: defaultValue)
    }
    .transform(.success(()))
    .get()
}

@inline(__always)
public func __ckDecodeOneWayTransformedIfPresent<T, K>(
  transformer: T,
  from container: KeyedDecodingContainer<K>,
  forKey key: K,
  useDefaultOnFailure: Bool,
  defaultValue: T.Output? = nil
) throws -> T.Output? where T: CodingTransformer, T.Input: Decodable {
  try DecodeAtKeyIfPresent<K, T.Input>(container, for: key)
    .wrapped()
    .chained(transformer)
    .conditionally(condition: useDefaultOnFailure) {
      DefaultOnFailureTransformer(defaultValue: defaultValue)
    }
    .optional()
    .transform(.success(()))
    .flatMapError { error -> Result<T.Output?, any Error> in
      if let error = error as? WrappedError, error == .valueNotFound {
        .success(defaultValue)
      } else {
        .failure(error)
      }
    }
    .get()
}

@inline(__always)
public func __ckEncodeOneWayTransformed<T, K>(
  transformer: T,
  value: T.Input,
  into container: inout KeyedEncodingContainer<K>,
  forKey key: K
) throws where T: CodingTransformer, T.Output: Encodable {
  let encoded = try transformer.transform(.success(value)).get()
  try container.encode(encoded, forKey: key)
}

@inline(__always)
public func __ckEncodeOneWayTransformedIfPresent<T, K>(
  transformer: T,
  value: T.Input?,
  into container: inout KeyedEncodingContainer<K>,
  forKey key: K,
  explicitNil: Bool
) throws where T: CodingTransformer, T.Output: Encodable {
  if let value {
    let encoded = try transformer.transform(.success(value)).get()
    try container.encode(encoded, forKey: key)
  } else if explicitNil {
    try container.encodeNil(forKey: key)
  }
}
