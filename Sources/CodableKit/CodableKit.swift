//
//  CodableKit.swift
//  CodableKit
//
//  Created by Wendell on 3/30/24.
//

// We should not import the plugin here, otherwise, a compile error will occur. Reference:
// https://forums.swift.org/t/xcode-15-beta-no-such-module-error-with-swiftpm-and-macro/65486/12
// import CodableKitMacros
@_exported import CodableKitShared

/// A macro that generates complete `Codable` conformance for structs and classes.
///
/// This macro automatically generates all the boilerplate code needed for `Codable` conformance,
/// including `CodingKeys` enum, `init(from:)` method, and `encode(to:)` method. It supports
/// default values, custom coding keys, nested key paths, and lifecycle hooks.
///
/// ## Overview
///
/// The `@Codable` macro is the most comprehensive option, generating both encoding and decoding
/// functionality. It's equivalent to using both `@Encodable` and `@Decodable` together.
///
/// ## Basic Usage
///
/// ```swift
/// @Codable
/// struct User {
///     let id: Int
///     let name: String
///     var age: Int = 25  // Default value
/// }
/// ```
///
/// This generates:
///
/// ```swift
/// extension User: Codable {
///     enum CodingKeys: String, CodingKey {
///         case id, name, age
///     }
///
///     init(from decoder: Decoder) throws {
///         let container = try decoder.container(keyedBy: CodingKeys.self)
///         id = try container.decode(Int.self, forKey: .id)
///         name = try container.decode(String.self, forKey: .name)
///         age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 25
///         try didDecode(from: decoder)
///     }
///
///     func encode(to encoder: Encoder) throws {
///         try willEncode(to: encoder)
///         var container = encoder.container(keyedBy: CodingKeys.self)
///         try container.encode(id, forKey: .id)
///         try container.encode(name, forKey: .name)
///         try container.encode(age, forKey: .age)
///         try didEncode(to: encoder)
///     }
/// }
/// ```
///
/// ## Advanced Features
///
/// ### Custom Coding Keys
///
/// ```swift
/// @Codable
/// struct User {
///     @CodableKey("user_id")
///     let id: Int
///     let name: String
/// }
/// ```
///
/// ### Nested Key Paths
///
/// ```swift
/// @Codable
/// struct User {
///     @CodableKey("data.user_id")
///     let id: Int
///     @CodableKey("profile.info.name")
///     let name: String
/// }
/// ```
///
/// ### Lifecycle Hooks
///
/// ```swift
/// @Codable
/// struct User {
///     var id: String = ""
///     let name: String
///     let age: Int
///
///     mutating func didDecode(from decoder: any Decoder) throws {
///         id = "\(name)-\(age)" // Post-processing
///     }
///
///     func willEncode(to encoder: any Encoder) throws {
///         // Pre-encoding preparation
///     }
///
///     func didEncode(to encoder: any Encoder) throws {
///         // Post-encoding cleanup
///     }
/// }
/// ```
///
/// ### Class Inheritance
///
/// ```swift
/// @Codable
/// class User: NSObject {
///     let id: Int
///     let name: String
/// }
/// ```
///
/// For classes that inherit from non-Codable superclasses, use the `.skipSuperCoding` option:
///
/// ```swift
/// @Codable(options: .skipSuperCoding)
/// class User: NSObject {
///     let id: Int
///     let name: String
/// }
/// ```
///
/// ## Generated Code Features
///
/// - **Automatic `CodingKeys` enum**: Generated with proper string mappings
/// - **Default value support**: Uses `decodeIfPresent` with fallback to default values
/// - **Lifecycle hooks**: Calls `didDecode`, `willEncode`, and `didEncode` methods if implemented
/// - **Superclass handling**: Automatically calls `super.init(from:)` and `super.encode(to:)` for Codable superclasses
/// - **Error handling**: Proper `throws` declarations and error propagation
///
/// ## Macro Options
///
/// - `options`: Controls macro behavior (see `CodableOptions`)
///
/// ## Protocol Conformance
///
/// The macro automatically adds conformance to:
/// - `Codable` (combines `Encodable` and `Decodable`)
/// - `CodableHooks` (for lifecycle hook support)
///
/// ## Compile-Time Safety
///
/// All code generation happens at compile time via Swift macros, ensuring:
/// - No runtime overhead
/// - Compile-time error checking
/// - Type safety
/// - IDE support with autocomplete
///
/// - Parameters:
///   - options: Configuration options for the macro behavior. Defaults to `.default`.
@attached(extension, conformances: Codable, CodableHooks, names: named(CodingKeys), named(init(from:)), arbitrary)
@attached(member, conformances: Codable, names: named(init(from:)), named(encode(to:)), arbitrary)
public macro Codable(
  options: CodableOptions = .default
) = #externalMacro(module: "CodableKitMacros", type: "CodableMacro")

