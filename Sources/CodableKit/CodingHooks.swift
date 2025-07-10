//
//  CodingHooks.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/6/5.
//

/// Provides hooks for custom actions after decoding from a Decoder.
///
/// **Note:** This protocol is a helper for code completion and will be removed after compilation
/// if you do not provide any hooks. You can implement these methods in different forms:
/// - `func didDecode(from decoder: any Decoder) throws` (for classes)
/// - `mutating func didDecode(from decoder: any Decoder) throws` (for structs)
public protocol DecodingHooks {
  /// Called immediately after all properties are decoded.
  ///
  /// - Parameter decoder: The decoder instance used for decoding.
  /// - Throws: Any error thrown from custom logic.
  @inline(__always)
  func didDecode(from decoder: any Decoder) throws
}

/// Provides hooks for custom actions before and after encoding to an Encoder.
///
/// **Note:** This protocol is a helper for code completion and will be removed after compilation
/// if you do not provide any hooks. You can implement these methods in different forms:
/// - `func willEncode(to encoder: any Encoder) throws` (for classes)
/// - `mutating func willEncode(to encoder: any Encoder) throws` (for structs)
/// - `func didEncode(to encoder: any Encoder) throws` (for classes)
/// - `mutating func didEncode(to encoder: any Encoder) throws` (for structs)
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
///
/// **Note:** This protocol is a helper for code completion and will be removed after compilation
/// if you do not provide any hooks.
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
