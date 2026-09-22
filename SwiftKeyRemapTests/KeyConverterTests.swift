//
//  KeyConverterTests.swift
//  SwiftKeyRemapTests
//

import CoreGraphics
import Foundation
import Testing

@testable import SwiftKeyRemap

struct KeyConverterTests {

  // MARK: - Helper

  static let command = CGEventFlags.maskCommand.rawValue
  static let shift = CGEventFlags.maskShift.rawValue
  static let control = CGEventFlags.maskControl.rawValue

  func createShortcut(keyCode: UInt16, flags: UInt64 = 0) -> KeyboardShortcut {
    KeyboardShortcut(keyCode: CGKeyCode(keyCode), flags: CGEventFlags(rawValue: flags))
  }

  func createMapping(
    input: (keyCode: UInt16, flags: UInt64), output: (keyCode: UInt16, flags: UInt64)
  ) -> KeyMapping {
    KeyMapping(
      input: createShortcut(keyCode: input.keyCode, flags: input.flags),
      output: createShortcut(keyCode: output.keyCode, flags: output.flags))
  }

  /// 設定表を作る。keyMappingListToShortcutList と同じく、入力キーコードで引ける辞書にする
  func createTable(_ mappings: [KeyMapping]) -> [CGKeyCode: [KeyMapping]] {
    KeyMappingListEditor.shortcutTable(from: mappings)
  }

  func resolve(_ shortcut: KeyboardShortcut, in table: [CGKeyCode: [KeyMapping]])
    -> KeyConversion
  {
    KeyConverter.resolve(shortcut: shortcut, lookupKeyCode: shortcut.keyCode, in: table)
  }

  // MARK: - resolve: 一致の有無

  @Test func emptyTablePassesThrough() {
    #expect(resolve(createShortcut(keyCode: 55), in: [:]) == .passThrough)
  }

  @Test func differentKeyCodePassesThrough() {
    let table = createTable([createMapping(input: (55, 0), output: (102, 0))])
    #expect(resolve(createShortcut(keyCode: 0), in: table) == .passThrough)
  }

  @Test func matchingKeyCodeConverts() {
    let table = createTable([createMapping(input: (55, 0), output: (102, 0))])
    let result = resolve(createShortcut(keyCode: 55), in: table)
    #expect(result == .convert(keyCode: 102, flags: CGEventFlags(rawValue: 0)))
  }

  @Test func disableOutputGivesDisable() {
    let table = createTable([createMapping(input: (102, 0), output: (999, 0))])
    #expect(resolve(createShortcut(keyCode: 102), in: table) == .disable)
  }

  // MARK: - resolve: 修飾フラグの扱い

  @Test func extraModifierIsKept() {
    let table = createTable([createMapping(input: (55, 0), output: (102, 0))])
    let result = resolve(createShortcut(keyCode: 55, flags: Self.shift), in: table)
    #expect(result == .convert(keyCode: 102, flags: CGEventFlags(rawValue: Self.shift)))
  }

  @Test func inputModifierIsRemovedAndOutputModifierIsAdded() {
    let table = createTable([createMapping(input: (49, Self.command), output: (49, Self.control))])
    let result = resolve(createShortcut(keyCode: 49, flags: Self.command), in: table)
    #expect(result == .convert(keyCode: 49, flags: CGEventFlags(rawValue: Self.control)))
  }

