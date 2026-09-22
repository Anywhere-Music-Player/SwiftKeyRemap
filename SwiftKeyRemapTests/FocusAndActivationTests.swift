//
//  FocusAndActivationTests.swift
//  SwiftKeyRemapTests
//

import Cocoa
import Testing

@testable import SwiftKeyRemap

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

    func mouseEvent() -> NSEvent {
      NSEvent.mouseEvent(
        with: .leftMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
        context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    // MARK: - アプリ切り替え通知

    /// グローバルの一覧と除外辞書を退避し、テスト後に戻す
    final class Lists {
      private let originalRecent = activeAppsList
      private let originalDict = exclusionAppsDict

      init(exclusion: [String: String]) {
        activeAppsList = []
        exclusionAppsDict = exclusion
      }

      func restore() {
        activeAppsList = originalRecent
        exclusionAppsDict = originalDict
      }
    }

    /// 自分以外で bundle ID を持つ動作中のアプリ（Finder など）
    var otherApp: NSRunningApplication? {
      NSWorkspace.shared.runningApplications.first {
        $0.bundleIdentifier != nil && $0.bundleIdentifier != Bundle.main.bundleIdentifier
          && $0.localizedName != nil
      }
    }

    func notification(for app: NSRunningApplication) -> NSNotification {
      NSNotification(
        name: NSWorkspace.didActivateApplicationNotification, object: nil,
        userInfo: [NSWorkspace.applicationUserInfoKey: app])
    }

    @Test func activationNotificationAddsTheAppToRecentList() throws {
      let app = try #require(otherApp)
      let lists = Lists(exclusion: [:])
      defer { lists.restore() }
      let keyEvent = KeyEvent()

      keyEvent.setActiveApp(notification(for: app))

      #expect(keyEvent.isExclusionApp == false)
      #expect(activeAppsList.first?.id == app.bundleIdentifier)
    }

    @Test func activationNotificationOfExclusionAppSetsTheFlag() throws {
      let app = try #require(otherApp)
      let lists = Lists(exclusion: [app.bundleIdentifier!: app.localizedName!])
      defer { lists.restore() }
      let keyEvent = KeyEvent()

      keyEvent.setActiveApp(notification(for: app))

      #expect(keyEvent.isExclusionApp == true)
      #expect(activeAppsList.isEmpty)
    }
  }
}
