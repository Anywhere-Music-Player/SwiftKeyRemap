//
//  FocusAndActivationTests.swift
//  cmd-eikanaTests
//

import Cocoa
import Testing

@testable import _英かな

/// 入力欄のフォーカスの出入りと、アプリ切り替え通知の受け口。グローバルを書き換えるので直列の親の下に置く
extension GlobalStateTests {
  @Suite struct FocusAndActivationTests {

    // MARK: - フォーカス

    @MainActor @Test func becomingFirstResponderMarksTheFieldActive() {
      let original = activeKeyTextField
      defer { activeKeyTextField = original }
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: .borderless,
        backing: .buffered, defer: false)
      let field = KeyTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
      window.contentView?.addSubview(field)

      let became = window.makeFirstResponder(field)

      #expect(became == true)
      #expect(activeKeyTextField === field)

      field.blur()
      #expect(activeKeyTextField == nil)
      #expect(window.firstResponder !== field)
    }

    @MainActor @Test func mouseDownOnShortcutsScreenBlursTheField() {
      let original = activeKeyTextField
      defer { activeKeyTextField = original }
      let field = KeyTextField(frame: .zero)
      activeKeyTextField = field

      PreferenceScreens.shortcuts.mouseDown(with: mouseEvent())

      #expect(activeKeyTextField == nil)
    }

    @MainActor @Test func mouseDownOnPreferenceWindowBlursTheField() {
      let original = activeKeyTextField
      defer { activeKeyTextField = original }
      let field = KeyTextField(frame: .zero)
      activeKeyTextField = field
      let windowController = (NSApp.delegate as! AppDelegate).preferenceWindowController!

      windowController.mouseDown(with: mouseEvent())

      #expect(activeKeyTextField == nil)
    }

    func mouseEvent() -> NSEvent {
      NSEvent.mouseEvent(
        with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
        context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    }
  }
}