  @Test func unrelatedModifierSurvivesConversion() {
    let table = createTable([createMapping(input: (49, Self.command), output: (49, Self.control))])
    let result = resolve(createShortcut(keyCode: 49, flags: Self.command | Self.shift), in: table)
    #expect(
      result == .convert(keyCode: 49, flags: CGEventFlags(rawValue: Self.control | Self.shift)))
  }

  @Test func missingRequiredModifierPassesThrough() {
    let table = createTable([createMapping(input: (49, Self.command), output: (49, Self.control))])
    #expect(resolve(createShortcut(keyCode: 49), in: table) == .passThrough)
  }

  @Test func wrongModifierPassesThrough() {
    let table = createTable([createMapping(input: (49, Self.command), output: (49, Self.control))])
    #expect(resolve(createShortcut(keyCode: 49, flags: Self.shift), in: table) == .passThrough)
  }

  /// 修飾キー自身の flagsChanged では、そのキーのビットが立っていても isCover の対象外として扱われる
  @Test func modifierKeyItselfMatchesUnmodifiedMapping() {
    let table = createTable([createMapping(input: (55, 0), output: (102, 0))])
    let result = resolve(createShortcut(keyCode: 55, flags: Self.command), in: table)
    #expect(result == .convert(keyCode: 102, flags: CGEventFlags(rawValue: Self.command)))
  }

  /// 照合は論理的な修飾ビットだけで行い、flags の計算は生のビットで行う（現状の挙動を固定）
  @Test func nonModifierBitsAreComparedOnlyInFlagArithmetic() {
    let table = createTable([createMapping(input: (0, 0x100108), output: (102, 0))])
    let result = resolve(createShortcut(keyCode: 0, flags: 0x100110), in: table)
    #expect(result == .convert(keyCode: 102, flags: CGEventFlags(rawValue: 0x10)))
  }

  // MARK: - resolve: 同じキーに複数の設定

  @Test func firstMatchingMappingWins() {
    let table = createTable([
      createMapping(input: (55, 0), output: (102, 0)),
      createMapping(input: (55, Self.shift), output: (104, 0)),
    ])
    let result = resolve(createShortcut(keyCode: 55, flags: Self.shift), in: table)
    #expect(result == .convert(keyCode: 102, flags: CGEventFlags(rawValue: Self.shift)))
  }

  @Test func orderOfMappingsChangesResult() {
    let table = createTable([
      createMapping(input: (55, Self.shift), output: (104, 0)),
      createMapping(input: (55, 0), output: (102, 0)),
    ])
    let result = resolve(createShortcut(keyCode: 55, flags: Self.shift), in: table)
    #expect(result == .convert(keyCode: 104, flags: CGEventFlags(rawValue: 0)))
  }

  @Test func laterMappingIsUsedWhenFirstDoesNotMatch() {
    let table = createTable([
      createMapping(input: (49, Self.command), output: (0, 0)),
      createMapping(input: (49, 0), output: (1, 0)),
    ])
    let result = resolve(createShortcut(keyCode: 49, flags: Self.shift), in: table)
    #expect(result == .convert(keyCode: 1, flags: CGEventFlags(rawValue: Self.shift)))
  }

  // MARK: - resolve: メディアキー

  @Test func mediaKeyIsLookedUpByOffsetKeyCode() {
    let mediaKeyCode = UInt16(mediaKeyCodeOffset + Int(NX_KEYTYPE_SOUND_UP))
    let table = createTable([createMapping(input: (mediaKeyCode, 0), output: (102, 0))])
    let result = KeyConverter.resolve(
      shortcut: createShortcut(keyCode: 0), lookupKeyCode: CGKeyCode(mediaKeyCode), in: table)
    #expect(result == .convert(keyCode: 102, flags: CGEventFlags(rawValue: 0)))
  }

  @Test func mediaKeyWithoutRequiredModifierPassesThrough() {
    let mediaKeyCode = UInt16(mediaKeyCodeOffset + Int(NX_KEYTYPE_SOUND_UP))
    let table = createTable([
      createMapping(input: (mediaKeyCode, Self.command), output: (102, 0))
    ])
    let result = KeyConverter.resolve(
      shortcut: createShortcut(keyCode: 0), lookupKeyCode: CGKeyCode(mediaKeyCode), in: table)
    #expect(result == .passThrough)
  }

  // MARK: - resolve: 直前の一致に影響されない（修飾キー単体押しの不具合の回帰）

  @Test func resolveIsIndependentOfPreviousCall() {
    let table = createTable([
      createMapping(input: (102, 0), output: (999, 0)),
      createMapping(input: (55, 0), output: (102, 0)),
    ])
    #expect(resolve(createShortcut(keyCode: 102), in: table) == .disable)
    #expect(
      resolve(createShortcut(keyCode: 55), in: table)
        == .convert(keyCode: 102, flags: CGEventFlags(rawValue: 0)))
  }

  // MARK: - mediaKeyMappingKeyCode

  @Test func mediaKeyTypeZeroMapsToOffset() {
    #expect(KeyConverter.mediaKeyMappingKeyCode(keyType: 0) == CGKeyCode(mediaKeyCodeOffset))
  }

  @Test func largestFittingMediaKeyTypeMapsToMaximumKeyCode() {
    #expect(KeyConverter.mediaKeyMappingKeyCode(keyType: 65535 - mediaKeyCodeOffset) == 65535)
  }

  @Test func mediaKeyTypeBeyondRangeGivesNil() {
    #expect(KeyConverter.mediaKeyMappingKeyCode(keyType: 65536 - mediaKeyCodeOffset) == nil)
  }

  @Test func negativeMediaKeyTypeBelowOffsetGivesNil() {
    #expect(KeyConverter.mediaKeyMappingKeyCode(keyType: -mediaKeyCodeOffset - 1) == nil)
  }

  // MARK: - modifierKeyState

  @Test func leftCommandWithCommandFlagIsDown() {
    #expect(
      KeyConverter.modifierKeyState(keyCode: 55, flags: CGEventFlags(rawValue: Self.command))
        == true)
  }

  @Test func leftCommandWithoutCommandFlagIsUp() {
    #expect(KeyConverter.modifierKeyState(keyCode: 55, flags: CGEventFlags(rawValue: 0)) == false)
  }

  @Test func shiftKeyWithOnlyCommandFlagIsUp() {
    #expect(
      KeyConverter.modifierKeyState(keyCode: 56, flags: CGEventFlags(rawValue: Self.command))
        == false)
  }

  @Test func capsLockWithAlphaShiftFlagIsDown() {
    #expect(KeyConverter.modifierKeyState(keyCode: 57, flags: .maskAlphaShift) == true)
  }

  @Test func fnKeyWithSecondaryFnFlagIsDown() {
    #expect(KeyConverter.modifierKeyState(keyCode: 63, flags: .maskSecondaryFn) == true)
  }

  @Test func nonModifierKeyGivesNil() {
    #expect(
      KeyConverter.modifierKeyState(keyCode: 0, flags: CGEventFlags(rawValue: Self.command)) == nil)
  }

  // MARK: - ModifierTapTracker

  @Test func downThenUpOfSameKeyIsTap() {
    var tracker = ModifierTapTracker()
    tracker.modifierDown(55)
    #expect(tracker.modifierUp(55) == true)
  }

  @Test func cancelBetweenDownAndUpIsNotTap() {
    var tracker = ModifierTapTracker()
    tracker.modifierDown(55)
    tracker.cancel()
    #expect(tracker.modifierUp(55) == false)
  }

  /// 修飾キーを重ねて押したとき、追跡されるのは最後に押したキーだけ（現状の挙動を固定）
  @Test func lastPressedModifierIsTheTap() {
    var tracker = ModifierTapTracker()
    tracker.modifierDown(55)
    tracker.modifierDown(56)
    #expect(tracker.modifierUp(56) == true)
  }

  @Test func earlierPressedModifierIsNotTapAfterAnotherModifier() {
    var tracker = ModifierTapTracker()
    tracker.modifierDown(55)
    tracker.modifierDown(56)
    _ = tracker.modifierUp(56)
    #expect(tracker.modifierUp(55) == false)
  }

  @Test func upWithoutDownIsNotTap() {
    var tracker = ModifierTapTracker()
    #expect(tracker.modifierUp(55) == false)
  }

  @Test func upOfDifferentKeyResetsTracking() {
    var tracker = ModifierTapTracker()
    tracker.modifierDown(55)
    #expect(tracker.modifierUp(54) == false)
    #expect(tracker.modifierUp(55) == false)
  }

  @Test func secondUpIsNotTap() {
    var tracker = ModifierTapTracker()
    tracker.modifierDown(55)
    #expect(tracker.modifierUp(55) == true)
    #expect(tracker.modifierUp(55) == false)
  }
}
