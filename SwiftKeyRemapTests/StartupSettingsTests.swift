//
//  StartupSettingsTests.swift
//  SwiftKeyRemapTests
//

import CoreGraphics
import Foundation
import Testing

@testable import SwiftKeyRemap

struct StartupSettingsTests {

  // MARK: - Helper

  func shortcutDictionary(keyCode: Int, flags: Int = 0) -> [AnyHashable: Any] {
    ["keyCode": keyCode, "flags": flags]
  }

  func mappingDictionary(input: Int, output: Int, enable: Bool = true) -> [AnyHashable: Any] {
    [
      "input": shortcutDictionary(keyCode: input),
      "output": shortcutDictionary(keyCode: output),
      "enable": enable,
    ]
  }

  func pairs(_ list: [KeyMapping]) -> [[UInt16]] {
    list.map { [$0.input.keyCode, $0.output.keyCode] }
  }

  // MARK: - 除外アプリ

  @Test func exclusionAppsFromNilIsEmpty() {
    #expect(StartupSettings.exclusionApps(from: nil).isEmpty)
  }

  @Test func exclusionAppsFromNonArrayIsEmpty() {
    #expect(StartupSettings.exclusionApps(from: "foo").isEmpty)
    #expect(StartupSettings.exclusionApps(from: ["name": "A", "id": "a"]).isEmpty)
  }

  @Test func exclusionAppsRestoresNameAndIdInOrder() {
    let saved: [[AnyHashable: Any]] = [
      ["name": "A", "id": "com.example.a"],
      ["name": "B", "id": "com.example.b"],
    ]
    let list = StartupSettings.exclusionApps(from: saved)
    #expect(list.map { $0.id } == ["com.example.a", "com.example.b"])
    #expect(list.map { $0.name } == ["A", "B"])
  }

  @Test func exclusionAppsSkipsMalformedEntries() {
    let saved: [[AnyHashable: Any]] = [
      ["name": "A", "id": "com.example.a"],
      ["name": "no id"],
      ["id": 123, "name": "B"],
    ]
    let list = StartupSettings.exclusionApps(from: saved)
    #expect(list.map { $0.id } == ["com.example.a"])
  }

  @Test func exclusionAppsDictMapsIdToName() {
    let list = [AppData(name: "A", id: "com.example.a"), AppData(name: "B", id: "com.example.b")]
    let dict = StartupSettings.exclusionAppsDict(list)
    #expect(dict == ["com.example.a": "A", "com.example.b": "B"])
  }

  @Test func exclusionAppsDictLetsLaterDuplicateWin() {
    let list = [
      AppData(name: "old", id: "com.example.a"), AppData(name: "new", id: "com.example.a"),
    ]
    #expect(StartupSettings.exclusionAppsDict(list) == ["com.example.a": "new"])
  }

  // MARK: - キー設定: 保存値あり

  @Test func savedMappingsAreRestored() {
    let saved = [
      mappingDictionary(input: 55, output: 102),
      mappingDictionary(input: 54, output: 104, enable: false),
    ]
    let result = StartupSettings.mappings(saved: saved)
    #expect(result.source == .saved)
    #expect(pairs(result.list) == [[55, 102], [54, 104]])
    #expect(result.list.map { $0.enable } == [true, false])
  }

  @Test func savedEmptyArrayStaysEmptyWithoutDefaults() {
    let result = StartupSettings.mappings(saved: [[AnyHashable: Any]]())
    #expect(result.source == .saved)
    #expect(result.list.isEmpty)
  }

  @Test func savedMappingsSkipMalformedEntries() {
    let saved: [[AnyHashable: Any]] = [
      mappingDictionary(input: 55, output: 102),
      ["input": shortcutDictionary(keyCode: 54)],
      [
        "input": shortcutDictionary(keyCode: -1), "output": shortcutDictionary(keyCode: 104),
        "enable": true,
      ],
    ]
    let result = StartupSettings.mappings(saved: saved)
    #expect(pairs(result.list) == [[55, 102]])
  }

  @Test func savedValueOfWrongTypeIsTreatedAsAbsent() {
    let result = StartupSettings.mappings(saved: "foo")
    #expect(result.source == .defaults)
  }

  // MARK: - キー設定: 初期設定

  @Test func defaultsAreLeftAndRightCommandToEisuAndKana() {
    let result = StartupSettings.mappings(saved: nil)
    #expect(result.source == .defaults)
    #expect(pairs(result.list) == [[55, 102], [54, 104]])
    #expect(
      result.list.allSatisfy {
        $0.enable && $0.input.flags.rawValue == 0 && $0.output.flags.rawValue == 0
      })
  }

  @Test func defaultMappingsAreFreshInstancesEachTime() {
    let first = StartupSettings.defaultMappings
    let second = StartupSettings.defaultMappings
    #expect(first[0] !== second[0])
  }
}
