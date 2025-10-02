//
//  CodableKeyOptions.swift
//  CodableKit
//
//  Created by WendellXY on 2024/5/14
//  Copyright © 2024 WendellXY. All rights reserved.
//

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
  /// This option enables automatic conversion between a JSON string representation and a
  /// strongly-typed model during encoding and decoding. The property type must conform to
  /// the appropriate coding protocol based on usage:
  /// - For decoding: must conform to `Decodable`
  /// - For encoding: must conform to `Encodable`
  /// - For both operations: must conform to `Codable` (which combines both protocols)
  ///
  /// This is particularly useful when dealing with APIs that encode nested objects as
  /// string-encoded JSON, eliminating the need for custom encoding/decoding logic.
  ///
  /// For example, given this JSON response where `car` is a string-encoded JSON object:
  ///
  /// ```json
  /// {
  ///   "name": "Tom",
  ///   "car": "{\"brand\":\"XYZ\",\"year\":9999}"
  /// }
  /// ```
  ///
  /// You can decode it directly into typed models:
  ///
  /// ```swift
  /// @Codable
  /// struct Car {
  ///   let brand: String
  ///   let year: Int
  /// }
  ///
  /// @Codable
  /// struct Person {
  ///   let name: String
  ///   @CodableKey(options: .transcodeRawString)
  ///   var car: Car
  /// }
  /// ```
  ///
  /// When dealing with potentially invalid JSON strings, you can combine with other options.
  /// For example:
  ///
  /// ```json
  /// {
  ///   "name": "Tom",
  ///   "car": "invalid json string"
  /// }
  /// ```
  ///
  /// ```swift
  /// @Codable
  /// struct SafePerson {
  ///   let name: String
  ///
  ///   // Will use the default car when JSON string is invalid
  ///   @CodableKey(options: [.transcodeRawString, .useDefaultOnFailure])
  ///   var car: Car = Car(brand: "Default", year: 2024)
  ///
  ///   // Will be nil when JSON string is invalid
  ///   @CodableKey(options: [.transcodeRawString, .useDefaultOnFailure])
  ///   var optionalCar: Car?
  /// }
  /// ```
  ///
  /// Without this option, you would need to:
  /// 1. First decode the car field as a String
  /// 2. Parse that string into JSON data
  /// 3. Decode the JSON data into the Car type
  /// 4. Implement the reverse process for encoding
  ///
  /// The `transcodeRawString` option handles all these steps automatically.
  ///
  /// - Note: The property type must conform to the appropriate coding protocol based on usage:
  ///         `Decodable` for decoding, `Encodable` for encoding, or `Codable` for both.
  ///         A compile-time error will occur if the type does not satisfy these requirements.
  /// - Important: The string value must contain valid JSON that matches the structure of
  ///             the target type. If the JSON is invalid or doesn't match the expected structure,
  ///             a decoding error will be thrown at runtime. See ``useDefaultOnFailure`` option
  ///             for handling invalid JSON strings gracefully.
  public static let transcodeRawString = Self(rawValue: 1 << 3)

  /// Use the default value or `nil` when decoding or encoding fails.
  ///
  /// This option provides fallback behavior when coding operations fail, with two scenarios:
  ///
  /// 1. For properties with explicit default values:
  ///    ```swift
  ///    @CodableKey(options: .useDefaultOnFailure)
  ///    var status: Status = .unknown
  ///    ```
  ///    The default value (`.unknown`) will be used when decoding fails.
  ///
  /// 2. For optional properties:
  ///    ```swift
  ///    @CodableKey(options: .useDefaultOnFailure)
  ///    var status: Status?
  ///    ```
  ///    The property will be set to `nil` when decoding fails.
  ///
  /// This is particularly useful for:
  /// - Enum properties where the raw value might not match any defined cases
  /// - Handling backward compatibility when adding new properties
  /// - Gracefully handling malformed or unexpected data
  ///
  /// Example handling an enum with invalid raw value:
  /// ```swift
  /// enum Status: String, Codable {
  ///     case active
  ///     case inactive
  ///     case unknown
  /// }
  ///
  /// struct User {
  ///     let id: Int
  ///     @CodableKey(options: .useDefaultOnFailure)
  ///     var status: Status = .unknown  // Will use .unknown if JSON contains invalid status
  /// }
  ///
  /// // JSON: {"id": 1, "status": "invalid_value"}
  /// // Decodes without error, status will be .unknown
  /// ```
  ///
  /// - Note: This option must be used with either:
  ///   - A property that has an explicit default value
  ///   - An optional property (which implicitly has `nil` as default)
  /// - Important: Without this option, decoding failures would throw an error and halt the
  ///             entire decoding process. With this option, failures are handled gracefully
  ///             by falling back to the default value or `nil`.
  public static let useDefaultOnFailure = Self(rawValue: 1 << 4)

  /// Decode the value in a lossy way for collections.
  ///
  /// - For arrays and sets: invalid elements are dropped.
  /// - For dictionaries: entries with invalid values (or keys that cannot be
  ///   converted from JSON string keys) are dropped.
  ///
  /// This option is useful when you want to tolerate partially-invalid data
  /// from APIs without failing the entire decode.
  public static let lossy = Self(rawValue: 1 << 5)
}
