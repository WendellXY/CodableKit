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
}
