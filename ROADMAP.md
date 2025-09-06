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
- 1.7.x: Phase 3 — expressiveness & conventions
- 1.8.x: Phase 4 — docs, performance, CI
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
- [ ] Lossy decoding for dictionaries (`.lossy`)
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

## Phase 3 — Expressiveness and Conventions (Target: 1.7.x)
- Global key naming strategy: `.snakeCaseKeys`
  - Acceptance:
    - `CodingKeys` defaults to snake_case unless overridden by `@CodableKey`
    - Works with nested key-paths and custom keys
- Transform options for common API quirks
  - `numberFromString`, `boolFromInt`, `dateISO8601`, `dateMillisecondsSince1970`
  - Acceptance:
    - Encode/decode apply transforms correctly
    - Composition with `.useDefaultOnFailure` behaves as expected
- Tests
  - snake_case with overrides and nesting
  - Transforms including edge cases (invalid inputs, timezones, empty strings)

## Phase 4 — Docs, Performance, and CI (Target: 1.8.x)
- Documentation updates (README, examples, migration notes)
  - Acceptance:
    - New options documented with concise examples
    - Clear guidance on defaults vs. `.useDefaultOnFailure`
- Benchmarks for critical paths
  - Acceptance:
    - Micro-bench for transcode and lossy paths comparing before/after
- CI matrix expansion
  - Acceptance:
    - Test on latest macOS/iOS/tvOS/watchOS and Swift toolchains

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
