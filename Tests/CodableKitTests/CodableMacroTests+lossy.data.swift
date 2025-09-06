//
//  CodableMacroTests+lossy.data.swift
//  CodableKitTests
//
//  Runtime behavior tests for lossy decoding
//

import CodableKit
import Foundation
import Testing

// Top-level test models (local types cannot have attached macros)
struct LossyItem: Codable, Equatable { let id: Int }

@Codable
struct LossyArrayModel {
  @CodableKey(options: .lossy)
  var items: [LossyItem]
}

@Codable
struct LossyOptionalSetModel {
  @CodableKey(options: .lossy)
  var tags: Set<String>?
}

@Codable
struct LossyDefaultModel {
  @CodableKey(options: [.lossy, .useDefaultOnFailure])
  var items: [LossyItem] = [LossyItem(id: 7)]
}

@Codable
struct LossyTranscodeModel {
  @CodableKey(options: [.lossy, .transcodeRawString])
  var values: [Int]
}

@Codable
struct LossySafeTranscodeModel {
  @CodableKey(options: [.lossy, .safeTranscodeRawString])
  var values: [Int] = [1, 2]
}

@Codable
struct LossyDictStringIntModel {
  @CodableKey(options: .lossy)
  var map: [String: Int]
}

@Codable
struct LossyDictIntDoubleModel {
  @CodableKey(options: .lossy)
  var map: [Int: Double]
}

@Codable
struct LossyOptionalDictModel {
  @CodableKey(options: .lossy)
  var scores: [String: Int]?
}

@Codable
struct LossyDictDefaultModel {
  @CodableKey(options: [.lossy, .useDefaultOnFailure])
  var map: [String: Int] = ["a": 1]
}

@Codable
struct LossyDictTranscodeModel {
  @CodableKey(options: [.lossy, .transcodeRawString])
  var map: [String: Int]
}

@Codable
struct LossyDictSafeTranscodeModel {
  @CodableKey(options: [.lossy, .safeTranscodeRawString])
  var map: [String: Int] = [:]
}

@Suite struct LossyRuntimeTests {
  @Test func lossyArray_dropsInvalidElements() throws {
    let json = #"{"items":[{"id":1},{"id":"oops"},{"id":3},{"bad":true},4,{"id":5}] }"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(LossyArrayModel.self, from: data)
    #expect(decoded.items == [LossyItem(id: 1), LossyItem(id: 3), LossyItem(id: 5)])
  }

  @Test func lossySet_optional_missingKey_isNil() throws {
    let json = #"{}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(LossyOptionalSetModel.self, from: data)
    #expect(decoded.tags == nil)
  }

  @Test func lossyArray_withDefault_and_useDefaultOnFailure() throws {
    // Non-array type for items → falls back to default due to .useDefaultOnFailure
    let json = #"{"items": 123}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(LossyDefaultModel.self, from: data)
    #expect(decoded.items == [LossyItem(id: 7)])
  }

  @Test func lossy_transcodeRawString_combined() throws {
    // values is a JSON string with mixed valid/invalid entries
    let embedded = #"[{\"id\":1},2,3,\"oops\",4]"#
    let payload = #"{"values":"\#(embedded)"}"#
    let data = payload.data(using: .utf8)!

    // Note: Our lossy path expects element to be Int; non-ints will be dropped
    let decoded = try JSONDecoder().decode(LossyTranscodeModel.self, from: data)
    #expect(decoded.values == [2, 3, 4])
  }

  @Test func lossy_safeTranscodeRawString_withDefault() throws {
    // Missing/invalid string should fall back to default
    let payload = #"{"values": null}"#
    let data = payload.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(LossySafeTranscodeModel.self, from: data)
    #expect(decoded.values == [1, 2])
  }

  @Test func lossyDict_dropsInvalidEntries() throws {
    // Mixed types inside the object; invalid entries dropped
    let json = #"{"map":{"a":1,"b":"oops","c":3,"d":true,"e":4}}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(LossyDictStringIntModel.self, from: data)
    #expect(decoded.map == ["a": 1, "c": 3, "e": 4])
  }

  @Test func lossyDict_dropsNonConvertibleKeys_andInvalidValues() throws {
    // Keys must be LosslessStringConvertible (Int). "two" cannot convert and is dropped.
    // Also drops value that cannot decode as Double
    let json = #"{"map":{"1":0.5,"two":2.5,"3":"bad","4":4}}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(LossyDictIntDoubleModel.self, from: data)
    #expect(decoded.map == [1: 0.5, 4: 4.0])
  }

  @Test func lossyDict_optional_missingKey_isNil() throws {
    let json = #"{}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(LossyOptionalDictModel.self, from: data)
    #expect(decoded.scores == nil)
  }

  @Test func lossyDict_withDefault_and_useDefaultOnFailure() throws {
    // Non-dictionary value → fallback to default due to .useDefaultOnFailure
    let json = #"{"map": 123}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(LossyDictDefaultModel.self, from: data)
    #expect(decoded.map == ["a": 1])
  }

  @Test func lossyDict_transcodeRawString_combined() throws {
    // Dictionary encoded as a JSON string with some invalid entries
    let embedded = #"{\"a\":1,\"b\":\"oops\",\"c\":3}"#
    let payload = #"{"map":"\#(embedded)"}"#
    let data = payload.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(LossyDictTranscodeModel.self, from: data)
    #expect(decoded.map == ["a": 1, "c": 3])
  }

  @Test func lossyDict_safeTranscodeRawString_withDefault() throws {
    let payload = #"{"map": null}"#
    let data = payload.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(LossyDictSafeTranscodeModel.self, from: data)
    #expect(decoded.map == [:])
  }
}
