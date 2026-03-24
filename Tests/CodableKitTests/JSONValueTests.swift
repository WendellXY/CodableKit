//
//  JSONValueTests.swift
//  CodableKitTests
//
//  Created by Assistant on 2026/3/24.
//

import CodableKit
import Foundation
import Testing

@Codable
struct JSONValuePayload {
  var value: JSONValue
}

@Suite("JSONValue runtime tests")
struct JSONValueTests {
  @Test func decode_scalar_values() throws {
    #expect(try decodeJSONValue("null") == .null)
    #expect(try decodeJSONValue("true") == .bool(true))
    #expect(try decodeJSONValue(#""hello""#) == .string("hello"))
    #expect(try decodeJSONValue("123") == .int(123))
    #expect(try decodeJSONValue("123.5") == .double(123.5))
  }

  @Test func decode_nested_arrays_and_objects() throws {
    let value = try decodeJSONValue(#"{"x":[1,"a",true,null],"y":{"z":2.5}}"#)

    #expect(
      value == .object([
        "x": .array([.int(1), .string("a"), .bool(true), .null]),
        "y": .object(["z": .double(2.5)]),
      ])
    )
  }

  @Test func encode_scalar_values() throws {
    try assertEncodesToJSON(.null, expected: NSNull())
    try assertEncodesToJSON(.bool(false), expected: false)
    try assertEncodesToJSON(.string("hello"), expected: "hello")
    try assertEncodesToJSON(.int(123), expected: 123)
    try assertEncodesToJSON(.double(123.5), expected: 123.5)
  }

  @Test func encode_nested_values() throws {
    let value = JSONValue.object([
      "meta": .object([
        "enabled": .bool(true),
        "score": .double(9.5),
      ]),
      "items": .array([.int(1), .string("two"), .null]),
    ])

    let encoded = try JSONEncoder().encode(value)
    let object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]

    let meta = object["meta"] as? [String: Any]
    let items = object["items"] as? [Any]

    #expect(meta?["enabled"] as? Bool == true)
    #expect((meta?["score"] as? NSNumber)?.doubleValue == 9.5)
    #expect((items?[0] as? NSNumber)?.intValue == 1)
    #expect(items?[1] as? String == "two")
    #expect(items?[2] is NSNull)
  }

  @Test func round_trips_mixed_payloads() throws {
    let original = JSONValue.object([
      "user": .object([
        "id": .int(7),
        "name": .string("Ada"),
        "flags": .array([.bool(true), .bool(false)]),
      ]),
      "score": .double(10.25),
      "note": .null,
    ])

    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

    #expect(decoded == original)
  }

  @Test func accessors_and_subscripts_follow_runtime_shape() throws {
    let value = JSONValue.object([
      "name": .string("Ada"),
      "stats": .array([.int(3), .double(4.5), .null]),
    ])

    #expect(value.isNull == false)
    #expect(value["name"]?.stringValue == "Ada")
    #expect(value["name"]?.intValue == nil)
    #expect(value["stats"]?[0]?.intValue == 3)
    #expect(value["stats"]?[1]?.doubleValue == 4.5)
    #expect(value["stats"]?[2]?.isNull == true)
    #expect(value["stats"]?[3] == nil)
    #expect(value["missing"] == nil)
  }

  @Test func literal_conveniences_build_expected_tree() {
    let nullValue: JSONValue = nil
    let boolValue: JSONValue = true
    let stringValue: JSONValue = "hello"
    let intValue: JSONValue = 123
    let doubleValue: JSONValue = 123.5
    let arrayValue: JSONValue = [1, "two", false, nil]
    let objectValue: JSONValue = [
      "name": "Ada",
      "count": 3,
      "flags": [true, nil],
    ]

    #expect(nullValue == .null)
    #expect(boolValue == .bool(true))
    #expect(stringValue == .string("hello"))
    #expect(intValue == .int(123))
    #expect(doubleValue == .double(123.5))
    #expect(arrayValue == .array([.int(1), .string("two"), .bool(false), .null]))
    #expect(
      objectValue == .object([
        "name": .string("Ada"),
        "count": .int(3),
        "flags": .array([.bool(true), .null]),
      ])
    )
  }

  @Test func payload_model_decodes_dynamic_values() throws {
    let scalarPayload = try JSONDecoder().decode(
      JSONValuePayload.self,
      from: #"{"value":123}"#.data(using: .utf8)!
    )
    #expect(scalarPayload.value == .int(123))

    let stringPayload = try JSONDecoder().decode(
      JSONValuePayload.self,
      from: #"{"value":"hello"}"#.data(using: .utf8)!
    )
    #expect(stringPayload.value == .string("hello"))

    let nestedPayload = try JSONDecoder().decode(
      JSONValuePayload.self,
      from: #"{"value":{"x":[1,"a",true,null]}}"#.data(using: .utf8)!
    )
    #expect(
      nestedPayload.value == .object([
        "x": .array([.int(1), .string("a"), .bool(true), .null]),
      ])
    )
  }

  private func decodeJSONValue(_ json: String) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
  }

  private func assertEncodesToJSON(_ value: JSONValue, expected: Any) throws {
    let data = try JSONEncoder().encode(value)
    let decoded = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)

    switch expected {
    case is NSNull:
      #expect(decoded is NSNull)
    case let expected as Bool:
      #expect(decoded as? Bool == expected)
    case let expected as String:
      #expect(decoded as? String == expected)
    case let expected as Int:
      #expect((decoded as? NSNumber)?.intValue == expected)
    case let expected as Double:
      #expect((decoded as? NSNumber)?.doubleValue == expected)
    default:
      fatalError("Unhandled expected value type")
    }
  }
}
