# CodableKit ⚡️

[![Swift Version](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWendellXY%2FCodableKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/WendellXY/CodableKit)
[![Platform](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWendellXY%2FCodableKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/WendellXY/CodableKit)
![CI](https://img.shields.io/github/actions/workflow/status/WendellXY/CodableKit/ci.yml)

CodableKit is a Swift macro package designed to simplify the use of Swift's `Codable` protocol by allowing easy
integration of default values, reducing the amount of auxiliary code you need to write.

## Features

- Custom coding keys
- Default values for missing data
- Handling of decoding failures
- String to struct transcoding
- Property ignoring
- Explicit nil handling
- Custom key property generation

## Usage

To use the Codable macro, simply add the `@Codable` attribute to your struct declaration.

```swift
@Codable
struct Car {
    let brand: String
    let model: String
    var year: Int = 2024
}
```

By setting the default value of the `year` property to 2024, the value will be 2024 when the raw data does not include that property.

## Advanced Usage

The Codable macro provides several additional features through the `@CodableKey` attribute and its associated options:

*	**Custom Coding Keys**: Change the coding key for a property.

```swift
@CodableKey("uid")
let id: UUID
```

* **CodableKeyOptions**: Customize the behavior of properties using various options.

```swift
@CodableKey(options: [.useDefaultOnFailure, .transcodeRawString])
var someProperty: SomeType
```

> You can find the details in the [CodableKeyOptions.swift](Sources/CodableKitShared/CodableKeyOptions.swift) file.

Available options:
* `.default`: The default options (empty set).
* `.ignored`: The property will be ignored during encoding and decoding.
* `.explicitNil`: The key will be explicitly set to `nil` (`null`) when encoding and decoding, instead of being omitted.
* `.generateCustomKey`: Generates a computed property to access the key when a custom CodableKey is used.
* `.transcodeRawString`: Transcodes the value between raw string and the target type during encoding and decoding.
* `.useDefaultOnFailure`: Uses the default value (if set) when decoding or encoding fails.

## Example

Here's a comprehensive example showcasing various features:

```swift
@Codable
struct User {
    @CodableKey("uid")
    let id: UUID
    
    let name: String
    
    var age: Int = 24

    @CodableKey(options: .useDefaultOnFailure)
    var avatar: URL? = nil

    @CodableKey(options: .transcodeRawString)
    var car: Car

    @CodableKey(options: .ignored)
    let thisPropertyWillNotBeIncluded: String

    @CodableKey("custom_email", options: .generateCustomKey)
    var email: String

    @CodableKey(options: .explicitNil)
    var optionalField: String?
}
```

In this example:
* `id` uses a custom coding key "uid".
* `age` has a default value of 24.
* `avatar` uses the default value if decoding fails.
* `car` is transcoded from a raw string to the `Car` struct.
* `thisPropertyWillNotBeIncluded` is ignored during encoding and decoding.
* `email` uses a custom key "custom_email" and generates a computed property for access.
* `optionalField` will be explicitly set to `null` when `nil`, instead of being omitted.

## Installation

```swift
.package(url: "https://github.com/WendellXY/CodableKit.git", from: "0.0.1"),
```

## Contributions

Please feel free to contribute to `CodableKit`! Any input and suggestions are always appreciated.
