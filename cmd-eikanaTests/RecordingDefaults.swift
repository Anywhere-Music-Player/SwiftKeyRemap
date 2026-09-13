//
//  RecordingDefaults.swift
//  cmd-eikanaTests
//

import Foundation

/// set(_:forKey:) を記録するだけで、ファイルには何も書かない UserDefaults
final class RecordingDefaults: UserDefaults {
  var recorded: [(key: String, value: Any?)] = []

  override func set(_ value: Any?, forKey defaultName: String) {
    recorded.append((defaultName, value))
  }

  /// key に最後に書かれた値
  func lastValue(forKey key: String) -> Any? {
    recorded.last { $0.key == key }?.value
  }
}
