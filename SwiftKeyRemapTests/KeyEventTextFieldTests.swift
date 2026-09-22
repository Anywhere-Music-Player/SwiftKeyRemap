//
//  KeyEventTextFieldTests.swift
//  SwiftKeyRemapTests
//

import Cocoa
import Testing

@testable import SwiftKeyRemap

/// 設定画面の入力欄にフォーカスがある間のキーイベントの扱い。activeKeyTextField を書き換えるので直列の親の下に置く
extension GlobalStateTests {
  @Suite struct KeyEventTextFieldTests {

    let events = KeyEventTests()

    /// 入力欄をフォーカス中にして、テスト後に元へ戻す
    @MainActor
    final class FocusedField {
      let field = KeyTextField(frame: .zero)
      private let original = activeKeyTextField

      init(allowModifierOnly: Bool) {
        field.isAllowModifierOnly = allowModifierOnly
        activeKeyTextField = field
      }

      func restore() {
        activeKeyTextField = original
      }
    }

    @MainActor @Test func keyDownWhileEditingIsRecordedAndSwallowed() {
      let focused = FocusedField(allowModifierOnly: true)
      defer { focused.restore() }
      let harness = KeyEventTests.Harness(mappings: [events.mapping(input: 0, output: 11)])

      let result = harness.handle(.keyDown, events.keyEvent(0, down: true, flags: .maskCommand))

      #expect(result == nil)
      #expect(focused.field.shortcut?.keyCode == 0)
      #expect(focused.field.shortcut?.flags.contains(.maskCommand) == true)
      #expect(focused.field.stringValue == "⌘A")
    }

    @MainActor @Test func modifierDownWhileEditingInputColumnIsRecorded() {
      let focused = FocusedField(allowModifierOnly: true)
      defer { focused.restore() }
      let harness = KeyEventTests.Harness(mappings: [])
      let event = events.flagsChanged(55, flags: .maskCommand)

      let result = harness.handle(.flagsChanged, event)

      #expect(result === event)
      #expect(focused.field.shortcut?.keyCode == 55)
      #expect(focused.field.stringValue == "Command_L")
    }

    @MainActor @Test func modifierDownWhileEditingOutputColumnIsNotRecorded() {
      let focused = FocusedField(allowModifierOnly: false)
      defer { focused.restore() }
      let harness = KeyEventTests.Harness(mappings: [])

      _ = harness.handle(.flagsChanged, events.flagsChanged(55, flags: .maskCommand))

      #expect(focused.field.shortcut == nil)
      #expect(focused.field.stringValue == "")
    }

    @MainActor @Test func modifierTapWhileEditingPostsNothing() {
      let focused = FocusedField(allowModifierOnly: true)
      defer { focused.restore() }
      let harness = KeyEventTests.Harness(mappings: [events.mapping(input: 55, output: 102)])

      _ = harness.handle(.flagsChanged, events.flagsChanged(55, flags: .maskCommand))
      _ = harness.handle(.flagsChanged, events.flagsChanged(55, flags: []))

      #expect(harness.postedShortcuts.isEmpty)
    }

    @MainActor @Test func mediaKeyWhileEditingInputColumnIsRecordedAndSwallowed() {
      let focused = FocusedField(allowModifierOnly: true)
      defer { focused.restore() }
      let harness = KeyEventTests.Harness(mappings: [])

      let result = harness.handle(
        .null, events.mediaKeyEvent(keyType: NX_KEYTYPE_SOUND_UP, down: true))

      #expect(result == nil)
      #expect(
        focused.field.shortcut?.keyCode == CGKeyCode(mediaKeyCodeOffset + Int(NX_KEYTYPE_SOUND_UP)))
      #expect(focused.field.stringValue == "Sound_up")
      #expect(harness.postedKeyDowns.isEmpty)
    }

    @MainActor @Test func mediaKeyWhileEditingOutputColumnPassesThrough() {
      let focused = FocusedField(allowModifierOnly: false)
      defer { focused.restore() }
      let harness = KeyEventTests.Harness(mappings: [])
      let event = events.mediaKeyEvent(keyType: NX_KEYTYPE_SOUND_UP, down: true)

      let result = harness.handle(.null, event)

      #expect(result === event)
      #expect(focused.field.shortcut == nil)
    }
  }
}
