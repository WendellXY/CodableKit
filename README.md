# CodableKit — Swift Codable Macros for Safer, Faster JSON

[![Swift Version](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWendellXY%2FCodableKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/WendellXY/CodableKit)
[![Platform](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWendellXY%2FCodableKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/WendellXY/CodableKit)
![CI](https://img.shields.io/github/actions/workflow/status/WendellXY/CodableKit/ci.yml)

CodableKit is a Swift macro package that generates high‑quality `Codable`, `Encodable`, and `Decodable` implementations. It eliminates boilerplate, hardens your JSON parsing, and keeps your code fast and predictable.

It brings first‑class support for default values, nested custom keys, raw string transcoding, lossy decoding for collections, property‑level options, and lifecycle hooks — all via compile‑time macros, with no runtime cost.

## Why CodableKit?

Modern apps consume diverse JSON. Real‑world payloads include nested key paths, string‑encoded objects, partially invalid arrays, and evolving schemas. Hand‑written `Codable` tends to be verbose and brittle. CodableKit:

- Generates clean, deterministic `Codable` code at compile time (Swift macros) — no reflection, no magic at runtime
- Adds resilient patterns like defaults, lossy arrays/sets, and safe string‑to‑struct transcoding
- Keeps intent in your models via expressive annotations like `@CodableKey("data.uid")` and per‑property options
- Improves DX with clear diagnostics and predictable expansions

## Features

- One‑line `Codable` synthesis with `@Codable`, `@Encodable`, `@Decodable`
- Default values as automatic decode fallbacks
- Custom coding keys and nested key paths (`@CodableKey("data.uid")`)
- Graceful decoding failures with `.useDefaultOnFailure`
- String ↔ Struct transcoding for string‑encoded JSON (`.transcodeRawString`, `.safeTranscodeRawString`)
- Lossy collection decoding for collection types (`.lossy`) — drop invalid elements/entries
- Explicit `nil` encoding for optionals (`.explicitNil`)
- Generated computed key properties (`.generateCustomKey`)
- Lifecycle hooks: `didDecode`, `willEncode`, `didEncode`
- Macro‑based, compile‑time only — zero runtime overhead

## Quick Start

```swift
import CodableKit

@Codable
struct Car {
  let brand: String
  let model: String
  var year: Int = 2024 // Uses 2024 if missing
}
```

## Installation

Add to your Package.swift dependencies:

```swift
.package(url: "https://github.com/WendellXY/CodableKit.git", from: "1.4.0")
```

Still on Swift 5 or `swift-syntax` 510? Use the 0.x line (feature‑rich, but no longer developed):

```swift
.package(url: "https://github.com/WendellXY/CodableKit.git", from: "0.4.0")
```

## Feature Matrix

| Feature                        | Macro Syntax Example                                | Description                                     |
| ------------------------------ | --------------------------------------------------- | ----------------------------------------------- |
| Default values                 | `var count: Int = 0`                                | Use a fallback when data is missing             |
| Custom coding key              | `@CodableKey("uid") let id: UUID`                   | Map property to custom JSON key                 |
| Nested coding key path         | `@CodableKey("data.uid") let id: Int`               | Map to deeply nested JSON keys                  |
| Ignore property                | `@CodableKey(options: .ignored) var temp: String`   | Exclude property from coding                    |
| String ↔ Struct transcoding    | `@CodableKey(options: .transcodeRawString)`         | Decode/encode via JSON string field             |
| Lossy collection decoding      | `@CodableKey(options: .lossy)`                      | Decode arrays/sets; drop invalid elements       |
| Use default on failure         | `@CodableKey(options: .useDefaultOnFailure)`        | Fallback to default/nil on decoding error       |
| Generate custom key property   | `@CodableKey("id", options: .generateCustomKey)`    | Adds computed property for custom key           |
| Explicit nil encoding          | `@CodableKey(options: .explicitNil)`                | Encode nil as `null`, not omitted               |
| Coding lifecycle hooks         | `func didDecode(from:)`, `func willEncode(to:)`     | Run logic during encoding/decoding              |

## Usage Guides and Examples

### Default Values (Resilient Decoding)

```swift
@Codable
struct User {
  let id: Int
  let name: String
  var age: Int = 24 // Uses 24 if missing
}
```

### Nested Coding Keys (Dot‑Path)

```swift
@Codable
struct User {
  @CodableKey("data.uid") let id: Int
  @CodableKey("profile.info.name") let name: String
}
```

Decodes/encodes JSON like:

```json
{
  "data": { "uid": 123 },
  "profile": { "info": { "name": "Alice" } }
}
```

### Transcoding JSON Strings

Some APIs encode nested objects as JSON strings:

```json
{ "car": "{\"brand\":\"Tesla\",\"year\":2024}" }
```

```swift
@Codable
struct Car: Codable { let brand: String; let year: Int }

@Codable
struct User {
  @CodableKey(options: .transcodeRawString)
  var car: Car
}
```

### Safe Transcoding with Fallback

```swift
@Codable
struct User {
  @CodableKey(options: .safeTranscodeRawString)
  var car: Car = Car(brand: "Default", year: 2024) // Fallback if invalid/missing
}
```

### Lossy Decoding for Arrays/Sets (Drop Invalid Elements)

```swift
@Codable
struct Feed {
  // Keeps only valid integers; malformed items are ignored
  @CodableKey(options: .lossy)
  var ids: [Int]

  // Optional Set; when key absent → nil
  @CodableKey(options: .lossy)
  var tags: Set<String>?
}
```

Combine lossy with transcoding (array payload is a JSON string):

```swift
@Codable
struct Payload {
  // Raw string → Data → decode LossyArray<Int> → use .elements
  @CodableKey(options: [.lossy, .transcodeRawString])
  var values: [Int]
}
```

Safe variant with default when string is missing/invalid:

```swift
@Codable
struct SafePayload {
  @CodableKey(options: [.lossy, .safeTranscodeRawString])
  var values: [Int] = [1, 2]
}
```

### Lossy Decoding for Dictionaries

Decode dictionaries while dropping invalid entries (or keys that can’t be converted from JSON string keys).

```swift
@Codable
struct MapModel {
  // Keeps only entries with valid Int values
  @CodableKey(options: .lossy)
  var counts: [String: Int]

  // Optional dictionary; when key missing → nil
  @CodableKey(options: .lossy)
  var scores: [Int: Double]?
}
```

Combine with transcoding when the dictionary is encoded as a JSON string:

```swift
@Codable
struct DictPayload {
  // Raw string → Data → decode LossyDictionary<K, V> → use .elements
  @CodableKey(options: [.lossy, .transcodeRawString])
  var metrics: [String: Double]
}

@Codable
struct SafeDictPayload {
  // Falls back to default when the raw string is invalid/missing
  @CodableKey(options: [.lossy, .safeTranscodeRawString])
  var metrics: [Int: Double] = [:]
}
```

Notes:
- Dictionary keys must be `LosslessStringConvertible` (e.g., `String`, `Int`) so they can be constructed from JSON object keys, which are strings.
- Lossy behavior is decode‑only. Encoding dictionaries proceeds normally.

### Enum Fallbacks (Graceful Decoding)

```swift
enum Status: String, Codable { case active, inactive, unknown }

@Codable
struct User {
  @CodableKey(options: .useDefaultOnFailure)
  var status: Status = .unknown
}
```

## Lifecycle Hooks

Run custom logic before or after encoding/decoding, e.g. validation or derived values.

```swift
@Codable
struct User {
  var id: String = ""
  var name: String
  var age: Int

  mutating func didDecode(from decoder: any Decoder) throws {
    id = "\(name)-\(age)" // recompute derived values
  }

  func willEncode(to encoder: any Encoder) throws { /* prep */ }
  func didEncode(to encoder: any Encoder) throws { /* cleanup */ }
}
```

## Options Reference

CodableKit exposes two option sets:

- `CodableKeyOptions`: per‑property controls via `@CodableKey`
- `CodableOptions`: macro‑level controls for `@Codable`, `@Decodable`, `@Encodable`

### CodableKeyOptions (Property‑Level)

| Option                    | Description                                                                   |
| ------------------------- | ----------------------------------------------------------------------------- |
| `.ignored`                | Exclude property from (en|de)coding                                           |
| `.explicitNil`            | Encode optional `nil` as `null` (not omitted)                                 |
| `.generateCustomKey`      | Generate a computed property for the custom key                               |
| `.transcodeRawString`     | Transcode value via JSON string (nested model as string field)                |
| `.useDefaultOnFailure`    | Use default or `nil` if (en|de)coding fails                                   |
| `.safeTranscodeRawString` | Combine `.transcodeRawString` and `.useDefaultOnFailure`                      |
| `.lossy`                  | Lossy decode collections; drop invalid elements                               |

### CodableOptions (Macro‑Level)

| Option             | Description                                                                                  |
| ------------------ | -------------------------------------------------------------------------------------------- |
| `.default`         | Standard behavior; will call super encode/decode when appropriate                            |
| `.skipSuperCoding` | Skip generating `super.init(from:)` and `super.encode(to:)` if superclass is not `Codable`   |

## Performance and Determinism

- Pure compile‑time code generation (Swift macros), no reflection or runtime penalties
- Deterministic, minimal expansions for stable diffs and predictable behavior
- Shared encoder/decoder reuse within generated functions to reduce churn



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
