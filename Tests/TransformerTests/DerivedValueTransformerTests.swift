//
//  DerivedValueTransformerTests.swift
//  CodableKit
//
//  Created by Wendell Wang on 2026/6/11.
//

import CodableKit
import Foundation
import Testing

@Suite("Derived Value Transformer Tests")
struct DerivedValueTransformerTests {
  enum TestError: Error { case boom }

  // MARK: - DictionaryLookupTransformer

  @Test func dictionaryLookup_hit_returns_value() async throws {
    let t = DictionaryLookupTransformer<String, Int>(key: "a")
    #expect(try t.transform(.success(["a": 1, "b": 2])).get() == 1)
  }

  @Test func dictionaryLookup_miss_returns_nil_without_error() async throws {
    let t = DictionaryLookupTransformer<String, Int>(key: "missing")
    #expect(try t.transform(.success(["a": 1])).get() == nil)
  }

  @Test func dictionaryLookup_nilDictionary_returns_nil_without_error() async throws {
    let t = DictionaryLookupTransformer<String, Int>(key: "a")
    #expect(try t.transform(.success(nil)).get() == nil)
  }

  @Test func dictionaryLookup_propagates_upstream_failure() async throws {
    let t = DictionaryLookupTransformer<String, Int>(key: "a")
    var threw = false
    do { _ = try t.transform(.failure(TestError.boom)).get() } catch { threw = true }
    #expect(threw)
  }

  @Test func dictionaryLookup_accepts_nonOptional_dictionary_source() async throws {
    // A non-optional dictionary promotes implicitly into the `[K: V]?` input.
    let dict: [String: Int] = ["a": 1]
    let lookup = DictionaryLookupTransformer<String, Int>(key: "a")
    #expect(try lookup.transform(.success(dict)).get() == 1)

    // And a chain whose source is non-optional composes via `optional()`.
    let chained = IdentityTransformer<[String: Int]>()
      .optional()
      .chained(DictionaryLookupTransformer<String, Int>(key: "a"))
    #expect(try chained.transform(.success(dict)).get() == 1)
  }

  // MARK: - liftOptional

  @Test func liftOptional_nil_input_passes_through_as_nil() async throws {
    let t = IntegerToBooleanTransformer<Int>().liftOptional()
    #expect(try t.transform(.success(nil)).get() == nil)
  }

  @Test func liftOptional_nonNil_input_runs_base_transformer() async throws {
    let t = IntegerToBooleanTransformer<Int>().liftOptional()
    #expect(try t.transform(.success(1)).get() == true)
    #expect(try t.transform(.success(0)).get() == false)
  }

  @Test func liftOptional_propagates_upstream_failure() async throws {
    let t = IntegerToBooleanTransformer<Int>().liftOptional()
    var threw = false
    do { _ = try t.transform(.failure(TestError.boom)).get() } catch { threw = true }
    #expect(threw)
  }

  @Test func liftOptional_recovering_base_recovers_upstream_failure() async throws {
    let t = DefaultOnFailureTransformer(defaultValue: 9).liftOptional()

    // Upstream failure is forwarded into the base, which recovers to .some(default).
    #expect(try t.transform(.failure(TestError.boom)).get() == 9)

    // Upstream nil stays nil; the base transformer is never invoked.
    #expect(try t.transform(.success(nil)).get() == nil)
  }

  struct DRoom: Codable, Equatable {
    let id: Int
    let name: String
  }

  @Test func liftOptional_propagates_base_transformer_failure() async throws {
    let t = RawStringDecodingTransformer<DRoom>().liftOptional()
    var threw = false
    do { _ = try t.transform(.success("not json")).get() } catch { threw = true }
    #expect(threw)
  }

  @Test func liftOptional_bidirectional_reverse_maps_nil_and_value() async throws {
    let t = IntegerToBooleanTransformer<Int>().liftOptional()
    #expect(try t.reverseTransform(.success(nil)).get() == nil)
    #expect(try t.reverseTransform(.success(true)).get() == 1)
    #expect(try t.reverseTransform(.success(false)).get() == 0)
  }

  // MARK: - onFailure

  @Test func onFailure_invoked_on_failure_and_result_unchanged() async throws {
    var observed: [any Error] = []
    let t = IdentityTransformer<Int>().onFailure { observed.append($0) }
    let result = t.transform(.failure(TestError.boom))

    #expect(observed.count == 1)
    #expect(observed.first is TestError)

    var caught: (any Error)?
    do { _ = try result.get() } catch { caught = error }
    #expect(caught is TestError)
  }

  @Test func onFailure_not_invoked_on_success_and_result_unchanged() async throws {
    var observed: [any Error] = []
    let t = IdentityTransformer<Int>().onFailure { observed.append($0) }
    #expect(try t.transform(.success(7)).get() == 7)
    #expect(observed.isEmpty)
  }

  @Test func onFailure_observes_failure_produced_by_base_transformer() async throws {
    var observed: [any Error] = []
    let t = RawStringDecodingTransformer<DRoom>().onFailure { observed.append($0) }
    var threw = false
    do { _ = try t.transform(.success("not json")).get() } catch { threw = true }
    #expect(threw)
    #expect(observed.count == 1)
  }

  // MARK: - End-to-end: derived value from a slot bag

  /// Mirrors the motivating payload shape: an optional dictionary of slot bags
  /// keyed by config id, where each slot holds an embedded JSON string.
  struct Slot: Decodable {
    var str1: String?
  }

  struct FeatureConfig: Decodable, Equatable {
    let enabled: Bool
    let limit: Int
  }

  /// Dictionary lookup by key, key-path projection to the slot string, then
  /// JSON-decode of the embedded string — all from CodableKit primitives.
  static func makeDerivedValuePipeline() -> some CodingTransformer<[String: Slot]?, FeatureConfig?> {
    DictionaryLookupTransformer<String, Slot>(key: "10010")
      .chained(KeyPathTransformer<Slot?, String?>(keyPath: \Slot?.?.str1))
      .chained(RawStringDecodingTransformer<FeatureConfig>().liftOptional())
  }

  @Test func endToEnd_present_valid_json_decodes_typed_value() async throws {
    let slots: [String: Slot]? = ["10010": Slot(str1: #"{"enabled":true,"limit":3}"#)]
    let result = Self.makeDerivedValuePipeline().transform(.success(slots))
    #expect(try result.get() == FeatureConfig(enabled: true, limit: 3))
  }

  @Test func endToEnd_missing_key_yields_nil_without_error() async throws {
    let slots: [String: Slot]? = ["99999": Slot(str1: "{}")]
    #expect(try Self.makeDerivedValuePipeline().transform(.success(slots)).get() == nil)

    // A nil dictionary and an empty slot are also nil, not errors.
    #expect(try Self.makeDerivedValuePipeline().transform(.success(nil)).get() == nil)
    #expect(try Self.makeDerivedValuePipeline().transform(.success(["10010": Slot(str1: nil)])).get() == nil)
  }

  @Test func endToEnd_malformed_json_fails_and_onFailure_observes() async throws {
    var observed: [any Error] = []
    let pipeline = Self.makeDerivedValuePipeline().onFailure { observed.append($0) }
    let slots: [String: Slot]? = ["10010": Slot(str1: "not json")]

    var threw = false
    do { _ = try pipeline.transform(.success(slots)).get() } catch { threw = true }
    #expect(threw)
    #expect(observed.count == 1)
    #expect(observed.first is DecodingError)
  }
}
