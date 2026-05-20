//
//  Drop+Link.swift
//  crane
//
//  Link normalization and validation for capture + row rendering.
//

import Foundation

extension Drop {

  /// Returns display/save text for link mode: trims whitespace and
  /// prepends `https://` when the user omitted a scheme.
  static func normalizedLinkText(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return trimmed }
    if let url = URL(string: trimmed), url.scheme != nil {
      return trimmed
    }
    return "https://\(trimmed)"
  }

  /// Whether `normalizedLinkText` yields a usable http(s) URL with a host.
  static func isValidLinkText(_ raw: String) -> Bool {
    let normalized = normalizedLinkText(raw)
    guard let url = URL(string: normalized),
      let scheme = url.scheme?.lowercased(),
      scheme == "http" || scheme == "https",
      let host = url.host,
      !host.isEmpty
    else {
      return false
    }
    return true
  }

  /// URL suitable for `Link` in `DropRow`, using the same rules as save.
  /// Normalizes legacy rows saved before link validation shipped.
  static func linkURL(for text: String) -> URL? {
    let normalized = normalizedLinkText(text)
    guard isValidLinkText(text) else { return nil }
    return URL(string: normalized)
  }
}
