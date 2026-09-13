//
//  ViewController.swift
//  ⌘英かな
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Cocoa
import Sparkle

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
  /// 設定の保存先。テストでは記録するだけの UserDefaults に差し替える
  var userDefaults = UserDefaults.standard
  /// メニューバー項目の表示を切り替える。AppKit がその状態をアプリの設定に保存するので、テストでは記録するだけの関数に差し替える
  var setStatusItemVisible: (Bool) -> Void = { statusItem.isVisible = $0 }

  @IBOutlet weak var showIcon: NSButton!
  @IBOutlet weak var lunchAtStartup: NSButton!
  @IBOutlet weak var checkUpdateAtlaunch: NSButton!

  // Sparkle の updater は AppDelegate が保持している
  private var updater: SPUUpdater {
    (NSApp.delegate as! AppDelegate).updaterController.updater
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.

    let showIconState = userDefaults.object(forKey: "showIcon") as? Int ?? 1
    showIcon.state = NSControl.StateValue(rawValue: showIconState)

    lunchAtStartup.state = NSControl.StateValue(
      rawValue: userDefaults.integer(forKey: "lunchAtStartup"))

    checkUpdateAtlaunch.state = updater.automaticallyChecksForUpdates ? .on : .off
  }

  @IBAction func clickShowIcon(_ sender: AnyObject) {
    setStatusItemVisible(showIcon.state == NSControl.StateValue.on)
    userDefaults.set(showIcon.state, forKey: "showIcon")
  }
  @IBAction func clickLunchAtStartup(_ sender: AnyObject) {
    setLaunchAtStartup(lunchAtStartup.state == NSControl.StateValue.on)
    userDefaults.set(lunchAtStartup.state, forKey: "lunchAtStartup")
  }
  @IBAction func clickCheckUpdateAtlaunch(_ sender: AnyObject) {
    updater.automaticallyChecksForUpdates = (checkUpdateAtlaunch.state == .on)
  }
  // 結果（最新である・失敗した・更新がある）の表示は Sparkle の標準 UI が行う
  @IBAction func checkUpdateButton(_ sender: AnyObject) {
    updater.checkForUpdates()
  }
}
