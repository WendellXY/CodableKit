//
//  Diagnostic.swift
//  CodableKit
//
//  Created by Wendell on 3/30/24.
//

import SwiftDiagnostics
import SwiftSyntax

struct SimpleDiagnosticMessage: DiagnosticMessage, Error {
  static let diagnosticID = MessageID(domain: "CodableKit", id: "CodableMacro")
  let message: String
  let diagnosticID: MessageID = Self.diagnosticID
  let severity: DiagnosticSeverity
}

extension SimpleDiagnosticMessage: FixItMessage {
  var fixItID: MessageID { diagnosticID }
}

enum CustomError: Error, CustomStringConvertible {
  case message(String)

  var description: String {
    switch self {
    case .message(let text):
      return text
    }
  }
}
