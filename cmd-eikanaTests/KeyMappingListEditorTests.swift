//
//  KeyMappingListEditorTests.swift
//  cmd-eikanaTests
//

import CoreGraphics
import Foundation
import Testing

@testable import _英かな

struct KeyMappingListEditorTests {

  // MARK: - Helper

  func createShortcut(keyCode: UInt16 = 0, flags: UInt64 = 0) -> KeyboardShortcut {
    KeyboardShortcut(keyCode: CGKeyCode(keyCode), flags: CGEventFlags(rawValue: flags))
  }

  func createMapping(inputKeyCode: UInt16, outputKeyCode: UInt16, enable: Bool = true)
    -> KeyMapping
  {
    KeyMapping(
      input: createShortcut(keyCode: inputKeyCode),
      output: createShortcut(keyCode: outputKeyCode),
      enable: enable
    )
  }

  /// 見分けやすいよう入力キーコードを 1, 2, 3, ... にした項目を count 個作る
  func createMappings(count: Int) -> [KeyMapping] {
    (1...count).map { createMapping(inputKeyCode: UInt16($0), outputKeyCode: 100) }
  }

  /// 2 つの配列が同じ順序で同じインスタンスを指しているか
  func sameInstances(_ lhs: [KeyMapping], _ rhs: [KeyMapping]) -> Bool {
    lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0 === $1 }
  }

  // MARK: - MappingMenuOperation

  @Test(arguments: [
    ("remove", MappingMenuOperation.remove),
    ("この項目を削除", MappingMenuOperation.remove),
    ("move to the top", MappingMenuOperation.moveToTop),
    ("最上部に移動", MappingMenuOperation.moveToTop),
    ("move one up", MappingMenuOperation.moveUp),
    ("1つ上に移動", MappingMenuOperation.moveUp),
    ("move one down", MappingMenuOperation.moveDown),
    ("1つ下に移動", MappingMenuOperation.moveDown),
    ("move to bottom", MappingMenuOperation.moveToBottom),
    ("最下部に移動", MappingMenuOperation.moveToBottom),
  ])
  func menuTitleResolvesToOperation(title: String, expected: MappingMenuOperation) {
    #expect(MappingMenuOperation(menuTitle: title) == expected)
  }

  @Test(arguments: ["…", "", "foo", "Remove", "削除"])
  func unknownMenuTitleResolvesToNil(title: String) {
    #expect(MappingMenuOperation(menuTitle: title) == nil)
  }

  // MARK: - apply: remove

  @Test func removeMiddleRow() {
    let list = createMappings(count: 3)
    let result = KeyMappingListEditor.apply(.remove, at: 1, to: list)
    #expect(sameInstances(result, [list[0], list[2]]))
  }

  @Test func removeFirstRow() {
    let list = createMappings(count: 3)
    let result = KeyMappingListEditor.apply(.remove, at: 0, to: list)
    #expect(sameInstances(result, [list[1], list[2]]))
  }

  @Test func removeLastRow() {
    let list = createMappings(count: 3)
    let result = KeyMappingListEditor.apply(.remove, at: 2, to: list)
    #expect(sameInstances(result, [list[0], list[1]]))
  }

  @Test func removeOnlyRowGivesEmptyList() {
    let list = createMappings(count: 1)
    let result = KeyMappingListEditor.apply(.remove, at: 0, to: list)
    #expect(result.isEmpty)
  }

  @Test func removeDoesNotMutateOriginalList() {
    let list = createMappings(count: 3)
    let snapshot = list
    _ = KeyMappingListEditor.apply(.remove, at: 1, to: list)
    #expect(sameInstances(list, snapshot))
  }

  // MARK: - apply: move

  @Test func moveDownSwapsWithNextRow() {
    let list = createMappings(count: 4)
    let result = KeyMappingListEditor.apply(.moveDown, at: 1, to: list)
    #expect(sameInstances(result, [list[0], list[2], list[1], list[3]]))
  }

  @Test func moveUpSwapsWithPreviousRow() {
    let list = createMappings(count: 4)
    let result = KeyMappingListEditor.apply(.moveUp, at: 2, to: list)
    #expect(sameInstances(result, [list[0], list[2], list[1], list[3]]))
  }

  @Test func moveUpAtTopKeepsOrder() {
    let list = createMappings(count: 4)
    let result = KeyMappingListEditor.apply(.moveUp, at: 0, to: list)
    #expect(sameInstances(result, list))
  }

  @Test func moveDownAtBottomKeepsOrder() {
    let list = createMappings(count: 4)
    let result = KeyMappingListEditor.apply(.moveDown, at: 3, to: list)
    #expect(sameInstances(result, list))
  }

  @Test func moveToBottomMovesRowToEnd() {
    let list = createMappings(count: 4)
    let result = KeyMappingListEditor.apply(.moveToBottom, at: 1, to: list)
    #expect(sameInstances(result, [list[0], list[2], list[3], list[1]]))
  }

  @Test func moveToTopMovesRowToStart() {
    let list = createMappings(count: 4)
    let result = KeyMappingListEditor.apply(.moveToTop, at: 2, to: list)
    #expect(sameInstances(result, [list[2], list[0], list[1], list[3]]))
  }

  @Test(arguments: [
    MappingMenuOperation.moveToTop, .moveUp, .moveDown, .moveToBottom,
  ])
  func moveOnSingleRowKeepsList(operation: MappingMenuOperation) {
    let list = createMappings(count: 1)
    let result = KeyMappingListEditor.apply(operation, at: 0, to: list)
    #expect(sameInstances(result, list))
  }

  @Test(arguments: [
    MappingMenuOperation.moveToTop, .moveUp, .moveDown, .moveToBottom,
  ])
  func movePreservesCountAndInstances(operation: MappingMenuOperation) {
    let list = createMappings(count: 5)
    let result = KeyMappingListEditor.apply(operation, at: 2, to: list)
    #expect(result.count == list.count)
    for mapping in list {
      #expect(result.contains { $0 === mapping })
    }
  }

  // MARK: - adding

  @Test func addingToEmptyListAppendsDefaultMapping() {
    let result = KeyMappingListEditor.adding(to: [])
    #expect(result.count == 1)
    #expect(result[0].input.keyCode == 0)
    #expect(result[0].output.keyCode == 0)
    #expect(result[0].enable == true)
  }

  @Test func addingKeepsExistingInstancesInOrder() {
    let list = createMappings(count: 2)
    let result = KeyMappingListEditor.adding(to: list)
    #expect(result.count == 3)
    #expect(sameInstances(Array(result.prefix(2)), list))
  }

  // MARK: - shortcutTable

  @Test func shortcutTableContainsOnlyEnabledMappings() {
    let enabled = createMapping(inputKeyCode: 55, outputKeyCode: 102, enable: true)
    let disabled = createMapping(inputKeyCode: 54, outputKeyCode: 104, enable: false)
    let table = KeyMappingListEditor.shortcutTable(from: [enabled, disabled])
    #expect(table.count == 1)
    #expect(table[55]?.first === enabled)
    #expect(table[54] == nil)
  }

  @Test func shortcutTableFromEmptyListIsEmpty() {
    #expect(KeyMappingListEditor.shortcutTable(from: []).isEmpty)
  }

  @Test func shortcutTableKeepsListOrderForSameKeyCode() {
    let first = createMapping(inputKeyCode: 55, outputKeyCode: 102)
    let second = createMapping(inputKeyCode: 55, outputKeyCode: 104)
    let table = KeyMappingListEditor.shortcutTable(from: [first, second])
    #expect(table[55]?.count == 2)
    #expect(table[55]?[0] === first)
    #expect(table[55]?[1] === second)
  }

  @Test func shortcutTableReflectsMoveUp() {
    let first = createMapping(inputKeyCode: 55, outputKeyCode: 102)
    let second = createMapping(inputKeyCode: 55, outputKeyCode: 104)
    let moved = KeyMappingListEditor.apply(.moveUp, at: 1, to: [first, second])
    let table = KeyMappingListEditor.shortcutTable(from: moved)
    #expect(table[55]?[0] === second)
    #expect(table[55]?[1] === first)
  }

  // MARK: - serialized / save

  @Test func serializedMatchesToDictionary() {
    let list = [
      createMapping(inputKeyCode: 55, outputKeyCode: 102),
      createMapping(inputKeyCode: 54, outputKeyCode: 104, enable: false),
    ]
    let result = KeyMappingListEditor.serialized(list)
    #expect(result.count == 2)
    for (dictionary, mapping) in zip(result, list) {
      #expect(dictionary["input"] is [AnyHashable: Any])
      #expect(KeyMapping(dictionary: dictionary)?.input.keyCode == mapping.input.keyCode)
      #expect(KeyMapping(dictionary: dictionary)?.output.keyCode == mapping.output.keyCode)
      #expect(KeyMapping(dictionary: dictionary)?.enable == mapping.enable)
    }
  }

  @Test func serializedEmptyListIsEmptyArray() {
    #expect(KeyMappingListEditor.serialized([]).isEmpty)
  }

  /// 保存形式から KeyMapping(dictionary:) で復元でき、値が往復すること。
  /// save は serialized の結果を UserDefaults に渡すだけなので、書き込み自体はテストしない
  @Test func serializedRoundTripsThroughDictionaryInit() {
    let list = [
      KeyMapping(
        input: createShortcut(keyCode: 55, flags: 0x100000),
        output: createShortcut(keyCode: 102),
        enable: true),
      createMapping(inputKeyCode: 54, outputKeyCode: 104, enable: false),
    ]

    let restored = KeyMappingListEditor.serialized(list).compactMap { KeyMapping(dictionary: $0) }

    #expect(restored.count == 2)
    #expect(restored[0].input.keyCode == 55)
    #expect(restored[0].input.flags.rawValue == 0x100000)
    #expect(restored[0].output.keyCode == 102)
    #expect(restored[0].enable == true)
    #expect(restored[1].input.keyCode == 54)
    #expect(restored[1].output.keyCode == 104)
    #expect(restored[1].enable == false)
  }
}
