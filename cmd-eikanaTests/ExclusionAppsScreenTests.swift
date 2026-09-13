//
//  ExclusionAppsScreenTests.swift
//  cmd-eikanaTests
//

import Cocoa
import Testing

@testable import _英かな

/// 除外アプリ画面の操作。グローバルの一覧と保存先を退避して差し替える
extension GlobalStateTests {
  @Suite struct ExclusionAppsScreenTests {

    @MainActor
    final class Fixture {
      let controller = PreferenceScreens.exclusionApps
      let defaults = RecordingDefaults(suiteName: nil)!
      private let originalExclusion = exclusionAppsList
      private let originalRecent = activeAppsList
      private let originalDict = exclusionAppsDict
      private let originalDefaults = settingsDefaults

      init(exclusion: [String], recent: [String]) {
        exclusionAppsList = exclusion.map { AppData(name: "App \($0)", id: $0) }
        activeAppsList = recent.map { AppData(name: "App \($0)", id: $0) }
        exclusionAppsDict = StartupSettings.exclusionAppsDict(exclusionAppsList)
        settingsDefaults = defaults
      }

      func restore() {
        exclusionAppsList = originalExclusion
        activeAppsList = originalRecent
        exclusionAppsDict = originalDict
        settingsDefaults = originalDefaults
      }

      func column(_ identifier: String) -> NSTableColumn {
        controller.tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(identifier))!
      }

      func value(_ identifier: String, row: Int) -> Any? {
        controller.tableView(controller.tableView, objectValueFor: column(identifier), row: row)
      }
    }

    @MainActor @Test func rowCountCoversBothLists() {
      let fixture = Fixture(exclusion: ["x"], recent: ["a", "b"])
      defer { fixture.restore() }
      #expect(fixture.controller.numberOfRows(in: fixture.controller.tableView) == 3)
    }

    @MainActor @Test func columnsShowCheckboxNameAndId() {
      let fixture = Fixture(exclusion: ["x"], recent: ["a"])
      defer { fixture.restore() }

      #expect(fixture.value("checkbox", row: 0) as? Bool == true)
      #expect(fixture.value("appName", row: 0) as? String == "App x")
      #expect(fixture.value("appId", row: 0) as? String == "x")
      #expect(fixture.value("checkbox", row: 1) as? Bool == false)
      #expect(fixture.value("appId", row: 1) as? String == "a")
    }

    @MainActor @Test func unknownColumnGivesNil() {
      let fixture = Fixture(exclusion: ["x"], recent: [])
      defer { fixture.restore() }
      let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("other"))
      #expect(
        fixture.controller.tableView(fixture.controller.tableView, objectValueFor: column, row: 0)
          == nil)
    }

    @MainActor @Test func checkingRecentAppMovesItToExclusionAndSaves() {
      let fixture = Fixture(exclusion: ["x"], recent: ["a"])
      defer { fixture.restore() }

      fixture.controller.tableView(
        fixture.controller.tableView, setObjectValue: true, for: fixture.column("checkbox"), row: 1)

      #expect(exclusionAppsList.map { $0.id } == ["x", "a"])
      #expect(activeAppsList.isEmpty)
      #expect(exclusionAppsDict["a"] == "App a")
      let saved = fixture.defaults.lastValue(forKey: "exclusionApps") as? [[AnyHashable: Any]]
      #expect(saved?.map { $0["id"] as? String } == ["x", "a"])
    }

    @MainActor @Test func uncheckingExclusionAppMovesItToFrontOfRecent() {
      let fixture = Fixture(exclusion: ["x"], recent: ["a"])
      defer { fixture.restore() }

      fixture.controller.tableView(
        fixture.controller.tableView, setObjectValue: false, for: fixture.column("checkbox"), row: 0
      )

      #expect(exclusionAppsList.isEmpty)
      #expect(activeAppsList.map { $0.id } == ["x", "a"])
      #expect(exclusionAppsDict["x"] == nil)
    }

    @MainActor @Test func settingValueOnOtherColumnChangesNothing() {
      let fixture = Fixture(exclusion: ["x"], recent: ["a"])
      defer { fixture.restore() }

      fixture.controller.tableView(
        fixture.controller.tableView, setObjectValue: "name", for: fixture.column("appName"), row: 0
      )

      #expect(exclusionAppsList.map { $0.id } == ["x"])
      #expect(fixture.defaults.recorded.isEmpty)
    }
  }
}
