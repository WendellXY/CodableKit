# CodableKit

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
- Transformer pipelines via `@CodableKey(transformer:)` (advanced; one‑way and bidirectional), with composition
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
.package(url: "https://github.com/WendellXY/CodableKit.git", from: "1.7.6")
```

## Feature Matrix

| Feature                        | Macro Syntax Example                                | Description                                                  |
| ------------------------------ | --------------------------------------------------- | ------------------------------------------------------------ |
| Default values                 | `var count: Int = 0`                                | Use a fallback when data is missing                          |
| Custom coding key              | `@CodableKey("uid") let id: UUID`                   | Map property to custom JSON key                              |
| Nested coding key path         | `@CodableKey("data.uid") let id: Int`               | Map to deeply nested JSON keys                               |
| Ignore property                | `@CodableKey(options: .ignored) var temp: String`   | Exclude property from coding                                 |
| String ↔ Struct transcoding    | `@CodableKey(options: .transcodeRawString)`         | Decode/encode via JSON string field                          |
| Lossy collection decoding      | `@CodableKey(options: .lossy)`                      | Decode arrays/sets; drop invalid elements                    |
| Use default on failure         | `@CodableKey(options: .useDefaultOnFailure)`        | Fallback to default/nil on decoding error                    |
| Generate custom key property   | `@CodableKey("id", options: .generateCustomKey)`    | Adds computed property for custom key                        |
| Explicit nil encoding          | `@CodableKey(options: .explicitNil)`                | Encode nil as `null`, not omitted                            |
| Coding lifecycle hooks         | `static willDecode(from:)`, `func didDecode(from:)`, `func willEncode(to:)`, `func didEncode(to:)` | Run logic during encoding/decoding; annotate with `@CodableHook` for explicit control |
| Transformers (advanced)        | `@CodableKey(transformer: MyTransformer())`         | Apply custom/built‑in transforms, compose with bidirectional |

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

  // Runs before any properties are decoded (static-only)
  @CodableHook(.willDecode)
  static func pre(from decoder: any Decoder) throws { /* prepare decoder/userInfo */ }

  mutating func didDecode(from decoder: any Decoder) throws {
    id = "\(name)-\(age)" // recompute derived values
  }

  func willEncode(to encoder: any Encoder) throws { /* prep */ }
  func didEncode(to encoder: any Encoder) throws { /* cleanup */ }
}
```

### Annotated Hooks (Recommended)

- Use `@CodableHook(<stage>)` to explicitly mark lifecycle methods:
  - `.willDecode`: static/class method, signature `from decoder: any Decoder`, runs before property decoding.
  - `.didDecode`: instance method, signature `from decoder: any Decoder`, runs after decoding completes.
  - `.willEncode` / `.didEncode`: instance methods, signature `to encoder: any Encoder`, run before/after encoding.
- Multiple hooks per stage are supported and called in declaration order.
- You can pick any method names when annotated; the macro invokes the annotated methods.
- If no annotations are present, conventional names are still detected for compatibility.

### Why There’s No Instance `willDecode`

An instance `willDecode` is unsafe in Swift because `self` isn’t fully initialized before property decoding begins, so
calling an instance method there would violate initialization rules. Instead, CodableKit provides:

- `@CodableHook(.willDecode)` static/class hook that runs before decode.
- `didDecode(from:)` instance hook that runs after decode completes.
- `willEncode(to:)` / `didEncode(to:)` instance hooks around encoding.

Tips:
- Use property defaults for baseline state before decoding.
- Put normalization/derivations in `didDecode(from:)`.
- Preprocess or configure the decoder (e.g., `userInfo`) before calling `decode` when needed.

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

### Transformers (Advanced)

CodableKit lets you attach transformer pipelines to individual properties using `@CodableKey(transformer:)`. Transformers let you adapt wire formats to model types and back.

Note:
- Transformers can replicate or subsume many existing options (e.g., raw string transcoding, defaults on failure), and are intended for advanced use cases.
- The public API is stable, but we may add more expressive calling styles (e.g., dot‑chain helpers like `.transcode<Room>.chained(.default(…))`) over time to improve ergonomics.

There are two kinds:

- CodingTransformer<Input, Output>: one‑way (decode‑only or encode‑only depending on use)
- BidirectionalCodingTransformer<Input, Output>: two‑way (required for encode paths)

Built‑ins you can use immediately:

- `DefaultOnFailureTransformer<Value>`: converts failures into a provided default value
- `RawStringTransformer<Value>`: maps `String` ↔ `Value` using JSON encode/decode
- `RawStringDecodingTransformer<Value>` / `RawStringEncodingTransformer<Value>`: one‑way variants
- `IntegerToBooleanTransformer<Int>`: maps `0/1` ↔ `false/true`
- `IdentityTransformer<Value>`: pass‑through
- `KeyPathTransformer<T, U>`: project `U` from a `T` by key path when decoding

Compose pipelines with `.chained` and `.paired` helpers, and reverse a bidirectional transformer with `.reversed`.

#### Decode and Encode with a Bidirectional Transformer

```swift
struct IntFromString: BidirectionalCodingTransformer {
  func transform(_ input: Result<String, any Error>) -> Result<Int, any Error> { input.map { Int($0) ?? 0 } }
  func reverseTransform(_ input: Result<Int, any Error>) -> Result<String, any Error> { input.map(String.init) }
}

@Codable
struct Model {
  @CodableKey(transformer: IntFromString())
  var count: Int
}
```

This decodes a JSON string into an `Int` and encodes `Int` back to a JSON string.

#### Optional Properties and `explicitNil`

```swift
@Codable
struct Model {
  @CodableKey(transformer: IntFromString())
  var count: Int? // missing → nil; encodes omitted by default

  @CodableKey(options: .explicitNil, transformer: IntFromString())
  var exact: Int? // nil encodes as null
}
```

#### Use Default on Failure with a Transformer

```swift
@Codable
struct Model {
  @CodableKey(options: .useDefaultOnFailure, transformer: IntFromString())
  var count: Int = 42 // fallback when type mismatches or key is missing
}
```

#### Compose Transformers

```swift
struct Increment: BidirectionalCodingTransformer {
  func transform(_ x: Result<Int, any Error>) -> Result<Int, any Error> { x.map { $0 + 1 } }
  func reverseTransform(_ x: Result<Int, any Error>) -> Result<Int, any Error> { x.map { $0 - 1 } }
}

@Codable
struct Model {
  @CodableKey(transformer: IntFromString().chained(Increment()))
  var value: Int // "5" → 6 on decode; 6 → "5" on encode
}
```

#### Raw JSON as String

```swift
struct Room: Codable { let id: Int; let name: String }

@Codable
struct Model {
  @CodableKey(transformer: RawStringTransformer<Room>())
  var room: Room // JSON has field as a string containing JSON
}
```

#### One‑way Transformers

For decode‑only projections, you can use `CodingTransformer`. Example: extract a nested field with `KeyPathTransformer`.

```swift
struct Wrap: Codable { let inner: Int }

@Codable
struct Model {
  @CodableKey(transformer: KeyPathTransformer<Wrap, Int>(keyPath: \Wrap.inner))
  var count: Int
}
```

Note: In `@Decodable` containers, one‑way transformers are supported. In `@Codable` containers, encoding also uses the transformer; provide a `BidirectionalCodingTransformer` or explicitly pair one‑way transformers via `.paired(_:)`.

```swift
@Codable
struct Car: Codable { let brand: String; let year: Int }

@Codable
struct User {
  @CodableKey(options: .transcodeRawString)
  var car: Car
}
```

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
