//
//  ShortcutTextResolverTests.swift
//  cmd-eikanaTests
//

import CoreGraphics
import Foundation
import Testing

@testable import _英かな

struct ShortcutTextResolverTests {

  // MARK: - Helper

  func createShortcut(keyCode: UInt16 = 0, flags: UInt64 = 0) -> KeyboardShortcut {
    KeyboardShortcut(keyCode: CGKeyCode(keyCode), flags: CGEventFlags(rawValue: flags))
  }

  func createMapping(inputKeyCode: UInt16, outputKeyCode: UInt16) -> KeyMapping {
    KeyMapping(
      input: createShortcut(keyCode: inputKeyCode),
      output: createShortcut(keyCode: outputKeyCode)
    )
  }

  /// システム設定の読み取りが常に失敗する（設定が無い）状況
  let noHotKeys: (Int) -> [Int]? = { _ in nil }

  /// システム設定の読み取りが id によらず同じ parameters を返す状況
  func hotKeys(_ parameters: [Int]) -> (Int) -> [Int]? {
    { _ in parameters }
  }

  // MARK: - resolve: 固定の項目

  @Test func eisuResolvesToEisuKey() {
    let result = ShortcutTextResolver.resolve(
      text: "英数", current: nil, symbolicHotKeyParameters: noHotKeys)
    #expect(result?.keyCode == 102)
    #expect(result?.flags.rawValue == 0)
  }

  @Test func kanaResolvesToKanaKey() {
    let result = ShortcutTextResolver.resolve(
      text: "かな", current: nil, symbolicHotKeyParameters: noHotKeys)
    #expect(result?.keyCode == 104)
    #expect(result?.flags.rawValue == 0)
  }

  @Test func shiftKanaResolvesToKanaKeyWithShift() {
    let result = ShortcutTextResolver.resolve(
      text: "⇧かな", current: nil, symbolicHotKeyParameters: noHotKeys)
    #expect(result?.keyCode == 104)
    #expect(result?.flags == CGEventFlags.maskShift)
  }

  @Test func disableResolvesToDisableKeyCode() {
    let result = ShortcutTextResolver.resolve(
      text: "Disable", current: nil, symbolicHotKeyParameters: noHotKeys)
    #expect(result?.keyCode == 999)
    #expect(result?.flags.rawValue == 0)
  }

  @Test func fixedItemsReplaceCurrentValue() {
    let current = createShortcut(keyCode: 49, flags: 0x100000)
    let result = ShortcutTextResolver.resolve(
      text: "英数", current: current, symbolicHotKeyParameters: noHotKeys)
    #expect(result?.keyCode == 102)
    #expect(result !== current)
  }

  // MARK: - resolve: システム設定の入力ソース切り替え

  @Test(arguments: [
    "select the previous input source", "前の入力ソースを選択",
    "select next source in input menu", "入力メニューの次のソースを選択",
  ])
  func inputSourceItemsUseSystemHotKey(text: String) {
    let result = ShortcutTextResolver.resolve(
      text: text, current: nil, symbolicHotKeyParameters: hotKeys([65535, 49, 262144]))
    #expect(result?.keyCode == 49)
    #expect(result?.flags.rawValue == 262144)
  }

  @Test func previousInputSourceLooksUpId60() {
    var requestedId: Int?
    _ = ShortcutTextResolver.resolve(
      text: "select the previous input source", current: nil,
      symbolicHotKeyParameters: { id in
        requestedId = id
        return nil
      })
    #expect(requestedId == 60)
  }

  @Test func nextInputSourceLooksUpId61() {
    var requestedId: Int?
    _ = ShortcutTextResolver.resolve(
      text: "select next source in input menu", current: nil,
      symbolicHotKeyParameters: { id in
        requestedId = id
        return nil
      })
    #expect(requestedId == 61)
  }

  @Test func inputSourceItemKeepsCurrentWhenSettingIsMissing() {
    let current = createShortcut(keyCode: 49, flags: 0x100000)
    let result = ShortcutTextResolver.resolve(
      text: "select the previous input source", current: current,
      symbolicHotKeyParameters: noHotKeys)
    #expect(result === current)
  }

  @Test func inputSourceItemKeepsCurrentWhenParametersAreTooShort() {
    let current = createShortcut(keyCode: 49, flags: 0x100000)
    let result = ShortcutTextResolver.resolve(
      text: "select the previous input source", current: current,
      symbolicHotKeyParameters: hotKeys([65535, 49]))
    #expect(result === current)
  }

