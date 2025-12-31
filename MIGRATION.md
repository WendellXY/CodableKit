# Migration Guide

This guide highlights breaking changes and recommended migrations between major versions of CodableKit.

## Migrating to v2: Codable hooks are now explicit

In v1.x (e.g. `1.7.7`), CodableKit supported **implicit** lifecycle hooks by convention:

- `didDecode(from:)`
- `willEncode(to:)`
- `didEncode(to:)`

These were invoked by the macro even if the methods were defined in an `extension` (including in another file).

In v2, hooks are **explicit**:

- Only methods annotated with `@CodableHook(<stage>)` are invoked.
- Conventional method names are **not** invoked unless you annotate them.
- The macro will emit a **compile-time error** when it sees conventional hook methods without `@CodableHook`.

### What changed (summary)

- **Removed**: conventional-name hook fallback (`didDecode`, `willEncode`, `didEncode`, `willDecode`) as an implicit mechanism.
- **Added**: `@CodableHook` for explicitly marking hook methods.

### How to migrate

#### 1) `didDecode(from:)`

Before (v1.x):

```swift
@Codable
struct User {
  var name: String

  mutating func didDecode(from decoder: any Decoder) throws {
    name = name.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
```

After (v2):

```swift
@Codable
struct User {
  var name: String

  @CodableHook(.didDecode)
  mutating func didDecode(from decoder: any Decoder) throws {
    name = name.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
```

Parameterless variant is also supported:

```swift
@CodableHook(.didDecode)
mutating func didDecode() throws { /* ... */ }
```

#### 2) `willEncode(to:)` / `didEncode(to:)`

Before (v1.x):

```swift
@Encodable
struct User {
  var name: String

  func willEncode(to encoder: any Encoder) throws { /* ... */ }
  func didEncode(to encoder: any Encoder) throws { /* ... */ }
}
```

After (v2):

```swift
@Encodable
struct User {
  var name: String

  @CodableHook(.willEncode)
  func willEncode(to encoder: any Encoder) throws { /* ... */ }

  @CodableHook(.didEncode)
  func didEncode(to encoder: any Encoder) throws { /* ... */ }
}
```

Parameterless variants are also supported:

```swift
@CodableHook(.willEncode)
func willEncode() throws { /* ... */ }

@CodableHook(.didEncode)
func didEncode() throws { /* ... */ }
```

#### 3) Pre-decode hook (`willDecode`)

v2 adds explicit pre-decode hooks:

```swift
@Decodable
struct User {
  let id: Int

  @CodableHook(.willDecode)
  static func willDecode(from decoder: any Decoder) throws {
    // configure decoder.userInfo, validate configuration, etc.
  }
}
```

Notes:
- `willDecode` must be `static` or `class`.
- You can also declare a parameterless variant.

### Common gotchas

- **Hooks in extensions**: in v2, hook detection and invocation is based on annotated methods. Prefer putting `@CodableHook` methods in the type body to keep intent local and obvious.
- **Overloads**: if you have both `hook()` and `hook(from:)`, pick one form and annotate it to avoid ambiguity.


