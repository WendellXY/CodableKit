//
//  LossyArray.swift
//  CodableKit
//
//  Created by Wendell Wang on 2025/9/5.
//

import Foundation

/// A custom wrapper to handle lossy decoding
public struct LossyArray<Element: Decodable>: Decodable {
  public var elements: [Element] = []

  public init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    var result: [Element] = []
    while !container.isAtEnd {
      do {
        result.append(try container.decode(Element.self))
      } catch {
        _ = try? container.superDecoder()  // robustly advance one element
      }
    }
    self.elements = result
  }
}

extension LossyArray: Sendable where Element: Sendable {}
extension LossyArray: Equatable where Element: Equatable {}
extension LossyArray: Hashable where Element: Hashable {}

extension LossyArray: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: Element...) {
    self.elements = elements
  }
}

extension LossyArray: CustomStringConvertible {
  public var description: String {
    return "LossyArray(\(elements.map { "\($0)" }.joined(separator: ", ")))"
  }
}

extension LossyArray: CustomDebugStringConvertible {
  public var debugDescription: String {
    return "LossyArray(\(elements.map { "\($0)" }.joined(separator: ", ")))"
  }
}

extension LossyArray: Sequence {
  public func makeIterator() -> IndexingIterator<[Element]> {
    return elements.makeIterator()
  }
}