  @Test func inputSourceItemGivesNilWhenSettingIsMissingAndNoCurrent() {
    let result = ShortcutTextResolver.resolve(
      text: "select the previous input source", current: nil, symbolicHotKeyParameters: noHotKeys)
    #expect(result == nil)
  }

  // MARK: - resolve: 該当しない文字列

  @Test(arguments: ["foo", "", "disable", " 英数", "英数 ", "eisu"])
  func unknownTextKeepsCurrent(text: String) {
    let current = createShortcut(keyCode: 49, flags: 0x100000)
    let result = ShortcutTextResolver.resolve(
      text: text, current: current, symbolicHotKeyParameters: noHotKeys)
    #expect(result === current)
  }

  @Test func unknownTextWithNoCurrentGivesNil() {
    let result = ShortcutTextResolver.resolve(
      text: "foo", current: nil, symbolicHotKeyParameters: noHotKeys)
    #expect(result == nil)
  }

  // MARK: - shortcut(fromSymbolicHotKeyParameters:)

  @Test func parametersWithThreeElementsBecomeShortcut() {
    let result = ShortcutTextResolver.shortcut(fromSymbolicHotKeyParameters: [65535, 49, 262144])
    #expect(result?.keyCode == 49)
    #expect(result?.flags.rawValue == 262144)
  }

  @Test func extraParametersAreIgnored() {
    let result = ShortcutTextResolver.shortcut(fromSymbolicHotKeyParameters: [65535, 49, 262144, 0])
    #expect(result?.keyCode == 49)
    #expect(result?.flags.rawValue == 262144)
  }

  @Test(arguments: [[Int](), [65535], [65535, 49]])
  func tooFewParametersGiveNil(parameters: [Int]) {
    #expect(ShortcutTextResolver.shortcut(fromSymbolicHotKeyParameters: parameters) == nil)
  }

  // MARK: - apply

  @Test func applyToInputColumnReplacesInputOnly() {
    var list = [createMapping(inputKeyCode: 55, outputKeyCode: 102)]
    let originalOutput = list[0].output
    let shortcut = createShortcut(keyCode: 54)

    ShortcutTextResolver.apply(shortcut, to: &list, row: 0, columnId: "input")

    #expect(list[0].input === shortcut)
    #expect(list[0].output === originalOutput)
  }

  @Test func applyToOutputColumnReplacesOutputOnly() {
    var list = [createMapping(inputKeyCode: 55, outputKeyCode: 102)]
    let originalInput = list[0].input
    let shortcut = createShortcut(keyCode: 104)

    ShortcutTextResolver.apply(shortcut, to: &list, row: 0, columnId: "output")

    #expect(list[0].output === shortcut)
    #expect(list[0].input === originalInput)
  }

  @Test func applyWithOtherColumnIdReplacesOutput() {
    var list = [createMapping(inputKeyCode: 55, outputKeyCode: 102)]
    let shortcut = createShortcut(keyCode: 104)

    ShortcutTextResolver.apply(shortcut, to: &list, row: 0, columnId: "other")

    #expect(list[0].output === shortcut)
  }

  @Test func applyTouchesOnlyTheGivenRow() {
    var list = [
      createMapping(inputKeyCode: 1, outputKeyCode: 11),
      createMapping(inputKeyCode: 2, outputKeyCode: 12),
      createMapping(inputKeyCode: 3, outputKeyCode: 13),
    ]
    let untouchedFirst = (list[0].input, list[0].output)
    let untouchedLast = (list[2].input, list[2].output)
    let shortcut = createShortcut(keyCode: 99)

    ShortcutTextResolver.apply(shortcut, to: &list, row: 1, columnId: "input")

    #expect(list[1].input === shortcut)
    #expect(list[0].input === untouchedFirst.0 && list[0].output === untouchedFirst.1)
    #expect(list[2].input === untouchedLast.0 && list[2].output === untouchedLast.1)
  }

  @Test func applyToLastRow() {
    var list = [
      createMapping(inputKeyCode: 1, outputKeyCode: 11),
      createMapping(inputKeyCode: 2, outputKeyCode: 12),
    ]
    let shortcut = createShortcut(keyCode: 99)

    ShortcutTextResolver.apply(shortcut, to: &list, row: list.count - 1, columnId: "output")

    #expect(list[1].output === shortcut)
  }
}
