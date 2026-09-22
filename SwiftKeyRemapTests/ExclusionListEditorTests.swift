//
//  ExclusionListEditorTests.swift
//  SwiftKeyRemapTests
//

import Foundation
import Testing

@testable import SwiftKeyRemap

struct ExclusionListEditorTests {

  // MARK: - Helper

  func apps(_ ids: [String]) -> [AppData] {
    ids.map { AppData(name: "App \($0)", id: $0) }
  }

  func ids(_ list: [AppData]) -> [String] {
    list.map { $0.id }
  }

  // MARK: - rowCount

  @Test func rowCountIsSumOfBothLists() {
    #expect(ExclusionListEditor.rowCount(exclusion: apps(["x", "y"]), recent: apps(["a"])) == 3)
    #expect(ExclusionListEditor.rowCount(exclusion: [], recent: []) == 0)
  }

  // MARK: - row

  @Test func rowsInExclusionRangeComeFromExclusionList() {
    let exclusion = apps(["x", "y"])
    let entry = ExclusionListEditor.row(1, exclusion: exclusion, recent: apps(["a"]))
    #expect(entry?.isExclusion == true)
    #expect(entry?.app === exclusion[1])
  }

  @Test func rowsAfterExclusionRangeComeFromRecentList() {
    let recent = apps(["a", "b"])
    let entry = ExclusionListEditor.row(3, exclusion: apps(["x", "y"]), recent: recent)
    #expect(entry?.isExclusion == false)
    #expect(entry?.app === recent[1])
  }

  @Test func rowsWithEmptyExclusionListStartFromRecent() {
    let recent = apps(["a"])
    let entry = ExclusionListEditor.row(0, exclusion: [], recent: recent)
    #expect(entry?.isExclusion == false)
    #expect(entry?.app === recent[0])
  }

  @Test(arguments: [-1, 3, 100])
  func rowOutOfRangeIsNil(row: Int) {
    #expect(ExclusionListEditor.row(row, exclusion: apps(["x"]), recent: apps(["a", "b"])) == nil)
  }

  // MARK: - toggled

  @Test func togglingExclusionRowMovesItToFrontOfRecent() {
    let result = ExclusionListEditor.toggled(
      row: 0, exclusion: apps(["x", "y"]), recent: apps(["a", "b"]))
    #expect(ids(result.exclusion) == ["y"])
    #expect(ids(result.recent) == ["x", "a", "b"])
  }

  @Test func togglingRecentRowAppendsItToExclusion() {
    let result = ExclusionListEditor.toggled(
      row: 3, exclusion: apps(["x", "y"]), recent: apps(["a", "b"]))
    #expect(ids(result.exclusion) == ["x", "y", "b"])
    #expect(ids(result.recent) == ["a"])
  }

  @Test func toggledKeepsTheSameInstance() {
    let recent = apps(["a"])
    let result = ExclusionListEditor.toggled(row: 0, exclusion: [], recent: recent)
    #expect(result.exclusion.first === recent[0])
  }

  @Test func togglingBackRestoresMembershipButNotOrder() {
    let once = ExclusionListEditor.toggled(
      row: 2, exclusion: apps(["x", "y"]), recent: apps(["a"]))
    let twice = ExclusionListEditor.toggled(row: 2, exclusion: once.exclusion, recent: once.recent)
    #expect(ids(twice.exclusion) == ["x", "y"])
    #expect(ids(twice.recent) == ["a"])
  }

  @Test(arguments: [-1, 3])
  func togglingOutOfRangeRowChangesNothing(row: Int) {
    let exclusion = apps(["x"])
    let recent = apps(["a", "b"])
    let result = ExclusionListEditor.toggled(row: row, exclusion: exclusion, recent: recent)
    #expect(ids(result.exclusion) == ["x"])
    #expect(ids(result.recent) == ["a", "b"])
  }

  @Test func toggledDoesNotMutateInputs() {
    let exclusion = apps(["x"])
    let recent = apps(["a"])
    _ = ExclusionListEditor.toggled(row: 0, exclusion: exclusion, recent: recent)
    #expect(ids(exclusion) == ["x"])
    #expect(ids(recent) == ["a"])
  }

  // MARK: - serialized

  @Test func serializedMatchesToDictionary() {
    let list = [AppData(name: "A", id: "com.example.a"), AppData(name: "B", id: "com.example.b")]
    let result = ExclusionListEditor.serialized(list)
    #expect(result.count == 2)
    #expect(result[0]["name"] as? String == "A")
    #expect(result[0]["id"] as? String == "com.example.a")
    #expect(result[1]["id"] as? String == "com.example.b")
  }

  @Test func serializedRoundTripsThroughStartupSettings() {
    let list = [AppData(name: "A", id: "com.example.a")]
    let restored = StartupSettings.exclusionApps(from: ExclusionListEditor.serialized(list))
    #expect(ids(restored) == ["com.example.a"])
    #expect(restored.first?.name == "A")
  }

  @Test func serializedEmptyListIsEmptyArray() {
    #expect(ExclusionListEditor.serialized([]).isEmpty)
  }
}
