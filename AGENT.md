# AGENT.md

This document is for AI agents and contributors working on `CodableKit`. It explains the project structure, how to build and test locally, coding standards, and common workflows. Keep it concise and high-signal.

## Overview

CodableKit is a Swift macro package that generates Codable/Encodable/Decodable conformances with powerful customization:

- Default values and graceful decoding fallbacks
- Custom/nested coding keys, property-level options
- String ↔ Struct transcoding
- Lifecycle hooks (didDecode/willEncode/didEncode)
- Macro-based, compile-time codegen; no runtime cost

## Repository Map

- `Package.swift`: SwiftPM manifest; targets and dependencies.
- `Sources/`
  - `CodableKitShared/`: Shared types exposed to both runtime and macro targets (e.g., `CodableKeyOptions`, `CodableOptions`).
  - `CodableKitMacros/`: SwiftSyntax-based macro implementations and compiler plugin entry points.
    - Key files: `CodableMacro.swift`, `CodableKeyMacro.swift`, `CodeGenCore(+GenDecode/+GenEncode).swift`, `Diagnostic.swift`, `Plugin.swift`.
  - `CodableKit/`: Public runtime facade and helper protocols (e.g., `CodableHooks`, `EncodingHooks`, `DecodingHooks`).
- `Tests/`
  - `CodableKitTests/`, `DecodableKitTests/`, `EncodableKitTests/`: Macro expansion tests and behavior coverage (structs, classes, enums, diagnostics, inheritance).

## Build Matrix

- Swift tools: 6.0
- Platforms: macOS 10.15+, iOS 13+, tvOS 13+, watchOS 6+, Mac Catalyst 13+
- Dependencies: `swift-syntax` ≥ 600.0.0

## Getting Started (Local Dev)

1) Prerequisites

- Xcode 16+ or Swift toolchain compatible with Swift 6.0 and SwiftSyntax 600.0.0
- macOS host recommended (macro plugin requires Apple toolchains)

2) Clone and open

```bash
git clone https://github.com/WendellXY/CodableKit.git
cd CodableKit
```

3) Build

```bash
swift build -v
```

4) Test

```bash
swift test -v
```

5) Open in Xcode (optional)

```bash
xed .
```

## Using in Your Project

Add to your package dependencies:

```swift
.package(url: "https://github.com/WendellXY/CodableKit.git", from: "1.4.0")
```

Import and apply macros:

```swift
import CodableKit

@Codable
struct User { /* ... */ }
```

For Swift 5 users or projects constrained to `swift-syntax 510.x`, use `from: "0.4.0"` (legacy line).

## Common Tasks

- Update macro behavior: modify `Sources/CodableKitMacros/CodeGenCore*.swift` and related macro files; ensure diagnostics remain helpful.
- Add property option: extend `Sources/CodableKitShared/CodableKeyOptions.swift` and update codegen logic accordingly.
- Add macro-level option: edit `Sources/CodableKitShared/CodableOptions.swift` and relevant generation branches.
- Adjust plugin registration: see `Sources/CodableKitMacros/Plugin.swift`.

## Coding Standards

- Prefer explicit, readable names; avoid abbreviations.
- Keep code generation paths clear with early exits and guard clauses.
- Use minimal but meaningful comments explaining intent and invariants; avoid trivial commentary.
- Match existing formatting; avoid reformatting unrelated code.
- Add tests alongside feature changes (struct/class/enum/diagnostics coverage where applicable).

## Testing Guidance

- Run `swift test` locally; tests cover macro expansion for classes (incl. inheritance), structs, enums, and diagnostics.
- When adding new features, include examples in the appropriate test module (Encodable/Decodable/Codable) to validate expansion and behavior.
- For inheritance where superclass is not Codable, use `.skipSuperCoding` in tests to avoid calling missing super methods.

## Troubleshooting

- Build fails with SwiftSyntax version errors: ensure toolchain matches `swift-syntax` 600.x and Swift tools 6.0.
- Macro not expanding / plugin issues: clean build folder, ensure Xcode uses the correct toolchain, and re-run `swift build -v`.
- Decoding errors in tests: verify default values and `.useDefaultOnFailure` or `.safeTranscodeRawString` semantics; check key paths.

## Contribution Workflow

1) Create a feature branch
2) Implement changes with tests
3) Run `swift build` and `swift test`
4) Update `README.md` if user-facing behavior changes
5) Open a PR with a concise description and rationale

## Release Notes

- Keep `README.md` Installation section aligned with the latest published version.
- Update badges and CI as needed for new Swift versions.

## Security

No known sensitive data or credentials. Report vulnerabilities via GitHub issues.

## Maintainers

- Primary: Wendell (repo owner)
- Contributions welcome via PRs
