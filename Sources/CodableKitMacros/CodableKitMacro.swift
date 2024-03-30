import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CodableMacro: ExtensionMacro {
  private static let messageID = MessageID(domain: "CodableKit", id: "CodableMacro")

  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    // Validate that the macro is being applied to a protocol declaration
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      throw SimpleDiagnosticMessage(
        message: "Macro `CodableMacro` can only be applied to a struct",
        diagnosticID: messageID,
        severity: .error
      )
    }

    let properties = extractProperties(from: structDecl)

    guard !properties.isEmpty else { return [] }

    let inheritanceClause = InheritanceClauseSyntax {
      InheritedTypeSyntax(type: "Codable" as TypeSyntax)
    }

    let extensionDecl = ExtensionDeclSyntax(extendedType: type, inheritanceClause: inheritanceClause) {
      genCodingKeyEnumDecl(from: properties)
      genInitDecoderDecl(from: properties)
      genEncodeFuncDecl(from: properties)
    }

    return [extensionDecl]
  }
}

// MARK: - Supporting Method

extension CodableMacro {
  /// Extract all the properties from the `struct` and add type info.
  fileprivate static func extractProperties(from structDecl: StructDeclSyntax) -> [PatternBindingSyntax] {
    structDecl.memberBlock.members
      .map(\.decl)
      .compactMap { declaration in
        declaration.as(VariableDeclSyntax.self)?.bindings
      }
      .filter { syntax in
        syntax.first?.accessorBlock == nil
      }
      .flatMap { bindings in
        var patterns: [PatternBindingSyntax] = []

        guard let lastPattern = bindings.last else {
          return patterns
        }

        for binding in bindings.dropLast() {
          if binding.typeAnnotation?.type != nil {
            patterns.append(binding)
          } else {
            var copy = binding
            copy.typeAnnotation = lastPattern.typeAnnotation
            patterns.append(copy)
          }
        }

        patterns.append(lastPattern)

        return patterns
      }
  }
}

// MARK: Codable Boilerplate Code Generation
extension CodableMacro {
  fileprivate static func genCodingKeyEnumDecl(from properties: [PatternBindingSyntax]) -> EnumDeclSyntax {
    EnumDeclSyntax(
      name: "CodingKeys",
      inheritanceClause: .init(
        inheritedTypesBuilder: {
          InheritedTypeSyntax(type: "String" as TypeSyntax)
          InheritedTypeSyntax(type: "CodingKey" as TypeSyntax)
        }
      )
    ) {
      for property in properties {
        "case \(property.pattern)"
      }
    }
  }

  fileprivate static func genInitDecoderDecl(from properties: [PatternBindingSyntax]) -> InitializerDeclSyntax {
    InitializerDeclSyntax(
      signature: .init(
        parameterClause: .init(
          parametersBuilder: {
            "from decoder: Decoder"
          }
        ),
        effectSpecifiers: .init(
          throwsSpecifier: "throws"
        )
      )
    ) {
      "let container = try decoder.container(keyedBy: CodingKeys.self)"
      for property in properties {
        if let type = property.typeAnnotation?.type.trimmed {
          let key = property.pattern
          if let defaultValue = property.initializer?.value {
            "\(key) = try container.decodeIfPresent(\(type).self, forKey: .\(key)) ?? \(defaultValue)"
          } else {
            "\(key) = try container.decode(\(type).self, forKey: .\(key))"
          }
        }
      }
    }
  }

  fileprivate static func genEncodeFuncDecl(from properties: [PatternBindingSyntax]) -> FunctionDeclSyntax {
    FunctionDeclSyntax(
      name: "encode",
      signature: .init(
        parameterClause: .init(
          parametersBuilder: {
            "to encoder: Encoder"
          }
        ),
        effectSpecifiers: .init(
          throwsSpecifier: "throws"
        )
      )
    ) {
      "var container = encoder.container(keyedBy: CodingKeys.self)"
      for property in properties {
        "try container.encode(\(property.pattern), forKey: .\(property.pattern))"
      }
    }
  }
}
