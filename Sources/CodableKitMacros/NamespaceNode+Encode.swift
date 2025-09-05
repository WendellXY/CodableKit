//
//  NamespaceNode+Encode.swift
//  CodableKit
//
//  Extracted encode generation from NamespaceNode
//

import SwiftSyntax
import SwiftSyntaxBuilder

extension NamespaceNode {
  var encodeContainersAssignment: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []
    if parent == nil {
      result.append(CodeBlockItemSyntax(item: .decl(CodeGenCore.genEncodeContainerDecl())))
      if hasTranscodeRawStringInSubtree {
        result.append(
          CodeBlockItemSyntax(item: .decl(CodeGenCore.genJSONEncoderVariableDecl(variableName: "__ckEncoder"))))
      }
    }
    for child in children.values.sorted(by: { $0.segment < $1.segment }) {
      result.append(
        CodeBlockItemSyntax(
          item: .decl(
            CodeGenCore.genNestedEncodeContainerDecl(
              container: child.containerName,
              parentContainer: containerName,
              keyedBy: child.enumName,
              forKey: child.segment
            )
          )
        )
      )
    }
    return result
  }
}

extension NamespaceNode {
  private var propertyEncodeAssignment: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []

    result.append(
      contentsOf: properties.filter(\.isNormal).map { property in
        CodeBlockItemSyntax(
          item: .expr(
            CodeGenCore.genContainerEncodeExpr(
              containerName: containerName,
              key: property.name,
              patternName: property.name,
              isOptional: property.isOptional,
              explicitNil: property.options.contains(.explicitNil)
            )
          )
        )
      })

    // Encode lossy properties normally (lossy is decode-only). Skip when also using transcodeRawString.
    for property in properties
    where property.options.contains(.lossy)
      && !property.options.contains(.transcodeRawString) && !property.ignored
    {
      result.append(
        CodeBlockItemSyntax(
          item: .expr(
            CodeGenCore.genContainerEncodeExpr(
              containerName: containerName,
              key: property.name,
              patternName: property.name,
              isOptional: property.isOptional,
              explicitNil: property.options.contains(.explicitNil)
            )
          )
        )
      )
    }

    // Encode as raw JSON string (transcoding). For optionals without `.explicitNil`, omit the key when nil.
    for property in properties where property.options.contains(.transcodeRawString) && !property.ignored {
      if property.isOptional && !property.options.contains(.explicitNil) {
        // if let <name>Unwrapped = <name> { ... encode ... }
        let unwrappedName = PatternSyntax(IdentifierPatternSyntax(identifier: .identifier("\(property.name)Unwrapped")))
        result.append(
          CodeBlockItemSyntax(
            item: .expr(
              ExprSyntax(
                IfExprSyntax(
                  conditions: [
                    ConditionElementSyntax(
                      condition: .optionalBinding(
                        OptionalBindingConditionSyntax(
                          bindingSpecifier: .keyword(.let),
                          pattern: unwrappedName,
                          initializer: InitializerClauseSyntax(
                            value: DeclReferenceExprSyntax(baseName: .identifier("\(property.name)"))
                          )
                        )
                      )
                    )
                  ],
                  body: CodeBlockSyntax {
                    CodeBlockItemSyntax(
                      item: .decl(
                        CodeGenCore.genJSONEncoderEncodeDecl(
                          variableName: property.rawDataName,
                          instance: unwrappedName,
                          encoderVarName: hasTranscodeRawStringInSubtree ? "__ckEncoder" : nil
                        )
                      )
                    )
                    CodeBlockItemSyntax(
                      item: .expr(
                        CodeGenCore.genEncodeRawDataHandleExpr(
                          key: property.name,
                          rawDataName: property.rawDataName,
                          rawStringName: property.rawStringName,
                          containerName: containerName,
                          codingPath: codingKeyChain(for: property),
                          message: "Failed to transcode raw data to string",
                          isOptional: false,
                          explicitNil: false
                        )
                      )
                    )
                  }
                )
              )
            )
          )
        )
      } else {
        // Non-optional or `.explicitNil` option: encode current value, allowing explicit nil as string
        result.append(contentsOf: [
          CodeBlockItemSyntax(
            item: .decl(
              CodeGenCore.genJSONEncoderEncodeDecl(
                variableName: property.rawDataName,
                instance: property.name,
                encoderVarName: hasTranscodeRawStringInSubtree ? "__ckEncoder" : nil
              )
            )
          ),
          CodeBlockItemSyntax(
            item: .expr(
              CodeGenCore.genEncodeRawDataHandleExpr(
                key: property.name,
                rawDataName: property.rawDataName,
                rawStringName: property.rawStringName,
                containerName: containerName,
                codingPath: codingKeyChain(for: property),
                message: "Failed to transcode raw data to string",
                isOptional: property.isOptional,
                explicitNil: property.options.contains(.explicitNil)
              )
            )
          ),
        ])
      }
    }

    return result
  }

  var encodeBlockItem: [CodeBlockItemSyntax] {
    var result: [CodeBlockItemSyntax] = []

    result.append(contentsOf: encodeContainersAssignment)
    result.append(contentsOf: propertyEncodeAssignment)
    for child in children.values.sorted(by: { $0.segment < $1.segment }) {
      result.append(contentsOf: child.encodeBlockItem)
    }

    return result
  }
}
