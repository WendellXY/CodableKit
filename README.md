# CodableKit ⚡️

CodableKit is a Swift macro package designed to simplify the use of Swift's `Codable` protocol by allowing easy
integration of default values, reducing the amount of auxiliary code you need to write.

## How It Works

> This project is still under development, so the documentation is not complete, you may refer to the source code for
> more details or peek the example below.

Just add the `@Codable` attribute to your structure. The macro automatically generates code to handle decoding and
encoding in compliance with the Codable protocol, recognizing and neatly handling default values:

```swift
@Codable
struct User {
  @CodableKey("uid") // Change the coding key to `uid`
  let id: UUID
  let name: String
  var age: Int = 24

  @CodableKey(ignored: true) // Ignore this property
  let thisPropertyWillNotBeIncluded: String
}
```

It gets transformed into:

```swift
struct User {
  let id: UUID
  let name: String
  var age: Int = 24

  let thisPropertyWillNotBeIncluded: String
}

extension User: Codable {
  enum CodingKeys: String, CodingKey {
    case id = "uid"
    case name
    case age
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    age = try container.decodeIfPresent(Int.self, forKey: .age) ?? 24
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encode(age, forKey: .age)
  }
}
```

This lets you keep your models clean while the `@Codable` attribute generates the necessary Codable compliance code
with incorporated default values in the background. Enjoy more streamlined Swift `Codable` handling with `CodableKit`.

## Installation

> This project is still under development, so the `main` branch is used here.

```swift
.package(url: "https://github.com/WendellXY/CodableKit.git", branch: "main"),
```

## Contributions

Please feel free to contribute to `CodableKit`! Any input and suggestions are always appreciated.
