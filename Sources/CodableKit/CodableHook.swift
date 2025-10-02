//
//  CodableHook.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/10/2.
//

/// Lifecycle stages at which `@CodableHook`-annotated methods are invoked.
///
/// Use these values with `@CodableHook(_:)` on methods to opt into
/// invocation during macro-generated `init(from:)` and `encode(to:)`.
///
/// Call order:
/// - Decoding: all `.willDecode` hooks → property decoding → all `.didDecode` hooks
/// - Encoding: all `.willEncode` hooks → property encoding → all `.didEncode` hooks
///
/// Multiple hooks per stage are supported and are called in declaration order.
public enum HookStage: String, Sendable {
  /// Runs before any property decoding occurs inside `init(from:)`.
  /// - Usage: annotate a static/class method with `@CodableHook(.willDecode)`.
  ///   The method should accept `from decoder: any Decoder` and can throw.
  /// - Important: Must be a `static` or `class` method; instance `willDecode` is not supported.
  case willDecode

  /// Runs immediately before property encoding in `encode(to:)`.
  /// - Usage: annotate an instance method with `@CodableHook(.willEncode)`.
  ///   The method should accept `to encoder: any Encoder` and can throw.
  /// - Note: Should be nonmutating.
  case willEncode

  /// Runs after property encoding completes in `encode(to:)`.
  /// - Usage: annotate an instance method with `@CodableHook(.didEncode)`.
  ///   The method should accept `to encoder: any Encoder` and can throw.
  /// - Note: Should be nonmutating.
  case didEncode

  /// Runs after all properties have been decoded in `init(from:)`.
  /// - Usage: annotate an instance method with `@CodableHook(.didDecode)`.
  ///   The method should accept `from decoder: any Decoder` and can throw.
  /// - Note: May be `mutating` for structs.
  case didDecode
}

/// Marks a method to be invoked by the container macro at a particular coding stage.
///
/// Usage:
/// - `@CodableHook(.willDecode)` on static methods taking `(from decoder: any Decoder)`
/// - `@CodableHook(.didDecode)` on methods taking `(from decoder: any Decoder)`
/// - `@CodableHook(.willEncode)` or `@CodableHook(.didEncode)` on methods taking `(to encoder: any Encoder)`
///
/// Note:
/// - Hooks should be `throws` and nonmutating for encode stages. For structs, `.didDecode` may be `mutating`.
@attached(peer)
public macro CodableHook(_ stage: HookStage) = #externalMacro(module: "CodableKitMacros", type: "CodingHookMacro")
