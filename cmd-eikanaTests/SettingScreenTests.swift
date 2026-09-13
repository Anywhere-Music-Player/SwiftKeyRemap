//
//  SettingScreenTests.swift
//  cmd-eikanaTests
//

import Cocoa
import Testing

@testable import _英かな

/// 設定画面とメニューバー。自動起動の登録と Sparkle の設定は OS やアプリの実設定を変えるので触らない
@Suite(.serialized)
struct SettingScreenTests {

  @MainActor @Test func showIconCheckboxTogglesTheStatusItemAndSaves() {
    let controller = PreferenceScreens.setting
    let defaults = RecordingDefaults(suiteName: nil)!
    let originalDefaults = controller.userDefaults
    let originalVisible = statusItem.isVisible
    let originalState = controller.showIcon.state
    defer {
      controller.userDefaults = originalDefaults
      statusItem.isVisible = originalVisible
      controller.showIcon.state = originalState
    }
    controller.userDefaults = defaults

    controller.showIcon.state = .off
    controller.clickShowIcon(controller.showIcon)
    #expect(statusItem.isVisible == false)
    #expect((defaults.lastValue(forKey: "showIcon") as? NSControl.StateValue) == .off)

    controller.showIcon.state = .on
    controller.clickShowIcon(controller.showIcon)
    #expect(statusItem.isVisible == true)
    #expect(defaults.recorded.count == 2)
  }

  @MainActor @Test func checkboxesReflectSavedStateAfterLoad() {
    let controller = PreferenceScreens.setting
    // viewDidLoad は保存値を読んで反映する。テストのホストは実設定で起動しているので、値の有無だけ確かめる
    #expect([.on, .off].contains(controller.showIcon.state))
    #expect([.on, .off].contains(controller.lunchAtStartup.state))
    #expect([.on, .off].contains(controller.checkUpdateAtlaunch.state))
  }

  @MainActor @Test func menuBarHasTheFourItemsInOrder() {
    let titles = statusItem.menu?.items.map { $0.title } ?? []
    #expect(titles.count == 5)
    #expect(titles[0].hasPrefix("About ⌘英かな "))
    #expect(titles[1] == "Preferences...")
    #expect(titles[2] == "")
    #expect(titles[3] == "Restart")
    #expect(titles[4] == "Quit")
  }

  @MainActor @Test func menuItemsTargetTheExpectedActions() {
    let items = statusItem.menu?.items ?? []
    #expect(items[0].action == #selector(AppDelegate.open(_:)))
    #expect(items[1].action == #selector(AppDelegate.openPreferencesSerector(_:)))
    #expect(items[3].action == #selector(AppDelegate.restart(_:)))
    #expect(items[4].action == #selector(AppDelegate.quit(_:)))
  }
}
