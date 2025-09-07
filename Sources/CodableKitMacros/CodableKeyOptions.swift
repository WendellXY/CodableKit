//
//  CodableKeyOptions.swift
//  CodableKit
//
//  Created by Wendell on 4/3/24.
//

import CodableKitShared

extension CodableKeyMacro {
  /// Options for customizing the behavior of a `CodableKey`.
  package typealias Options = CodableKeyOptions
}

extension DecodeKeyMacro {
  /// Options for customizing the behavior of a `DecodeKey`.
  package typealias Options = CodableKeyOptions
}

extension EncodeKeyMacro {
  /// Options for customizing the behavior of an `EncodeKey`.
  package typealias Options = CodableKeyOptions
}
