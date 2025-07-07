# CodableKit ⚡️

[![Swift Version](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWendellXY%2FCodableKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/WendellXY/CodableKit)
[![Platform](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWendellXY%2FCodableKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/WendellXY/CodableKit)
![CI](https://img.shields.io/github/actions/workflow/status/WendellXY/CodableKit/ci.yml)

CodableKit is a Swift macro package designed to make Swift’s `Codable` conformance vastly simpler, safer, and more robust.  
It provides macros for generating `Codable`, `Encodable`, and `Decodable` implementations, adding first-class support for default values, custom coding keys, raw string transcoding, property-level customization, and lifecycle hooks.

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Feature Matrix](#feature-matrix)
- [Usage Examples](#usage-examples)
- [Lifecycle Hooks](#lifecycle-hooks)
- [Advanced Key and Macro Options](#advanced-key-and-macro-options)
- [Installation](#installation)
- [Limitations](#limitations)
- [Contributing](#contributing)

## Features

- **One-line `Codable` synthesis:**  
  Use `@Codable`, `@Encodable`, or `@Decodable` for fully automatic boilerplate generation.

- **Default values:**  
  Use default property values as automatic fallback during decoding.

- **Custom coding keys:**  
  Change the mapping from property names to coding keys, with full support for nested models.

- **Nested coding key paths:**  Use `@CodableKey("data.uid")` or deeper paths to map properties to nested keys in the JSON hierarchy (e.g., `{ "data": { "uid": 0 } }`).

- **Graceful decoding failures:**  
  Specify that a property should fallback to a default (or `nil`) instead of throwing on invalid/missing input.

- **String ↔ Struct transcoding:**  
  Automatically decode/encode nested models from/to raw string fields (common in many APIs).

- **Property ignoring:**  
  Mark properties to be ignored for coding, without splitting up your models.

- **Explicit nil encoding:**  
  Encode optionals as `null` instead of omitting them.

- **Custom key property generation:**  
  Generate computed properties for custom keys.

- **Lifecycle hooks:**  
  Add custom logic before/after encoding or decoding (`didDecode`, `willEncode`, `didEncode`).

- **Macro-based, no runtime cost:**  
  All customization is performed at compile-time via Swift macros.

## Quick Start

```swift
import CodableKit

@Codable
struct Car {
    let brand: String
    let model: String
    var year: Int = 2024  // Uses 2024 if missing from input
}
```

## Feature Matrix

| Feature                        | Macro Syntax Example                                | Description                                     |
| ------------------------------ | --------------------------------------------------- | ----------------------------------------------- |
| Default values                 | `var count: Int = 0`                                | Use a fallback when data is missing             |
| Custom coding key              | `@CodableKey("uid") let id: UUID`                   | Map property to custom JSON key                 |
| Nested coding key path         | `@CodableKey("data.uid") let id: Int`                 | Support mapping to deeply nested JSON keys        |
| Ignore property                | `@CodableKey(options: .ignored) var temp: String`   | Exclude property from coding                    |
| String ↔ Struct transcoding    | `@CodableKey(options: .transcodeRawString)`         | Decode/encode via JSON string field             |
| Use default on failure         | `@CodableKey(options: .useDefaultOnFailure)`        | Fallback to default or nil on decoding error    |
| Generate custom key property   | `@CodableKey("id", options: .generateCustomKey)`    | Adds computed property for custom key           |
| Explicit nil encoding          | `@CodableKey(options: .explicitNil)`                | Encode nil as null, not omitted                 |
| Safe string-to-struct fallback | `@CodableKey(options: .safeTranscodeRawString)`     | Gracefully handle invalid JSON string, fallback |
| Coding lifecycle hooks         | `func didDecode(from:)`, `func willEncode(to:)`     | Run logic during encoding/decoding              |

## Usage Examples

### Basic: Default Values

To use the Codable macro, simply add the `@Codable` attribute to your struct declaration.

```swift
@Codable
struct User {
    let id: Int
    let name: String
    var age: Int = 24   // Uses 24 if missing
}
```

By setting the default value of the `year` property to 2024, the value will be 2024 when the raw data does not include that property.

### Custom Key & Ignoring a Property

```swift
@Codable
struct User {
    @CodableKey("uid")
    let id: UUID

    @CodableKey(options: .ignored)
    let cacheToken: String = ""
}
```

### Nested Coding Keys

You can map a property to a deeply nested key in your JSON using dot notation with `@CodableKey`. For example, this struct:

```swift
@Codable
struct User {
    @CodableKey("data.uid") let id: Int
    @CodableKey("profile.info.name") let name: String
}
```

...will encode/decode JSON like:

```json
{
  "data": { "uid": 123 },
  "profile": { "info": { "name": "Alice" } }
}
```

### Transcoding JSON Strings

Suppose the API encodes a model as a string:

```json
{
  "car": "{\"brand\":\"Tesla\",\"year\":2024}"
}
```

You can decode directly to a struct:

```swift
@Codable
struct Car: Codable {
    let brand: String
    let year: Int
}

@Codable
struct User {
    @CodableKey(options: .transcodeRawString)
    var car: Car
}
```

### Safe String-to-Struct Fallback

```swift
@Codable
struct User {
    @CodableKey(options: .safeTranscodeRawString)
    var car: Car = Car(brand: "Default", year: 2024)
    // Falls back to default car if string is invalid
}
```

### Enum Fallbacks (Graceful Decoding)

```swift
enum Status: String, Codable {
    case active, inactive, unknown
}

@Codable
struct User {
    @CodableKey(options: .useDefaultOnFailure)
    var status: Status = .unknown
}
```

## Lifecycle Hooks

Run custom logic before or after (en|de)coding, e.g. postprocessing or validation:

```swift
@Codable
struct User {
    var id: String = ""
    var name: String
    var age: Int

    mutating func didDecode(from decoder: any Decoder) throws {
        id = "\(name)-\(age)" // e.g., recompute derived values
    }

    func willEncode(to encoder: any Encoder) throws {
        // Custom preparation before encoding
    }

    func didEncode(to encoder: any Encoder) throws {
        // Cleanup or logging after encoding
    }
}
```

## Advanced Key and Macro Options

CodableKit exposes powerful customization points via two sets of options:

- `CodableKeyOptions`: property-level options for the `@CodableKey` macro.
- `CodableOptions`: macro-level options for the `@Codable`, `@Decodable`, and `@Encodable` macros.

### CodableKeyOptions (Property-Level)

Use with `@CodableKey` to control how a specific property is encoded/decoded.

| Option                        | Description                                                         |
| ----------------------------- | ------------------------------------------------------------------- |
| `.ignored`                    | Exclude this property from (en|de)coding                            |
| `.explicitNil`                | Encode nil optionals as `null` (not omitted)                        |
| `.generateCustomKey`          | Generate a computed property for the custom key                     |
| `.transcodeRawString`         | Transcode value via JSON string (for nested model as string fields) |
| `.useDefaultOnFailure`        | Use default or nil if (en|de)coding fails                           |
| `.safeTranscodeRawString`     | Combine `.transcodeRawString` and `.useDefaultOnFailure`            |

**Example:**

```swift
struct User {
    @CodableKey("uuid", options: .generateCustomKey)
    let id: String

    @CodableKey(options: [.ignored, .explicitNil])
    var debugToken: String?
}
```

### CodableOptions (Macro-Level)

Pass as options: to the `@Codable`, `@Decodable`, or `@Encodable` macro to control expansion at the type level.

| Option             | Description                                                                                  |
| ------------------ | -------------------------------------------------------------------------------------------- |
| `.default`         | Standard behavior: will generate super encode/decode calls if the type inherits from a class |
| `.skipSuperCoding` | Skip generating super.init(from:) and super.encode(to:).Use if superclass is not Codable     |

#### When to use .skipSuperCoding

If your model inherits from a class that **does not** conform to `Codable`, you **must** use `.skipSuperCoding` to prevent compile-time errors.

**Example:**

```swift
@Codable(options: .skipSuperCoding)
class User: NSObject {
    var id: Int
    var name: String
}
```

This generates:

```swift
required init(from decoder: Decoder) throws {
    super.init() // No call to super.init(from:)
    // ...decode properties
}

func encode(to encoder: Encoder) throws {
    // ...encode properties (no call to super.encode)
}
```

If you omit `.skipSuperCoding` on such a class, you’ll get a compiler error because the macro will attempt to call non-existent superclass coding methods.

**See also:**
- [`CodableKeyOptions`](Sources/CodableKitShared/CodableKeyOptions.swift) for property options.
- [`CodableOptions`](Sources/CodableKitShared/CodableOptions.swift) for macro-level options.
- [Usage Examples](#usage-examples) for practical code samples.

## Installation

```swift
.package(url: "https://github.com/WendellXY/CodableKit.git", from: "1.4.0"),
```

For those who still use Swift 5 or have dependencies that require Swift 5 or swift-syntax 510.0.0,
you can use the previous 0.x version of CodableKit, which is compatible with Swift 5 and should
cover most of features in the latest version. Be aware that the 0.x version will not be developed
anymore, and it is recommended to upgrade to the latest version.

```swift
.package(url: "https://github.com/WendellXY/CodableKit.git", from: "0.4.0"),
```

## Limitations

When applying this macro to a base class, in the class definition header, you should not add any inheritance to the
class. Otherwise, this class will be considered as a class with a superclass, because the macro cannot identify whether
the inheritance is a class or a protocol during macro expansion.

```swift
// Codable will consider the BaseUser as a base class since it does not have any inheritance
@Codable
class BaseUser { }

// Codable will consider the HashableUser as a subclass even if the inheritance just contains a protocol
@Codable
class HashableUser: Hashable { }

// So you have to write the HashableUser like:
@Codable
class HashableUser { }
extension HashableUser: Hashable { }
```

**Note:** For highly unusual or invalid Swift identifiers in key paths (e.g., reserved words), the generated coding key enum/case names will be sanitized to ensure valid Swift code.

## Contributing

Please feel free to contribute to `CodableKit`! Any input and suggestions are always appreciated.
