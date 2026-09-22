//
//  ActiveAppTrackerTests.swift
//  SwiftKeyRemapTests
//

import Foundation
import Testing

@testable import SwiftKeyRemap

struct ActiveAppTrackerTests {

  // MARK: - Helper

  let selfId = "io.github.dominion525.cmd-eikana"

  func apps(_ ids: [String]) -> [AppData] {
    ids.map { AppData(name: "App \($0)", id: $0) }
  }

  func ids(_ list: [AppData]) -> [String] {
    list.map { $0.id }
  }

  func update(
    _ recent: [AppData], activated id: String, name: String? = nil,
    exclusion: [String: String] = [:]
  ) -> ActiveAppTracker.Update {
    ActiveAppTracker.update(
      recentApps: recent, activatedName: name ?? "App \(id)", activatedId: id,
      selfBundleId: selfId, exclusionAppsDict: exclusion)
  }

  // MARK: - 除外判定

  @Test func appInExclusionDictIsExclusion() {
    let result = update([], activated: "com.example.a", exclusion: ["com.example.a": "A"])
    #expect(result.isExclusion == true)
  }

  @Test func appNotInExclusionDictIsNotExclusion() {
    let result = update([], activated: "com.example.a", exclusion: ["com.example.b": "B"])
    #expect(result.isExclusion == false)
  }

  @Test func selfIsNotExclusion() {
    let result = update([], activated: selfId)
    #expect(result.isExclusion == false)
  }

  // MARK: - 一覧の更新

  @Test func activatedAppIsInsertedAtFront() {
    let result = update(apps(["b", "c"]), activated: "a")
    #expect(ids(result.recentApps) == ["a", "b", "c"])
  }

  @Test func insertedEntryCarriesNameAndId() {
    let result = update([], activated: "com.example.a", name: "Example A")
    #expect(result.recentApps.count == 1)
    #expect(result.recentApps[0].name == "Example A")
    #expect(result.recentApps[0].id == "com.example.a")
  }

  @Test func existingAppMovesToFrontWithoutDuplicate() {
    let result = update(apps(["a", "b", "c"]), activated: "b")
    #expect(ids(result.recentApps) == ["b", "a", "c"])
  }

  @Test func exclusionAppIsNotAddedToList() {
    let recent = apps(["a", "b"])
    let result = update(recent, activated: "x", exclusion: ["x": "X"])
    #expect(ids(result.recentApps) == ["a", "b"])
  }

  @Test func selfIsNotAddedToList() {
    let recent = apps(["a", "b"])
    let result = update(recent, activated: selfId)
    #expect(ids(result.recentApps) == ["a", "b"])
  }

  @Test func listIsCappedAtLimitByDroppingOldest() {
    let recent = apps((1...ActiveAppTracker.recentAppsLimit).map { "app\($0)" })
    let result = update(recent, activated: "new")
    #expect(result.recentApps.count == ActiveAppTracker.recentAppsLimit)
    #expect(result.recentApps.first?.id == "new")
    #expect(ids(result.recentApps).contains("app\(ActiveAppTracker.recentAppsLimit)") == false)
  }

  @Test func reactivatingWithinFullListDoesNotDropAnything() {
    let recent = apps((1...ActiveAppTracker.recentAppsLimit).map { "app\($0)" })
    let result = update(recent, activated: "app5")
    #expect(result.recentApps.count == ActiveAppTracker.recentAppsLimit)
    #expect(result.recentApps.first?.id == "app5")
    #expect(Set(ids(result.recentApps)) == Set(ids(recent)))
  }

  @Test func inputListIsNotMutated() {
    let recent = apps(["a", "b"])
    _ = update(recent, activated: "c")
    #expect(ids(recent) == ["a", "b"])
  }

  @Test func recentAppsLimitIsTen() {
    #expect(ActiveAppTracker.recentAppsLimit == 10)
  }
}
