//
//  JSONValueCoercionTests.swift
//  CodableKitTests
//
//  Created by Wendell Wang on 2026/4/2.
//

import CodableKit
import Testing

@Suite("JSONValue coercion tests")
struct JSONValueCoercionTests {

  // MARK: - coercedBoolValue

  @Suite("coercedBoolValue")
  struct CoercedBool {
    @Test func from_bool() {
      #expect(JSONValue.bool(true).coercedBoolValue == true)
      #expect(JSONValue.bool(false).coercedBoolValue == false)
    }

    @Test func from_int() {
      #expect(JSONValue.int(1).coercedBoolValue == true)
      #expect(JSONValue.int(0).coercedBoolValue == false)
      #expect(JSONValue.int(-1).coercedBoolValue == true)
      #expect(JSONValue.int(42).coercedBoolValue == true)
    }

    @Test func from_double() {
      #expect(JSONValue.double(1.0).coercedBoolValue == true)
      #expect(JSONValue.double(0.0).coercedBoolValue == false)
      #expect(JSONValue.double(0.5).coercedBoolValue == true)
    }

    @Test func from_truthy_strings() {
      for s in ["true", "True", "TRUE", "t", "T", "yes", "Yes", "YES", "y", "Y", "1"] {
        #expect(JSONValue.string(s).coercedBoolValue == true, "Expected true for \"\(s)\"")
      }
    }

    @Test func from_falsy_strings() {
      for s in ["false", "False", "FALSE", "f", "F", "no", "No", "NO", "n", "N", "0"] {
        #expect(JSONValue.string(s).coercedBoolValue == false, "Expected false for \"\(s)\"")
      }
    }

    @Test func from_unrecognized_string() {
      #expect(JSONValue.string("maybe").coercedBoolValue == nil)
      #expect(JSONValue.string("2").coercedBoolValue == nil)
      #expect(JSONValue.string("").coercedBoolValue == nil)
    }

    @Test func from_null_array_object() {
      #expect(JSONValue.null.coercedBoolValue == nil)
      #expect(JSONValue.array([]).coercedBoolValue == nil)
      #expect(JSONValue.object([:]).coercedBoolValue == nil)
    }
  }

  // MARK: - coercedIntValue

  @Suite("coercedIntValue")
  struct CoercedInt {
    @Test func from_int() {
      #expect(JSONValue.int(42).coercedIntValue == 42)
      #expect(JSONValue.int(-1).coercedIntValue == -1)
      #expect(JSONValue.int(0).coercedIntValue == 0)
    }

    @Test func from_double_exact() {
      #expect(JSONValue.double(3.0).coercedIntValue == 3)
      #expect(JSONValue.double(-5.0).coercedIntValue == -5)
    }

    @Test func from_double_fractional() {
      #expect(JSONValue.double(3.5).coercedIntValue == nil)
      #expect(JSONValue.double(0.1).coercedIntValue == nil)
    }

    @Test func from_bool() {
      #expect(JSONValue.bool(true).coercedIntValue == 1)
      #expect(JSONValue.bool(false).coercedIntValue == 0)
    }

    @Test func from_numeric_string() {
      #expect(JSONValue.string("123").coercedIntValue == 123)
      #expect(JSONValue.string("-7").coercedIntValue == -7)
      #expect(JSONValue.string("0").coercedIntValue == 0)
    }

    @Test func from_float_string_exact() {
      #expect(JSONValue.string("3.0").coercedIntValue == 3)
    }

    @Test func from_float_string_fractional() {
      #expect(JSONValue.string("3.5").coercedIntValue == nil)
    }

    @Test func from_non_numeric_string() {
      #expect(JSONValue.string("abc").coercedIntValue == nil)
      #expect(JSONValue.string("").coercedIntValue == nil)
    }

    @Test func from_null_array_object() {
      #expect(JSONValue.null.coercedIntValue == nil)
      #expect(JSONValue.array([]).coercedIntValue == nil)
      #expect(JSONValue.object([:]).coercedIntValue == nil)
    }
  }

  // MARK: - coercedDoubleValue

  @Suite("coercedDoubleValue")
  struct CoercedDouble {
    @Test func from_double() {
      #expect(JSONValue.double(3.14).coercedDoubleValue == 3.14)
    }

    @Test func from_int() {
      #expect(JSONValue.int(42).coercedDoubleValue == 42.0)
    }

    @Test func from_bool() {
      #expect(JSONValue.bool(true).coercedDoubleValue == 1.0)
      #expect(JSONValue.bool(false).coercedDoubleValue == 0.0)
    }

    @Test func from_numeric_string() {
      #expect(JSONValue.string("3.14").coercedDoubleValue == 3.14)
      #expect(JSONValue.string("42").coercedDoubleValue == 42.0)
      #expect(JSONValue.string("-1.5").coercedDoubleValue == -1.5)
    }

    @Test func from_non_numeric_string() {
      #expect(JSONValue.string("abc").coercedDoubleValue == nil)
      #expect(JSONValue.string("").coercedDoubleValue == nil)
    }

    @Test func from_null_array_object() {
      #expect(JSONValue.null.coercedDoubleValue == nil)
      #expect(JSONValue.array([]).coercedDoubleValue == nil)
      #expect(JSONValue.object([:]).coercedDoubleValue == nil)
    }
  }

  // MARK: - coercedStringValue

  @Suite("coercedStringValue")
  struct CoercedString {
    @Test func from_string() {
      #expect(JSONValue.string("hello").coercedStringValue == "hello")
    }

    @Test func from_bool() {
      #expect(JSONValue.bool(true).coercedStringValue == "true")
      #expect(JSONValue.bool(false).coercedStringValue == "false")
    }

    @Test func from_int() {
      #expect(JSONValue.int(42).coercedStringValue == "42")
      #expect(JSONValue.int(-1).coercedStringValue == "-1")
    }

    @Test func from_double() {
      #expect(JSONValue.double(3.14).coercedStringValue == "3.14")
    }

    @Test func from_null() {
      #expect(JSONValue.null.coercedStringValue == "null")
    }

    @Test func from_array_object() {
      #expect(JSONValue.array([]).coercedStringValue == nil)
      #expect(JSONValue.object([:]).coercedStringValue == nil)
    }
  }

  // MARK: - Compatibility numeric accessors with coercion

  @Suite("Compatibility numeric coercion")
  struct CompatibilityNumeric {
    @Test func int64Value_from_string() {
      #expect(JSONValue.string("123").int64Value == 123)
      #expect(JSONValue.string("3.0").int64Value == 3)
      #expect(JSONValue.string("abc").int64Value == nil)
    }

    @Test func int64Value_from_bool() {
      #expect(JSONValue.bool(true).int64Value == 1)
      #expect(JSONValue.bool(false).int64Value == 0)
    }

    @Test func int8Value_from_string() {
      #expect(JSONValue.string("42").int8Value == 42)
      #expect(JSONValue.string("200").int8Value == nil) // overflow
      #expect(JSONValue.string("abc").int8Value == nil)
    }

    @Test func int8Value_from_bool() {
      #expect(JSONValue.bool(true).int8Value == 1)
      #expect(JSONValue.bool(false).int8Value == 0)
    }

    @Test func numberValue_from_string() {
      #expect(JSONValue.string("3.14").numberValue == 3.14)
      #expect(JSONValue.string("42").numberValue == 42.0)
      #expect(JSONValue.string("abc").numberValue == nil)
    }

    @Test func numberValue_from_bool() {
      #expect(JSONValue.bool(true).numberValue == 1.0)
      #expect(JSONValue.bool(false).numberValue == 0.0)
    }
  }
}
