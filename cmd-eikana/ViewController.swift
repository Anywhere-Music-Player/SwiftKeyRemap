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
  let userDefaults = UserDefaults.standard

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

  override var representedObject: Any? {
    didSet {
      // Update the view, if already loaded.
    }
  }

  @IBAction func clickShowIcon(_ sender: AnyObject) {
    statusItem.isVisible = (showIcon.state == NSControl.StateValue.on)
    userDefaults.set(showIcon.state, forKey: "showIcon")
  }
  @IBAction func clickLunchAtStartup(_ sender: AnyObject) {
    setLaunchAtStartup(lunchAtStartup.state == NSControl.StateValue.on)
    userDefaults.set(lunchAtStartup.state, forKey: "lunchAtStartup")
  }
  @IBAction func clickCheckUpdateAtlaunch(_ sender: AnyObject) {
    updater.automaticallyChecksForUpdates = (checkUpdateAtlaunch.state == .on)
  }
  @IBAction func test(_ sender: Any) {

  }

  // 結果（最新である・失敗した・更新がある）の表示は Sparkle の標準 UI が行う
  @IBAction func checkUpdateButton(_ sender: AnyObject) {
    updater.checkForUpdates()
  }
}