/// A macro that generates `Decodable` conformance for structs and classes.
///
/// This macro generates only the decoding functionality (`init(from:)` method and `CodingKeys` enum).
/// Use this when you only need to decode data and don't need encoding capabilities.
///
/// ## Overview
///
/// The `@Decodable` macro is useful when you only need to parse JSON data into your types
/// but don't need to serialize them back to JSON. This can be more efficient than `@Codable`
/// when encoding is not required.
///
/// ## Basic Usage
///
/// ```swift
/// @Decodable
/// struct User {
///     let id: Int
///     let name: String
///     var age: Int = 25  // Default value
/// }
/// ```
///
/// This generates:
///
/// ```swift
/// extension User: Decodable {
///     enum CodingKeys: String, CodingKey {
///         case id, name, age
///     }
///
///     init(from decoder: Decoder) throws {
///         let container = try decoder.container(keyedBy: CodingKeys.self)
///         id = try container.decode(Int.self, forKey: .id)
///         name = try container.decode(String.self, forKey: .name)
///         age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 25
///         try didDecode(from: decoder)
///     }
/// }
/// ```
///
/// ## Advanced Features
///
/// ### Custom Coding Keys
///
/// ```swift
/// @Decodable
/// struct User {
///     @CodableKey("user_id")
///     let id: Int
///     let name: String
/// }
/// ```
///
/// ### Nested Key Paths
///
/// ```swift
/// @Decodable
/// struct User {
///     @CodableKey("data.user_id")
///     let id: Int
///     @CodableKey("profile.info.name")
///     let name: String
/// }
/// ```
///
/// ### Lifecycle Hooks
///
/// ```swift
/// @Decodable
/// struct User {
///     var id: String = ""
///     let name: String
///     let age: Int
///
///     mutating func didDecode(from decoder: any Decoder) throws {
///         id = "\(name)-\(age)" // Post-processing
///     }
/// }
/// ```
///
/// ### Class Inheritance
///
/// ```swift
/// @Decodable
/// class User: NSObject {
///     let id: Int
///     let name: String
/// }
/// ```
///
/// For classes that inherit from non-Codable superclasses:
///
/// ```swift
/// @Decodable(options: .skipSuperCoding)
/// class User: NSObject {
///     let id: Int
///     let name: String
/// }
/// ```
///
/// ## Generated Code Features
///
/// - **Automatic `CodingKeys` enum**: Generated with proper string mappings
/// - **Default value support**: Uses `decodeIfPresent` with fallback to default values
/// - **Lifecycle hooks**: Calls `didDecode` method if implemented
/// - **Superclass handling**: Automatically calls `super.init(from:)` for Codable superclasses
/// - **Error handling**: Proper `throws` declarations and error propagation
///
/// ## Macro Options
///
/// - `options`: Controls macro behavior (see `CodableOptions`)
///
/// ## Protocol Conformance
///
/// The macro automatically adds conformance to:
/// - `Decodable`
/// - `DecodingHooks` (for lifecycle hook support)
///
/// ## When to Use
///
/// Use `@Decodable` when:
/// - You only need to parse JSON data
/// - You don't need to serialize objects back to JSON
/// - You want to reduce generated code size
/// - You're working with read-only data models
///
/// - Parameters:
///   - options: Configuration options for the macro behavior. Defaults to `.default`.
@attached(extension, conformances: Decodable, DecodingHooks, names: named(CodingKeys), named(init(from:)), arbitrary)
@attached(member, conformances: Decodable, names: named(init(from:)), arbitrary)
public macro Decodable(
  options: CodableOptions = .default
) = #externalMacro(module: "CodableKitMacros", type: "CodableMacro")

