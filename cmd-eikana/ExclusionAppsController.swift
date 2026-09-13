//
//  ExclusionAppsController.swift
//  ⌘英かな
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Cocoa

class ExclusionAppsController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
  @IBOutlet weak var tableView: NSTableView!

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(ExclusionAppsController.tableReload),
      name: NSApplication.didBecomeActiveNotification,
      object: nil)
  }

  func numberOfRows(in tableView: NSTableView) -> Int {
    return ExclusionListEditor.rowCount(exclusion: exclusionAppsList, recent: activeAppsList)
  }

  func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int)
    -> Any?
  {
    guard
      let entry = ExclusionListEditor.row(row, exclusion: exclusionAppsList, recent: activeAppsList)
    else {
      return nil
    }

    switch tableColumn!.identifier.rawValue {
    case "checkbox":
      return entry.isExclusion
    case "appName":
      return entry.app.name
    case "appId":
      return entry.app.id
    default:
      return nil
    }
  }

  func tableView(
    _ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int
  ) {
    if tableColumn!.identifier != NSUserInterfaceItemIdentifier(rawValue: "checkbox") {
      return
    }

    let lists = ExclusionListEditor.toggled(
      row: row, exclusion: exclusionAppsList, recent: activeAppsList)
    exclusionAppsList = lists.exclusion
    activeAppsList = lists.recent
    exclusionAppsDict = StartupSettings.exclusionAppsDict(exclusionAppsList)

    tableReload()
    saveExclusionApps()
  }

  @objc func tableReload() {
    tableView.reloadData()
  }

  func saveExclusionApps() {
    UserDefaults.standard.set(
      ExclusionListEditor.serialized(exclusionAppsList), forKey: "exclusionApps")
  }
}
