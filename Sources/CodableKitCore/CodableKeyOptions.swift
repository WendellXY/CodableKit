//
//  CodableKeyOptions.swift
//  CodableKitCore
//
//  Shared (runtime + macro implementation) option definitions.
//

public struct CodableKeyOptions: OptionSet, Sendable {
  public let rawValue: Int32

  public init(rawValue: Int32) {
    self.rawValue = rawValue
  }

  /// The default options for a `CodableKey`, which is equivalent to an empty set.
  public static let `default`: Self = []

  /// A convenience option combining ``transcodeRawString`` and ``useDefaultOnFailure`` for safe JSON string transcoding.
  ///
  /// This option provides a safer way to handle string-encoded JSON by automatically falling back to
  /// default values or `nil` when the JSON string is invalid or malformed. It's equivalent to
  /// `[.transcodeRawString, .useDefaultOnFailure]`.
  public static let safeTranscodeRawString: Self = [.transcodeRawString, .useDefaultOnFailure]

  /// The key will be ignored during encoding and decoding.
  public static let ignored = Self(rawValue: 1 << 0)

  /// The key will be explicitly set to `nil` (`null`) when encoding and decoding.
  /// By default, the key will be omitted if the value is `nil`.
  public static let explicitNil = Self(rawValue: 1 << 1)

  /// If the key has a custom CodableKey, a computed property will be generated to access the key; otherwise, this
  /// option is ignored.
  public static let generateCustomKey = Self(rawValue: 1 << 2)

  /// Transcode the value between raw string and the target type.
  public static let transcodeRawString = Self(rawValue: 1 << 3)

  /// Use the default value or `nil` when decoding or encoding fails.
  public static let useDefaultOnFailure = Self(rawValue: 1 << 4)

  /// Decode the value in a lossy way for collections.
  ///
  /// - For arrays and sets: invalid elements are dropped.
  /// - For dictionaries: entries with invalid values (or keys that cannot be
  ///   converted from JSON string keys) are dropped.
  public static let lossy = Self(rawValue: 1 << 5)
}


