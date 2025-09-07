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

extension DecodableKeyMacro {
  /// Options for customizing the behavior of a `DecodeKey`.
  package typealias Options = CodableKeyOptions
}

extension EncodableKeyMacro {
  /// Options for customizing the behavior of an `EncodeKey`.
  package typealias Options = CodableKeyOptions
}
