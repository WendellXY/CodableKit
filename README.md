<p align="center">
  <br>
  <br>
  <img src="./assets/codablekit-icon.svg" alt="CodableKit logo" height="140">
  <br>
  <br>
</p>
<p align="center">
  <a href="https://swiftpackageindex.com/WendellXY/CodableKit"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWendellXY%2FCodableKit%2Fbadge%3Ftype%3Dswift-versions" alt="swift versions"></a>
  <a href="https://swiftpackageindex.com/WendellXY/CodableKit"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWendellXY%2FCodableKit%2Fbadge%3Ftype%3Dplatforms" alt="platform support"></a>
  <a href="https://github.com/WendellXY/CodableKit/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/WendellXY/CodableKit/ci.yml?branch=main" alt="build status"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/github/license/WendellXY/CodableKit" alt="license"></a>
</p>

# CodableKit

> Compile-time Codable macros for resilient Swift models.

- One-line `@Codable`, `@Encodable`, and `@Decodable` synthesis
- Default-aware decoding, nested keys, and graceful fallbacks
- Raw-string transcoding, lossy collections, and transformer pipelines
- Explicit lifecycle hooks with deterministic generated code

CodableKit is a Swift macro package built for the JSON you actually receive: nested payloads, string-encoded objects, partially invalid arrays, and schemas that drift over time. It keeps configuration close to each property, surfaces mistakes with compile-time diagnostics, and avoids runtime reflection or hidden magic.

[Quick Start](#quick-start) · [Feature Highlights](#feature-highlights) · [Targets](#targets) · [Installation](#installation) · [Migration Guide](./MIGRATION.md) · [Roadmap](./ROADMAP.md)

## Quick Start

```swift
import CodableKit

@Codable
struct User {
  @CodableKey("data.uid")
  let id: Int

  var name: String
  var age: Int = 24

  @CodableHook(.didDecode)
  mutating func normalize() {
    name = name.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
```

That single model gets generated `CodingKeys`, `init(from:)`, and `encode(to:)` implementations with nested key support, default fallback behavior, and an explicit post-decode hook.

## Feature Highlights

| Capability | Example | What you get |
| --- | --- | --- |
| Generated conformance | `@Codable`, `@Encodable`, `@Decodable` | Compile-time synthesis with predictable output |
| Default values | `var retries: Int = 3` | Missing keys can fall back without hand-written decode code |
| Nested coding keys | `@CodableKey("profile.info.name")` | Deep key-path mapping without manual containers |
| Graceful failure | `@CodableKey(options: .useDefaultOnFailure)` | Recover from bad payloads by falling back to defaults or `nil` |
| Raw-string transcoding | `@CodableKey(options: .safeTranscodeRawString)` | Decode string-encoded JSON into strongly typed models |
| Lossy collections | `@CodableKey(options: .lossy)` | Drop invalid array, set, or dictionary entries during decode |
| Explicit hooks | `@CodableHook(.didDecode)` | Run validation, normalization, or derived-value logic at clear lifecycle stages |
| Transformer pipelines | `@CodableKey(transformer: MyTransformer())` | Compose reusable decode and encode transformations |

## Targets

| Target | Purpose |
| --- | --- |
| `CodableKit` | Public facade that exports macros, hooks, transformers, lossy wrappers, and compatibility shims |
| `CodableKitCore` | Canonical shared option definitions consumed by both runtime and macro targets |
| `CodableKitMacros` | SwiftSyntax-based code generation, diagnostics, and compiler plugin entry points |

## Installation

Add CodableKit to your Swift Package Manager dependencies:

```swift
.package(url: "https://github.com/WendellXY/CodableKit.git", from: "2.0.0")
```

Then import it where you declare your models:

```swift
import CodableKit
```

### Requirements

- Swift tools 6.0
- Xcode 16+ or a Swift 6.0-compatible Apple toolchain
- `swift-syntax` 600.x
- macOS 10.15+, iOS 13+, tvOS 13+, watchOS 6+, Mac Catalyst 13+, visionOS 1+

If you need the legacy Swift 5 line that targets `swift-syntax` 510.x, use `from: "0.4.0"` instead.

## Examples

### Nested keys and defaults

```swift
@Codable
struct Session {
  @CodableKey("meta.version")
  var version: Int = 1

  @CodableKey("user.profile.name")
  let name: String
}
```

### Lossy collections and raw-string payloads

```swift
@Codable
struct Feed {
  @CodableKey(options: [.lossy, .safeTranscodeRawString])
  var items: [Item] = []
}
```

### Dynamic JSON values

```swift
@Codable
struct Payload {
  var value: JSONValue
}

let payload = try JSONDecoder().decode(
  Payload.self,
  from: #"{"value":{"name":"Ada","flags":[true,null]}}"#.data(using: .utf8)!
)

let name = payload.value["name"]?.stringValue
let firstFlag = payload.value["flags"]?[0]?.boolValue
```

### Explicit lifecycle hooks

```swift
@Encodable
struct AuditEvent {
  var createdAt: Date

  @CodableHook(.willEncode)
  func validate() throws {
    // validate or normalize before encoding
  }
}
```

In v2, hooks are explicit. Conventional method names alone are not invoked anymore. See [MIGRATION.md](./MIGRATION.md) for the upgrade path.

## Development

```bash
swift build -v
swift test -v
```

Tests cover macro expansion, diagnostics, hooks, inheritance, lossy coding, nested keys, and transformer behavior.

## Docs

- [Migration Guide](./MIGRATION.md): breaking changes and upgrade notes for v2
- [Roadmap](./ROADMAP.md): current priorities and planned work
- [Swift Package Index](https://swiftpackageindex.com/WendellXY/CodableKit): compatibility, metadata, and package discovery
- [Tests](./Tests): real examples for structs, classes, enums, hooks, diagnostics, and transformers

## License

[MIT](./LICENSE)
