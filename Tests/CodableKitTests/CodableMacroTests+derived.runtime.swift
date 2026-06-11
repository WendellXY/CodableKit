//
//  CodableMacroTests+derived.runtime.swift
//  CodableKitTests
//
//  Runtime behavior tests for @DerivedKey
//

import CodableKit
import Foundation
import Testing

// Top-level test models (local types cannot have attached macros)

struct DerivedFrame: Codable, Equatable {
  let id: Int
}

/// Pulls the `frame` slot out of a decoded slot-bag and decodes its embedded JSON payload.
private struct DerivedFrameSlotTransformer: CodingTransformer {
  func transform(_ input: Result<[String: String]?, any Error>) -> Result<DerivedFrame?, any Error> {
    input.flatMap { bag in
      guard let rawString = bag?["frame"] else { return .success(nil) }
      return Result {
        guard let data = rawString.data(using: .utf8) else {
          throw DecodingError.dataCorrupted(
            .init(codingPath: [], debugDescription: "Invalid UTF-8 in frame slot")
          )
        }
        return try JSONDecoder().decode(DerivedFrame.self, from: data)
      }
    }
  }
}

private struct DerivedTagCountTransformer: CodingTransformer {
  func transform(_ input: Result<[String], any Error>) -> Result<Int, any Error> {
    input.map(\.count)
  }
}

/// Fails the pipeline when the tag list is empty; used to verify error propagation for
/// non-optional, no-default derived properties.
private struct DerivedStrictCountTransformer: CodingTransformer {
  func transform(_ input: Result<[String], any Error>) -> Result<Int, any Error> {
    input.flatMap { tags in
      guard !tags.isEmpty else {
        return .failure(
          DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "tags must not be empty"))
        )
      }
      return .success(tags.count)
    }
  }
}

@Codable
struct DerivedConfigModel: Equatable {
  var userConfigValue: [String: String]?
  @DerivedKey(from: "userConfigValue", transformer: DerivedFrameSlotTransformer())
  private(set) var avatarFrame: DerivedFrame?
}

@Codable
struct DerivedCountModel: Equatable {
  var tags: [String] = []
  @DerivedKey(from: "tags", transformer: DerivedTagCountTransformer())
  private(set) var tagCount: Int = -1
}

@Codable
struct DerivedStrictModel {
  var tags: [String]
  @DerivedKey(from: "tags", transformer: DerivedStrictCountTransformer())
  private(set) var tagCount: Int
}

@Codable
struct DerivedHookModel {
  var tags: [String] = []
  @DerivedKey(from: "tags", transformer: DerivedTagCountTransformer())
  private(set) var tagCount: Int = -1
  @CodableKey(options: .ignored)
  var observedCount: Int = -2

  @CodableHook(.didDecode)
  mutating func captureDerived() {
    observedCount = tagCount
  }
}

@Codable
class DerivedConfigClass {
  var userConfigValue: [String: String]?
  @DerivedKey(from: "userConfigValue", transformer: DerivedFrameSlotTransformer())
  private(set) var avatarFrame: DerivedFrame?
}

@Codable
class DerivedHookClass {
  var tags: [String] = []
  @DerivedKey(from: "tags", transformer: DerivedTagCountTransformer())
  private(set) var tagCount: Int = -1
  @CodableKey(options: .ignored)
  var observedCount: Int = -2

  @CodableHook(.didDecode)
  func captureDerived() {
    observedCount = tagCount
  }
}

@Codable
class DerivedBaseClass {
  var baseName: String = ""
}

// The child inherits Codable from the base, so the compiler hands the macro an empty
// conformance list; `.skipProtocolConformance` opts back into member generation (the
// established pattern for subclasses of already-Codable bases).
@Codable(options: .skipProtocolConformance)
class DerivedChildClass: DerivedBaseClass {
  var tags: [String] = []
  @DerivedKey(from: "tags", transformer: DerivedTagCountTransformer())
  private(set) var tagCount: Int = -1
}

@Suite struct DerivedKeyRuntimeTests {
  @Test func derivedValue_materializesFromSiblingSlotBag() throws {
    let json = #"{"userConfigValue":{"frame":"{\"id\":7}","other":"x"}}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(DerivedConfigModel.self, from: data)
    #expect(decoded.userConfigValue?["other"] == "x")
    #expect(decoded.avatarFrame == DerivedFrame(id: 7))
  }

  @Test func derivedValue_malformedPayload_fallsBackToNil() throws {
    let json = #"{"userConfigValue":{"frame":"not json"}}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(DerivedConfigModel.self, from: data)
    #expect(decoded.avatarFrame == nil)
  }

  @Test func derivedValue_missingSlot_isNil() throws {
    let json = #"{"userConfigValue":{"other":"x"}}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(DerivedConfigModel.self, from: data)
    #expect(decoded.avatarFrame == nil)
  }

  @Test func derivedValue_roundTripEncode_omitsDerivedProperty() throws {
    let json = #"{"userConfigValue":{"frame":"{\"id\":7}"}}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(DerivedConfigModel.self, from: data)

    let encodedData = try JSONEncoder().encode(decoded)
    let encodedString = String(data: encodedData, encoding: .utf8)!
    #expect(!encodedString.contains("avatarFrame"))

    // Re-decoding the encoded payload re-derives the same value.
    let redecoded = try JSONDecoder().decode(DerivedConfigModel.self, from: encodedData)
    #expect(redecoded == decoded)
  }

  @Test func derivedValue_nonOptionalWithDefault_derivesFromCodedSibling() throws {
    let json = #"{"tags":["a","b","c"]}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(DerivedCountModel.self, from: data)
    #expect(decoded.tagCount == 3)
  }

  @Test func derivedValue_nonOptionalNoDefault_pipelineFailure_throwsFromDecode() throws {
    let json = #"{"tags":[]}"#
    let data = json.data(using: .utf8)!
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(DerivedStrictModel.self, from: data)
    }
  }

  @Test func derivedValue_nonOptionalNoDefault_pipelineSuccess_decodes() throws {
    let json = #"{"tags":["a","b"]}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(DerivedStrictModel.self, from: data)
    #expect(decoded.tagCount == 2)
  }

  @Test func derivedValue_structDidDecodeHook_observesDerivedValue() throws {
    let json = #"{"tags":["a","b","c"]}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(DerivedHookModel.self, from: data)
    #expect(decoded.tagCount == 3)
    #expect(decoded.observedCount == 3)
  }
}

@Suite struct DerivedKeyClassRuntimeTests {
  @Test func derivedValue_classWithoutSuperclass_materializes() throws {
    let json = #"{"userConfigValue":{"frame":"{\"id\":11}"}}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(DerivedConfigClass.self, from: data)
    #expect(decoded.avatarFrame == DerivedFrame(id: 11))
  }

  @Test func derivedValue_classDidDecodeHook_observesDerivedValue() throws {
    let json = #"{"tags":["a","b"]}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(DerivedHookClass.self, from: data)
    #expect(decoded.tagCount == 2)
    #expect(decoded.observedCount == 2)
  }

  @Test func derivedValue_subclass_derivesBeforeSuperInit() throws {
    // The generated init must assign the derived property before `try super.init(from:)`,
    // otherwise this would not compile; decoding proves both halves run.
    let json = #"{"baseName":"root","tags":["a","b"]}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(DerivedChildClass.self, from: data)
    #expect(decoded.baseName == "root")
    #expect(decoded.tagCount == 2)
  }
}