/// A macro that generates `Encodable` conformance for structs and classes.
///
/// This macro generates only the encoding functionality (`encode(to:)` method and `CodingKeys` enum).
/// Use this when you only need to encode data and don't need decoding capabilities.
///
/// ## Overview
///
/// The `@Encodable` macro is useful when you only need to serialize your types to JSON
/// but don't need to parse JSON data into your types. This can be more efficient than `@Codable`
/// when decoding is not required.
///
/// ## Basic Usage
///
/// ```swift
/// @Encodable
/// struct User {
///     let id: Int
///     let name: String
///     var age: Int = 25
/// }
/// ```
///
/// This generates:
///
/// ```swift
/// extension User: Encodable {
///     enum CodingKeys: String, CodingKey {
///         case id, name, age
///     }
///
///     func encode(to encoder: Encoder) throws {
///         try willEncode(to: encoder)
///         var container = encoder.container(keyedBy: CodingKeys.self)
///         try container.encode(id, forKey: .id)
///         try container.encode(name, forKey: .name)
///         try container.encode(age, forKey: .age)
///         try didEncode(to: encoder)
///     }
/// }
/// ```
///
/// ## Advanced Features
///
/// ### Custom Coding Keys
///
/// ```swift
/// @Encodable
/// struct User {
///     @CodableKey("user_id")
///     let id: Int
///     let name: String
/// }
/// ```
///
/// ### Nested Key Paths
///
/// ```swift
/// @Encodable
/// struct User {
///     @CodableKey("data.user_id")
///     let id: Int
///     @CodableKey("profile.info.name")
///     let name: String
/// }
/// ```
///
/// ### Lifecycle Hooks
///
/// ```swift
/// @Encodable
/// struct User {
///     let id: Int
///     let name: String
///     let age: Int
///
///     func willEncode(to encoder: any Encoder) throws {
///         // Pre-encoding preparation
///     }
///
///     func didEncode(to encoder: any Encoder) throws {
///         // Post-encoding cleanup
///     }
/// }
/// ```
///
/// ### Class Inheritance
///
/// ```swift
/// @Encodable
/// class User: NSObject {
///     let id: Int
///     let name: String
/// }
/// ```
///
/// For classes that inherit from non-Codable superclasses:
///
/// ```swift
/// @Encodable(options: .skipSuperCoding)
/// class User: NSObject {
///     let id: Int
///     let name: String
/// }
/// ```
///
/// ## Generated Code Features
///
/// - **Automatic `CodingKeys` enum**: Generated with proper string mappings
/// - **Lifecycle hooks**: Calls `willEncode` and `didEncode` methods if implemented
/// - **Superclass handling**: Automatically calls `super.encode(to:)` for Codable superclasses
/// - **Error handling**: Proper `throws` declarations and error propagation
///
/// ## Macro Options
///
/// - `options`: Controls macro behavior (see `CodableOptions`)
///
/// ## Protocol Conformance
///
/// The macro automatically adds conformance to:
/// - `Encodable`
/// - `EncodingHooks` (for lifecycle hook support)
///
/// ## When to Use
///
/// Use `@Encodable` when:
/// - You only need to serialize objects to JSON
/// - You don't need to parse JSON data
/// - You want to reduce generated code size
/// - You're working with write-only data models
///
/// - Parameters:
///   - options: Configuration options for the macro behavior. Defaults to `.default`.
@attached(extension, conformances: Encodable, EncodingHooks, names: named(CodingKeys), arbitrary)
@attached(member, conformances: Encodable, names: named(encode(to:)), arbitrary)
public macro Encodable(
  options: CodableOptions = .default
) = #externalMacro(module: "CodableKitMacros", type: "CodableMacro")

