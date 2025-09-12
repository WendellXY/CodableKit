//
//  BuiltInTransformerTests.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/9/13.
//

import CodableKit
import Foundation
import Testing

@Codable
struct TestModelDefaultOnFailureTransformer {
  @CodableKey(transformer: DefaultOnFailureTransformer(defaultValue: 0))
  var count: Int
}

@Codable
struct TestModelUseDefaultOnFailureOption {
  @CodableKey(options: .useDefaultOnFailure)
  var count: Int = 0
}

@Suite("Builtin Transformer Tests")
struct BuiltInTransformerTests {
  @Test func testDefaultOnFailureTransformer() async throws {
    let json = #"{"count":"1"}"#
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(TestModelDefaultOnFailureTransformer.self, from: data)
    #expect(decoded.count == 0)

    let oldDecoded = try JSONDecoder().decode(TestModelUseDefaultOnFailureOption.self, from: data)
    #expect(oldDecoded.count == decoded.count)
  }

  @Test func testIdentityTransformer_propagates_success_and_failure() async throws {
    let t = IdentityTransformer<Int>()
    let ok = t.transform(.success(7))
    #expect(try ok.get() == 7)

    enum E: Error { case boom }
    let err = t.transform(.failure(E.boom))
    var threw = false
    do { _ = try err.get() } catch { threw = true }
    #expect(threw)
  }

  @Test func testDefaultOnFailureTransformer_direct() async throws {
    let t = DefaultOnFailureTransformer(defaultValue: 9)
    #expect(try t.transform(.success(1)).get() == 1)

    // Failure recovers to default when provided
    #expect(try t.transform(.failure(NSError(domain: "x", code: 1))).get() == 9)

    // When default is nil, failure should propagate
    let noDefault = DefaultOnFailureTransformer<Int>(defaultValue: nil)
    var threw = false
    do { _ = try noDefault.transform(.failure(NSError(domain: "y", code: 2))).get() } catch { threw = true }
    #expect(threw)
  }

  struct BRoom: Codable, Equatable {
    let id: Int
    let name: String
  }

  @Test func testRawStringDecodingTransformer_success_and_failure() async throws {
    let jsonString = #"{"id":1,"name":"One"}"#
    let t = RawStringDecodingTransformer<BRoom>()
    let ok = try t.transform(.success(jsonString)).get()
    #expect(ok == BRoom(id: 1, name: "One"))

    // Invalid JSON should fail
    let bad = t.transform(.success("not json"))
    var threw = false
    do { _ = try bad.get() } catch { threw = true }
    #expect(threw)
  }

  @Test func testRawStringEncodingTransformer_success() async throws {
    let room = BRoom(id: 2, name: "Two")
    let t = RawStringEncodingTransformer<BRoom>()
    let s = try t.transform(.success(room)).get()
    let dict = try JSONSerialization.jsonObject(with: s.data(using: .utf8)!) as! [String: Any]
    #expect((dict["id"] as? NSNumber)?.intValue == 2)
    #expect(dict["name"] as? String == "Two")
  }

  @Test func testRawStringBidirectionalTransformer_roundtrip() async throws {
    let room = BRoom(id: 3, name: "Three")
    let t = RawStringTransformer<BRoom>()
    let enc = try t.reverseTransform(.success(room)).get()
    let dec = try t.transform(.success(enc)).get()
    #expect(dec == room)
  }

  @Test func testIntegerToBooleanTransformer_decode_and_encode() async throws {
    let t = IntegerToBooleanTransformer<Int>()
    #expect(try t.transform(.success(1)).get() == true)
    #expect(try t.transform(.success(0)).get() == false)
    #expect(try t.reverseTransform(.success(true)).get() == 1)
    #expect(try t.reverseTransform(.success(false)).get() == 0)
  }

  @Test func testKeyPathTransformer_projects_value() async throws {
    struct Wrap { let inner: Int }
    let t = KeyPathTransformer<Wrap, Int>(keyPath: \Wrap.inner)
    #expect(try t.transform(.success(.init(inner: 10))).get() == 10)
  }
}
