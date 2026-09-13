//
//  PreferenceScreens.swift
//  cmd-eikanaTests
//

import Cocoa

@testable import _英かな

/// テストのホストになっているアプリが起動時に作った設定ウィンドウの各画面
@MainActor
enum PreferenceScreens {
  static var tabs: NSTabViewController {
    let delegate = NSApp.delegate as! AppDelegate
    return delegate.preferenceWindowController.contentViewController as! NSTabViewController
  }

  /// 画面のビューを読み込んでから返す（viewDidLoad まで済ませる）
  static func loaded<T: NSViewController>(_ index: Int, as type: T.Type) -> T {
    let controller = tabs.tabViewItems[index].viewController as! T
    _ = controller.view
    return controller
  }

  static var shortcuts: ShortcutsController { loaded(0, as: ShortcutsController.self) }
  static var exclusionApps: ExclusionAppsController {
    loaded(1, as: ExclusionAppsController.self)
  }
  static var setting: ViewController { loaded(2, as: ViewController.self) }
}