/// A macro that customizes the coding key for a property.
///
/// This macro allows you to specify custom JSON keys for individual properties, including
/// support for nested key paths and various encoding/decoding options.
///
/// ## Overview
///
/// The `@CodableKey` macro provides fine-grained control over how individual properties
/// are encoded and decoded. It supports custom key names, nested key paths, and various
/// options for handling special cases like optional values and string transcoding.
///
/// ## Basic Usage
///
/// ### Simple Key Mapping
///
/// ```swift
/// @Codable
/// struct User {
///     @CodableKey("user_id")
///     let id: Int
///     let name: String
/// }
/// ```
///
/// This maps the `id` property to the JSON key `"user_id"`.
///
/// ### Nested Key Paths
///
/// ```swift
/// @Codable
/// struct User {
///     @CodableKey("data.user_id")
///     let id: Int
///     @CodableKey("profile.info.name")
///     let name: String
/// }
/// ```
///
/// This maps properties to nested JSON structures:
/// ```json
/// {
///   "data": { "user_id": 123 },
///   "profile": { "info": { "name": "Alice" } }
/// }
/// ```
///
/// ## Advanced Options
///
/// ### Ignoring Properties
///
/// ```swift
/// @Codable
/// struct User {
///     let id: Int
///     let name: String
///     @CodableKey(options: .ignored)
///     var cacheToken: String = ""
/// }
/// ```
///
/// The `cacheToken` property will be excluded from encoding and decoding.
///
/// ### Explicit Nil Encoding
///
/// ```swift
/// @Codable
/// struct User {
///     let id: Int
///     let name: String
///     @CodableKey(options: .explicitNil)
///     var description: String?
/// }
/// ```
///
/// The `description` property will be encoded as `null` when `nil`, instead of being omitted.
///
/// ### String Transcoding
///
/// ```swift
/// @Codable
/// struct User {
///     let id: Int
///     let name: String
///     @CodableKey(options: .transcodeRawString)
///     var profile: Profile
/// }
/// ```
///
/// The `profile` property will be encoded/decoded as a JSON string rather than an object.
///
/// ### Safe Transcoding with Fallback
///
/// ```swift
/// @Codable
/// struct User {
///     let id: Int
///     let name: String
///     @CodableKey(options: .safeTranscodeRawString)
///     var profile: Profile = Profile.default
/// }
/// ```
///
/// The `profile` property will be transcoded from JSON string, falling back to the default
/// value if the string is invalid or missing.
///
/// ### Use Default on Failure
///
/// ```swift
/// @Codable
/// struct User {
///     let id: Int
///     let name: String
///     @CodableKey(options: .useDefaultOnFailure)
///     var status: Status = .unknown
/// }
/// ```
///
/// If decoding fails for the `status` property, it will use the default value instead of throwing an error.
///
/// ### Generate Custom Key Property
///
/// ```swift
/// @Codable
/// struct User {
///     @CodableKey("user_id", options: .generateCustomKey)
///     let id: Int
///     let name: String
/// }
/// ```
///
/// This generates a computed property `user_id` that returns the value of `id`.
///
/// ## Available Options
///
/// - `.ignored`: Exclude the property from encoding/decoding
/// - `.explicitNil`: Encode `nil` values as `null` instead of omitting them
/// - `.transcodeRawString`: Encode/decode the property as a JSON string
/// - `.useDefaultOnFailure`: Use default value or `nil` if decoding fails
/// - `.safeTranscodeRawString`: Combine `.transcodeRawString` and `.useDefaultOnFailure`
/// - `.generateCustomKey`: Generate a computed property for the custom key
///
/// ## Compile-Time Safety
///
/// All key mappings and options are validated at compile time, ensuring:
/// - Valid JSON key names
/// - Proper nested key path syntax
/// - Compatible option combinations
/// - Type safety for transcoding operations
///
/// ## Performance
///
/// The macro generates optimized code with:
/// - Direct key access without string lookups
/// - Efficient nested container creation
/// - Minimal runtime overhead
/// - Compile-time constant folding where possible
///
/// - Parameters:
///   - key: The custom key or key path to use for encoding and decoding the property.
///     If not provided, the property name will be used.
///   - options: Options for customizing the behavior of the key. Defaults to `.default`.
@attached(peer, names: arbitrary)
public macro CodableKey(
  _ key: String? = nil,
  options: CodableKeyOptions = .default
) = #externalMacro(module: "CodableKitMacros", type: "CodableKeyMacro")

@attached(peer, names: arbitrary)
public macro CodableKey<T>(
  _ key: String? = nil,
  options: CodableKeyOptions = .default,
  transformer: T
) = #externalMacro(module: "CodableKitMacros", type: "CodableKeyMacro") where T: BidirectionalCodingTransformer
