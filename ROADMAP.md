# CodableKit Roadmap

This roadmap outlines the major priorities and phased delivery plan for CodableKit. It focuses on correctness, stability, ergonomics, and extensibility while keeping macro output predictable and fast.

## Guiding Principles
- Prefer compile-time guarantees and zero/low runtime overhead
- Predictable code generation; minimal surprises for users
- Opt-in features via options; maintain backwards compatibility by default
- Clear diagnostics with actionable fix-its
- Strong test coverage (snapshots + behavior) and CI signal

## Milestones
- 1.5.x: Phase 1 — correctness & stability (PRs #10, #11)
- 1.6.x: Phase 2 — ergonomics & resilience
- 1.7.x: Coding Transformer — functional, composable coding pipeline (MVP)
- 1.8.x: Transformer Ecosystem — official set, docs, performance
- 2.0.0: Breaking changes window (only if truly necessary)

## Phase 1 — Correctness and Stability (Target: 1.5.x)
- Status: ([PR #10](https://github.com/WendellXY/CodableKit/pull/10), [PR #11](https://github.com/WendellXY/CodableKit/pull/11))
- [x] Optional raw-string transcode: omit key when value is nil unless `.explicitNil`
  - Acceptance:
    - Optional property with `.transcodeRawString` encodes no key when `nil`
    - With `.explicitNil`, encodes null semantics appropriately
    - Decode path honors defaults/optionals as configured
- [x] Reuse a single `JSONEncoder`/`JSONDecoder` per encode/decode function
  - Acceptance:
    - Generated code creates one encoder/decoder per function
    - Tests assert behavior unchanged; micro-bench shows reduced churn
- [x] Deterministic codegen order for nested key-paths and containers
  - Acceptance:
    - Snapshot tests reveal stable order across runs/platforms
- [ ] Diagnostics improvements (clearer messages, targeted fix-its) — ([PR #11](https://github.com/WendellXY/CodableKit/pull/11))
  - [x] Warn when `.useDefaultOnFailure` on non-optional without default
  - [x] Warn when `.explicitNil` on non-optional property
  - [x] Suggest `.skipSuperCoding` for classes with inheritance when superclass may be non-Codable
  - [ ] Add fix-it for missing type annotation
  - [ ] Improve multi-binding with custom key error messaging
  - [ ] Enum options validation warnings
  - Acceptance:
    - Missing type annotation reports actionable error and fix-it
    - Multi-binding with custom key reports clear error
    - Enum options validation warns appropriately
- Tests
  - [x] Optional transcode: encode/decode (with/without `.explicitNil`)
  - [x] Deterministic nested ordering snapshots

## Phase 2 — Ergonomics and Resilience (Target: 1.6.x)
- [x] Lossy decoding for arrays and sets (`.lossy`)
  - Acceptance:
    - `LossyArray<T>` semantics: invalid items dropped, valid items decoded
    - Default/optional behaviors still respected (including `.useDefaultOnFailure`)
    - Works with `Set<T>` (deduplication preserved)
    - Composes with `.transcodeRawString` and `.safeTranscodeRawString` (decode lossy from transcoded payload)
- [x] Lossy decoding for dictionaries (`.lossy`)
  - Acceptance:
    - Gracefully drop invalid entries and decode valid key/value pairs
- Size-limit guard for raw-string transcode decoding
  - Acceptance:
    - Reasonable default limit; configurable via option or macro-level configuration in a later patch
    - Exceeding limit produces decode error or default/`nil` when `.useDefaultOnFailure` present
- Tests
  - Mixed-validity collections round-trips (Array and Set)
  - Combined `.lossy` + `.transcodeRawString` and `.safeTranscodeRawString`
  - Guard behavior, with and without defaults and `.useDefaultOnFailure`

## Coding Transformer — Functional, Composable Coding Pipeline (Target: 1.7.x)
- Problem statement
  - Per-field customization (e.g., dates, numbers-from-strings, lossy mapping) often requires options or manual code.
  - Some needs (like per-type date strategies) push users towards hacks and can impact performance.
  - Goal: Provide a first-class, composable pipeline for coding operations inspired by functional programming.
- Core concept
  - `CodingTransformer<Input, Output>` transforms `Result<Input, CodingError>` → `Result<Output, CodingError>`.
  - Chainable and reusable (e.g., `.map`, `.flatMap`, `.compose(_)`).
  - Sendable-friendly; encourages stateless transformers or shared, cached resources (e.g., formatters).
  - Symmetric support: decoding transformers, encoding transformers, or bi-directional transformers when possible.
- Integration
  - Property-level: `@CodableKey(transformers: [...])` to apply a pipeline during decode/encode.
  - Type-level defaults: optional default pipeline applied across the type, overridable per-field.
  - Backwards compatibility: existing options like `.transcodeRawString`, `.useDefaultOnFailure`, `.lossy` map to built-in transformers.
  - Diagnostics: compile-time checks for transformer type compatibility and fix-its for common mistakes.
- Initial official transformers (MVP)
  - `date(.iso8601 | .secondsSince1970 | .millisecondsSince1970 | .formatted(DateFormatter))`
  - `numberFromString<T: LosslessStringConvertible>()`
  - `boolFromInt(0/1)` and `boolFromString("true"/"false")`
  - `rawStringTranscode<T: Decodable &/or Encodable>()` with `safeRawStringTranscode` variant
  - `defaultOnFailure(_:)` and `nilOnFailure`
  - `lossyArray`, `lossySet`, `lossyDictionary`
  - Utility transforms: `trim`, `nonEmpty`, `clamp`, `coalesce(_:)`
- API sketch
  - Protocol:
    ```swift
    public protocol CodingTransformer {
      associatedtype Input
      associatedtype Output
      func transform(_ input: Result<Input, CodingError>) -> Result<Output, CodingError>
    }
    ```
  - Composition:
    ```swift
    extension CodingTransformer {
      func compose<T: CodingTransformer>(_ next: T) -> some CodingTransformer where T.Input == Output { /* ... */ }
    }
    ```
  - Usage with macro:
    ```swift
    @Codable
    struct Event {
      @CodableKey("date", transformers: [.date(.iso8601)])
      var date: Date
    }
    ```
- Acceptance
  - Pipelines apply in declared order; deterministic codegen, with snapshots.
  - Encode/decode symmetry where applicable; clear diagnostics otherwise.
  - Micro-benchmarks show minimal overhead compared to hand-written equivalents.
  - Documentation with examples and migration notes from options to transformers.

## Known Limitations & Workarounds
- JSON date decoding strategy is not configurable per type
  - Swift’s `Decoder` protocol does not expose `JSONDecoder.dateDecodingStrategy`. Once inside `init(from:)`, you cannot change the strategy.
  - Recommended: configure `JSONDecoder` at the call site (preferred approach).
  - Alternatives when call site cannot be controlled:
    - Pass a `DateFormatter` via `decoder.userInfo` and decode dates from `String` manually in the type.
    - Use wrapper types (e.g., `ISO8601Date`, `MillisecondsSince1970Date`) that handle per-field decoding.
  - Avoid attempting to cast `Decoder` to `JSONDecoder` — it is not reliable and breaks abstraction.

- Performance considerations of workarounds
  - `userInfo` lookups are cheap, but manual `String`→`Date` parsing adds per-field cost.
  - Always reuse static/shared `DateFormatter`/`ISO8601DateFormatter`; constructing formatters per decode is expensive.
  - Raw-string transcoding incurs extra allocations (string→`Data`→model). Keep payloads small; prefer native `Date` decoding when possible.
  - The upcoming Coding Transformer pipeline (1.7.x) will provide official, reusable date transformers with shared formatters and minimal overhead.

- Documentation and benchmarking
  - Add README guidance and examples for the above patterns and trade-offs.
  - Add micro-benchmarks comparing: call-site strategy vs `userInfo` vs wrapper types vs transformer pipelines.

## Transformer Ecosystem, Docs, and Performance (Target: 1.8.x)
- Official transformer set expansion
  - Additional date/time variants (custom calendars/timezones), locale-aware number parsing.
  - Key strategy transformer (e.g., snake_case) as a pipeline stage where applicable.
  - Registry for user-defined transformers and sharing across modules.
- Performance and caching
  - Shared/cached formatters; zero-allocation fast paths; reduce intermediary `Data`/`String` churn.
  - Benchmarks for transformer chains vs. macro options and manual code.
- Tooling & diagnostics
  - Better compile-time validation for transformer chains and inverse-encode coverage.
  - Lint-like mode to preview pipelines without codegen.
- Docs & adoption
  - Cookbook of transformer recipes; migration guide from options to transformers.
  - CI matrix expansion across Apple platforms and Swift toolchains.

## Stretch / Long‑Term Ideas (Post 1.8.x)
- Additional key strategies (e.g., kebab-case) if requested
- Plugin points for custom transforms (user-supplied encode/decode hooks per field)
- Lint-like mode: dry-run expansion check with warnings only
- Better Xcode diagnostics surfacing with notes and fix-its

## Breaking Changes Policy
- Avoid breaking changes in 1.x; introduce new behavior as opt-in options
- If 2.0 is required, provide deprecation path and migration notes at least one minor version beforehand

## Quality Bar (applies to every phase)
- Code-gen is deterministic and minimal
- Clear, localized diagnostic messages with actionable fix-its
- Tests: snapshot + behavioral for all new features and bug fixes
- Performance: no regressions; micro-benchmarks for hot paths
- Security: avoid unbounded allocations; limits and sanity checks in transcode paths

## Tracking and Contribution
- Each roadmap item tracked as an issue with label `roadmap`
- PRs should reference the roadmap item and include tests and docs updates
- Discussion for prioritization in GitHub Discussions or issues

## Quick Checklist (per item)
- [ ] Design note (if needed)
- [ ] Implementation behind options / flags
- [ ] Tests (snapshot + behavioral)
- [ ] Docs (README + examples)
- [ ] Benchmarks (if performance-sensitive)
- [ ] Changelog entry

---

If you have feature requests or feedback, please open an issue with context and examples. This roadmap evolves with community input.
