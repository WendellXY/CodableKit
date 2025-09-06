//
//  CodingTransformerTests+data.swift
//  CodableKitTests
//
//  Runtime behavior tests for CodingTransformer
//

import CodableKit
import Foundation
import Testing

// MARK: - Transformers

struct IntFromString: BidirectionalCodingTransformer {
  func transform(_ input: Result<String, any Error>) -> Result<Int, any Error> {
    input.map { Int($0) ?? 0 }
  }

  func reverseTransform(_ input: Result<Int, any Error>) -> Result<String, any Error> {
    input.map(String.init)
  }
}

struct ISO8601DateTransformer: BidirectionalCodingTransformer {
  func transform(_ input: Result<String, any Error>) -> Result<Date, any Error> {
    input.flatMap { str in
      let f = ISO8601DateFormatter()
      f.formatOptions = [.withInternetDateTime]
      if let d = f.date(from: str) {
        return .success(d)
      }
      return .failure(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid ISO8601")))
    }
  }

  func reverseTransform(_ input: Result<Date, any Error>) -> Result<String, any Error> {
    input.map {
      let f = ISO8601DateFormatter()
      f.formatOptions = [.withInternetDateTime]
      return f.string(from: $0)
    }
  }
}

// MARK: - Models

@Codable
struct ModelIntNonOptional {
  @CodableKey(transformer: IntFromString())
  var count: Int
}

@Codable
struct ModelIntOptional {
  @CodableKey(transformer: IntFromString())
  var count: Int?
}

@Codable
struct ModelIntOptionalExplicitNil {
  @CodableKey(options: .explicitNil, transformer: IntFromString())
  var count: Int?
}

@Codable
struct ModelIntDefaultUseDefault {
  @CodableKey(options: .useDefaultOnFailure, transformer: IntFromString())
  var count: Int = 42
}

@Codable
struct ModelDateNonOptional {
  @CodableKey(
    transformer: ISO8601DateTransformer()
      .chained(DefaultOnFailureTransformer(defaultValue: .distantPast))
  )
  var date: Date
}

// MARK: - Tests

@Suite struct CodingTransformerRuntimeTests {
  @Test func decode_nonOptional_transformer() throws {
    let json = #"{"count":"123"}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(ModelIntNonOptional.self, from: data)
    #expect(decoded.count == 123)
  }

  @Test func encode_nonOptional_transformer() throws {
    let model = ModelIntNonOptional(count: 45)
    let data = try JSONEncoder().encode(model)
    // Expect count encoded as string
    let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(dict["count"] as? String == "45")
  }

  @Test func optional_missingKey_decodes_nil_and_omits_key_on_encode() throws {
    let json = #"{}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(ModelIntOptional.self, from: data)
    #expect(decoded.count == nil)

    let encoded = try JSONEncoder().encode(decoded)
    let dict = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
    #expect(dict["count"] == nil)
  }

  @Test func optional_explicitNil_encodes_null() throws {
    let model = ModelIntOptionalExplicitNil(count: nil)
    let data = try JSONEncoder().encode(model)
    let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(dict["count"] is NSNull)
  }

  @Test func useDefaultOnFailure_falls_back_on_type_mismatch_and_missing() throws {
    // Type mismatch (number instead of string) → default 42
    let jsonMismatch = #"{"count": 7}"#
    let dataMismatch = jsonMismatch.data(using: .utf8)!
    let decodedMismatch = try JSONDecoder().decode(ModelIntDefaultUseDefault.self, from: dataMismatch)
    #expect(decodedMismatch.count == 42)

    // Missing key → default 42
    let jsonMissing = #"{}"#
    let dataMissing = jsonMissing.data(using: .utf8)!
    let decodedMissing = try JSONDecoder().decode(ModelIntDefaultUseDefault.self, from: dataMissing)
    #expect(decodedMissing.count == 42)

    // Valid string → transformed value
    let jsonOK = #"{"count":"5"}"#
    let dataOK = jsonOK.data(using: .utf8)!
    let decodedOK = try JSONDecoder().decode(ModelIntDefaultUseDefault.self, from: dataOK)
    #expect(decodedOK.count == 5)
  }

  @Test func date_transformer_decode_and_encode_iso8601() throws {
    let s = "2020-01-02T03:04:05Z"
    let json = #"{"date":"\#(s)"}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(ModelDateNonOptional.self, from: data)
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    let expected = f.date(from: s)!
    #expect(abs(decoded.date.timeIntervalSince1970 - expected.timeIntervalSince1970) < 0.5)

    let encoded = try JSONEncoder().encode(decoded)
    let dict = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
    #expect(dict["date"] as? String == s)
  }

  @Test func date_transformer_decode_and_encode_iso8601_with_default_on_failure() throws {
    let s = "null"
    let json = #"{"date":"\#(s)"}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(ModelDateNonOptional.self, from: data)
    #expect(decoded.date == .distantPast)
  }
}
