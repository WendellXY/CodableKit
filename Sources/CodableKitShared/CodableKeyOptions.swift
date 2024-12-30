//
//  CodableKeyOptions.swift
//  CodableKit
//
//  Created by WendellXY on 2024/5/14
//  Copyright © 2024 WendellXY. All rights reserved.
//

import SwiftSyntax

public struct CodableKeyOptions: OptionSet, Sendable {
  public let rawValue: Int32

  public init(rawValue: Int32) {
    self.rawValue = rawValue
  }

  /// The default options for a `CodableKey`, which is equivalent to an empty set.
  public static let `default`: Self = []
  
  /// A convenience option combining ``transcodeRawString`` and ``useDefaultOnFailure`` for safe JSON string transcoding.
  ///
  /// This option provides a safer way to handle string-encoded JSON by automatically falling back to
  /// default values or `nil` when the JSON string is invalid or malformed. It's equivalent to
  /// `[.transcodeRawString, .useDefaultOnFailure]`.
  ///
  /// Example usage with invalid JSON handling:
  ///
  /// ```json
  /// {
  ///   "name": "Tom",
  ///   "validCar": "{\"brand\":\"XYZ\",\"year\":9999}",
  ///   "invalidCar": "corrupted json string",
  ///   "optionalCar": null
  /// }
  /// ```
  ///
  /// ```swift
  /// @Codable
  /// struct Person {
  ///   let name: String
  ///
  ///   // Successfully decodes valid JSON string
  ///   @CodableKey(options: .safeTranscodeRawString)
  ///   var validCar: Car = Car(brand: "Default", year: 2024)
  ///
  ///   // Uses default value for invalid JSON string
  ///   @CodableKey(options: .safeTranscodeRawString)
  ///   var invalidCar: Car = Car(brand: "Default", year: 2024)
  ///
  ///   // Becomes nil for invalid JSON string or null
  ///   @CodableKey(options: .safeTranscodeRawString)
  ///   var optionalCar: Car?
  /// }
  /// ```
  ///
  /// - Note: This is a convenience option. It's identical to using
  ///         `@CodableKey(options: [.transcodeRawString, .useDefaultOnFailure])`
  /// - Important: When using this option, ensure your properties either:
  ///   - Have an explicit default value, or
  ///   - Are optional (implicitly having `nil` as default)
  public static let safeTranscodeRawString: Self = [.transcodeRawString, .useDefaultOnFailure]

  /// The key will be ignored during encoding and decoding.
  ///
  /// This option is useful when you want to add a local or runtime-only property to the structure without creating
  /// another structure.
  ///
  /// -  Important: Using the `.ignored` option for an enum case may lead to runtime issues if you attempt to decode
  /// or encode the enum with that case using the `.ignored` option.
  public static let ignored = Self(rawValue: 1 << 0)

  /// The key will be explicitly set to `nil` (`null`) when encoding and decoding.
  /// By default, the key will be omitted if the value is `nil`.
  public static let explicitNil = Self(rawValue: 1 << 1)

  /// If the key has a custom CodableKey, a computed property will be generated to access the key; otherwise, this
  /// option is ignored.
  ///
  /// For example, if you have a custom key `myKey` and the original key `key`, a computed property `myKey` will be
  /// generated to access the original key `key`.
  ///
  /// ```swift
  /// @Codable
  /// struct MyStruct {
  ///   @CodableKey("key", options: .generateCustomKey)
  ///   var myKey: String
  /// }
  /// ```
  ///
  /// The generated code will be:
  /// ```swift
  /// struct MyStruct {
  ///   var myKey: String
  ///   var key: String {
  ///     myKey
  ///   }
  /// }
  /// ```
  public static let generateCustomKey = Self(rawValue: 1 << 2)

  /// Transcode the value between raw string and the target type.
  ///
  /// This is useful when the value needs to be converted from a string to another
  /// type during decoding and vice versa during encoding. The type of the property
  /// must conform to `Codable`, otherwise, a compile-time error will occur.
  ///
  /// For example, if you have a property `car` of type `Car` and you want to
  /// transcode it to a raw string, in the past, you would need to write a custom
  /// `init(from:)` and `encode(to:)` method. With this option, you can simply
  /// add the `transcodeRawString` option to the property and set the type of the
  /// property to the result type of the transcode operation.
  ///
  /// ```swift
  /// @Codable
  /// struct MyStruct {
  ///   @CodableKey(options: .transcodeRawString)
  ///   var car: Car
  /// }
  /// ```
  public static let transcodeRawString = Self(rawValue: 1 << 3)

  /// Use the default value (if set) when decode or encode fails.
  ///
  /// This option is only valid when the property has a default value or is optional (like `String?`).
  /// If the property is optional and the default value is set, the default value will be used when the
  /// property is empty or the decoding fails. If the property is optional and the default value is not set,
  /// the property will be set to `nil` when the decoding fails.
  ///
  /// This option is useful when you want to use a default value when the decoding fails, for example, when
  /// you have a enum property which decoded from a string, and you want to use a default value when the string
  /// is not a valid case.
  public static let useDefaultOnFailure = Self(rawValue: 1 << 4)
}

// MARK: It will be nice to use a macro to generate this code below.
extension CodableKeyOptions {
  package init(from expr: MemberAccessExprSyntax) {
    let variableName = expr.declName.baseName.text
    switch variableName {
    case "ignored":
      self = .ignored
    case "explicitNil":
      self = .explicitNil
    case "generateCustomKey":
      self = .generateCustomKey
    case "transcodeRawString":
      self = .transcodeRawString
    case "useDefaultOnFailure":
      self = .useDefaultOnFailure
    default:
      self = .default
    }
  }
}

extension CodableKeyOptions {
  /// Parse the options from 1a `LabelExprSyntax`. It support parse a single element like `.default`,
  /// or multiple elements like `[.ignored, .explicitNil]`
  package static func parse(from labeledExpr: LabeledExprSyntax) -> Self {
    if let memberAccessExpr = labeledExpr.expression.as(MemberAccessExprSyntax.self) {
      Self.init(from: memberAccessExpr)
    } else if let arrayExpr = labeledExpr.expression.as(ArrayExprSyntax.self) {
      arrayExpr.elements
        .compactMap { $0.expression.as(MemberAccessExprSyntax.self) }
        .map { Self.init(from: $0) }
        .reduce(.default) { $0.union($1) }
    } else {
      .default
    }
  }
}

extension LabeledExprSyntax {
  /// Parse the options from a `LabelExprSyntax`. It support parse a single element like .default,
  /// or multiple elements like [.ignored, .explicitNil].
  ///
  /// This is a convenience method to use for chaining.
  package func parseOptions() -> CodableKeyOptions {
    CodableKeyOptions.parse(from: self)
  }
}
