//
//  CodingHooks.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/6/5.
//

/// Provides hooks for custom actions after decoding from a Decoder.
public protocol DecodingHooks {
  /// Called immediately after all properties are decoded.
  ///
  /// - Parameter decoder: The decoder instance used for decoding.
  /// - Throws: Any error thrown from custom logic.
  @inline(__always)
  func didDecode(from decoder: any Decoder) throws
}

/// Provides hooks for custom actions before and after encoding to an Encoder.
public protocol EncodingHooks {
  /// Called immediately before any property is encoded.
  ///
  /// - Parameter encoder: The encoder instance used for encoding.
  /// - Throws: Any error thrown from custom logic.
  @inline(__always)
  func willEncode(to encoder: any Encoder) throws

  /// Called immediately after all properties are encoded.
  ///
  /// - Parameter encoder: The encoder instance used for encoding.
  /// - Throws: Any error thrown from custom logic.
  @inline(__always)
  func didEncode(to encoder: any Encoder) throws
}

/// Composite protocol that includes all encoding and decoding hooks.
public typealias CodableHooks = DecodingHooks & EncodingHooks

// MARK: - Default Implementations

extension DecodingHooks {
  @inline(__always)
  public func didDecode(from decoder: any Decoder) throws {
    // Default: do nothing
  }
}

extension EncodingHooks {
  @inline(__always)
  public func willEncode(to encoder: any Encoder) throws {
    // Default: do nothing
  }

  @inline(__always)
  public func didEncode(to encoder: any Encoder) throws {
    // Default: do nothing
  }
}
