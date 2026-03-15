# AGENTS.md

This document is for AI agents and contributors working on `CodableKit`. It explains the project structure, how to build and test locally, coding standards, and common workflows. Keep it concise and high-signal.

## Philosophy

Agents must reason from first principles. Do not rely on conventions, copied patterns, or assumptions without verification. Every task should begin by identifying the fundamental facts, constraints, and invariants of the system (e.g., API contracts, type rules, data models, performance limits). Decompose problems until they reach irreducible components, then derive solutions logically from those facts. Prefer the simplest design that satisfies all constraints, and explicitly verify assumptions using available evidence (code, documentation, tests, or tools). Avoid guesswork, pattern imitation, or speculative implementations. Solutions should be the result of facts → constraints → reasoning → implementation.

## Overview

CodableKit is a Swift macro package that generates Codable/Encodable/Decodable conformances with powerful customization:

- Default values and graceful decoding fallbacks
- Custom/nested coding keys, property-level options
- String ↔ Struct transcoding
- Lossy collection decoding and transformer pipelines
- Explicit lifecycle hooks via `@CodableHook`
- Macro-based, compile-time codegen; no runtime cost

## Repository Map

- `Package.swift`: SwiftPM manifest; targets and dependencies.
- `Sources/`
  - `CodableKitCore/`: Canonical shared option definitions used by both runtime and macro targets (e.g., `CodableKeyOptions`, `CodableOptions`).
  - `CodableKitMacros/`: SwiftSyntax-based macro implementations and compiler plugin entry points.
    - Key files: `CodableMacro.swift`, `CodableKeyMacro.swift`, `CodeGenCore(+GenDecode/+GenEncode).swift`, `CodingHookMacro.swift`, `Diagnostic.swift`, `Plugin.swift`.
  - `CodableKit/`: Public runtime facade, hook APIs, transformers, lossy wrappers, and compatibility shims that re-export canonical core types.
- `Tests/`
  - `CodableKitTests/`, `DecodableKitTests/`, `EncodableKitTests/`: Macro expansion tests and behavior coverage (structs, classes, enums, diagnostics, inheritance, hooks, lossy coding).
  - `TransformerTests/`: Runtime transformer behavior and composition coverage.
- `Docs`
  - `README.md`: User-facing feature guide and installation/version guidance.
  - `MIGRATION.md`: Breaking changes and upgrade notes between major versions.
  - `ROADMAP.md`: Planned work and longer-term direction.

## Build Matrix

- Swift tools: 6.0
- Platforms: macOS 10.15+, iOS 13+, tvOS 13+, watchOS 6+, Mac Catalyst 13+, visionOS 1+
- Dependencies: `swift-syntax` 600.x (currently `600.0.0 ..< 603.0.0`)

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
.package(url: "https://github.com/WendellXY/CodableKit.git", from: "2.0.0")
```

Import and apply macros:

```swift
import CodableKit

@Codable
struct User { /* ... */ }
```

For Swift 5 users or projects constrained to `swift-syntax 510.x`, use `from: "0.4.0"` (legacy line). For v1 hook behavior, consult `MIGRATION.md` before backporting examples.

## Common Tasks

- Update macro behavior: modify `Sources/CodableKitMacros/CodeGenCore*.swift` and related macro files; ensure diagnostics remain helpful.
- Add property option: extend `Sources/CodableKitCore/CodableKeyOptions.swift` and update macro/runtime handling accordingly.
- Add macro-level option: edit `Sources/CodableKitCore/CodableOptions.swift` and relevant generation branches.
- Update lifecycle hook behavior: check `Sources/CodableKit/CodableHook.swift`, `Sources/CodableKit/CodingHooks.swift`, `Sources/CodableKitMacros/CodingHookMacro.swift`, and hook diagnostics in `CodeGenCore.swift`.
- Update transformers: review `Sources/CodableKit/Transformers/` and `Tests/TransformerTests/` in addition to macro expansion coverage.
- Adjust plugin registration: see `Sources/CodableKitMacros/Plugin.swift`.

## Coding Standards

- Prefer explicit, readable names; avoid abbreviations.
- Keep code generation paths clear with early exits and guard clauses.
- Use minimal but meaningful comments explaining intent and invariants; avoid trivial commentary.
- Match existing formatting; avoid reformatting unrelated code.
- Add tests alongside feature changes (struct/class/enum/diagnostics coverage where applicable).

## Testing Guidance

- Run `swift test` locally; tests cover macro expansion for classes (incl. inheritance), structs, enums, diagnostics, hooks, lossy coding, and transformers.
- When adding new features, include examples in the appropriate test module (Encodable/Decodable/Codable/Transformer) to validate expansion and behavior.
- For inheritance where superclass is not Codable, use `.skipSuperCoding` in tests to avoid calling missing super methods.
- If behavior changes are user-visible, update `README.md`; if behavior is breaking or migration-sensitive, update `MIGRATION.md` too.

## Troubleshooting

- Build fails with SwiftSyntax version errors: ensure toolchain matches `swift-syntax` 600.x and Swift tools 6.0.
- Macro not expanding / plugin issues: clean build folder, ensure Xcode uses the correct toolchain, and re-run `swift build -v`.
- Decoding errors in tests: verify default values and `.useDefaultOnFailure` or `.safeTranscodeRawString` semantics; check key paths.
- Hook methods not firing: in v2, methods must be annotated with `@CodableHook(...)`; conventional names alone are diagnosed and not invoked.

## Contribution Workflow

1) Create a feature branch
2) Implement changes with tests
3) Run `swift build` and `swift test`
4) Update `README.md` if user-facing behavior changes; update `MIGRATION.md` for breaking behavior changes
5) Open a PR with a concise description and rationale

## Release Notes

- Keep `README.md` Installation section aligned with the latest published version.
- Update badges and CI as needed for new Swift versions.

## Security

No known sensitive data or credentials. Report vulnerabilities via GitHub issues.

## Maintainers

- Primary: Wendell (repo owner)
- Contributions welcome via PRs
