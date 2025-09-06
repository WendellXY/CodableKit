//
//  CodingTransformerRuntime.swift
//  CodableKit
//
//  Created by Assistant on 2025/9/6.
//

import Foundation

@inline(__always)
public func __ckDecodeTransformed<T, K>(
  transformer: T,
  from container: KeyedDecodingContainer<K>,
  forKey key: K,
  useDefaultOnFailure: Bool = false,
  defaultValue: T.Output? = nil
) throws -> T.Output where T: BidirectionalCodingTransformer, T.Input: Decodable {
  do {
    let input = try container.decode(T.Input.self, forKey: key)
    let result = transformer.transform(.success(input))
    switch result {
    case .success(let output):
      return output
    case .failure(let error):
      if useDefaultOnFailure, let defaultValue {
        return defaultValue
      }
      throw error
    }
  } catch {
    if useDefaultOnFailure, let defaultValue {
      return defaultValue
    }
    throw error
  }
}

@inline(__always)
public func __ckDecodeTransformedIfPresent<T, K>(
  transformer: T,
  from container: KeyedDecodingContainer<K>,
  forKey key: K,
  useDefaultOnFailure: Bool = false,
  defaultValue: T.Output? = nil
) throws -> T.Output? where T: BidirectionalCodingTransformer, T.Input: Decodable {
  do {
    guard let input = try container.decodeIfPresent(T.Input.self, forKey: key) else {
      return defaultValue
    }
    let result = transformer.transform(.success(input))
    switch result {
    case .success(let output):
      return output
    case .failure:
      if useDefaultOnFailure {
        return defaultValue
      }
      throw DecodingError.dataCorrupted(
        .init(codingPath: container.codingPath + [key], debugDescription: "Transformer failed")
      )
    }
  } catch {
    if useDefaultOnFailure {
      return defaultValue
    }
    throw error
  }
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
