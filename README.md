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
- Coding lifecycle hooks

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

- **Custom Coding Keys**: Change the coding key for a property.

```swift
@CodableKey("uid")
let id: UUID
```

- **CodableKeyOptions**: Customize the behavior of properties using various options.

```swift
@CodableKey(options: [.useDefaultOnFailure, .transcodeRawString])
var someProperty: SomeType
```

> You can find the details in the [CodableKeyOptions.swift](Sources/CodableKitShared/CodableKeyOptions.swift) file.

- **Lifecycle Hooks**: Run specific code during the decoding and encoding stages.

```swift
@Codable
struct User {
    var id: String = ""
    var name: String
    var age: Int
    var gender: Gender

    mutating func didDecode(from decoder: any Decoder) throws {
        id = name + "\(age)"
    }
}
```

## Example

Here's a comprehensive example showcasing various features:

```swift
@Codable
struct User {
    @Codable
    struct Car {
        let brand: String
        let model: String
        let year: Int
    }

    @CodableKey("uid")
    let id: UUID

    let name: String

    var age: Int = 24

    @CodableKey(options: .useDefaultOnFailure)
    var avatar: URL? = nil

    @CodableKey(options: .transcodeRawString)
    var car: Car

    @CodableKey(options: .ignored)
    let thisPropertyWillNotBeIncluded: String = "ignored"

    @CodableKey("custom_email", options: .generateCustomKey)
    var email: String

    @CodableKey(options: .explicitNil)
    var optionalField: String?
}
```

In this example:

- `id` uses a custom coding key "uid".

- `age` has a default value of 24.

- `avatar` uses the default value if decoding fails.

- `car` is transcoded from a raw string to the `Car` struct.

- `thisPropertyWillNotBeIncluded` is ignored during encoding and decoding.

- `email` uses a custom key "custom_email" and generates a computed property for access.

- `optionalField` will be explicitly set to `null` when `nil`, instead of being omitted.

## Installation

```swift
.package(url: "https://github.com/WendellXY/CodableKit.git", from: "1.0.0"),
```

For those who still use Swift 5 or have dependencies that require Swift 5 or swift-syntax 510.0.0,
you can use the previous 0.x version of CodableKit, which is compatible with Swift 5 and should
cover most of features in the latest version. Be aware that the 0.x version will not be developed
anymore, and it is recommended to upgrade to the latest version.

```swift
.package(url: "https://github.com/WendellXY/CodableKit.git", from: "0.4.0"),
```

## Limitation

When applying this macro to a base class, in the class definition header, you should not add any inheritance to the
class. Otherwise, this class will be considered as a class with a superclass, because the macro cannot identify whether
the inheritance is a class or a protocol during macro expansion.

```swift
// Codable will consider the BaseUser as a base class since it does not have any inheritance
@Codable
class BaseUser { }

// Codable will consider the HashableUser as a subclass even if the inheritance just contains a protocol
@Codable
class HashableUser: Hashable { }

// So you have to write the HashableUser like:
@Codable
class HashableUser { }
extension HashableUser: Hashable { }
```

## Contributions

Please feel free to contribute to `CodableKit`! Any input and suggestions are always appreciated.
