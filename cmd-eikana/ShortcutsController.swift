//
//  ShortcutsController.swift
//  ⌘英かな
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Cocoa

var shortcutList: [CGKeyCode: [KeyMapping]] = [:]

var keyMappingList: [KeyMapping] = []

func saveKeyMappings() {
  KeyMappingListEditor.save(keyMappingList, to: UserDefaults.standard)
}

func keyMappingListToShortcutList() {
  shortcutList = KeyMappingListEditor.shortcutTable(from: keyMappingList)

  #if DEBUG
    for val in keyMappingList where val.enable {
      print("\(val.input.keyCode): \(val.input.toString()) => \(val.output.toString())")
    }
  #endif
}

class ShortcutsController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
  @IBOutlet weak var tableView: NSTableView!

  override func mouseDown(with event: NSEvent) {
    activeKeyTextField?.blur()
  }

  func numberOfRows(in tableView: NSTableView) -> Int {
    return keyMappingList.count
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
  {
    let id = tableColumn!.identifier

    if let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView {
      switch id.rawValue {
      case "input", "output":
        let value = id.rawValue == "input" ? keyMappingList[row].input : keyMappingList[row].output

        let textField = cell.subviews[0] as! KeyTextField

        textField.stringValue = value.toString()
        textField.shortcut = value
        textField.saveAddress = (row: row, id: id.rawValue)
        textField.isAllowModifierOnly = id.rawValue == "input"

      case "mapping-menu":
        let button = cell.subviews[0] as! MappingMenu

        button.row = row

        button.target = self
        button.action = #selector(ShortcutsController.remove(_:))

      case "enable":
        let button = cell.subviews[0] as! NSButton

        button.state = keyMappingList[row].enable ? .on : .off
        button.tag = row
        button.target = self
        button.action = #selector(ShortcutsController.toggleEnable(_:))

      default:
        break
      }

      return cell
    }
    return nil
  }
  @objc func toggleEnable(_ sender: NSButton) {
    keyMappingList[sender.tag].enable.toggle()
    tableReload()
  }

  @objc func remove(_ sender: MappingMenu) {
    activeKeyTextField?.blur()

    if let operation = MappingMenuOperation(rawValue: sender.selectedTag()) {
      keyMappingList = KeyMappingListEditor.apply(operation, at: sender.row!, to: keyMappingList)
    }

    tableReload()
  }

  func tableReload() {
    tableView.reloadData()
    keyMappingListToShortcutList()
    saveKeyMappings()
  }

  @IBAction func quit(_ sender: AnyObject) {
    NSApplication.shared.terminate(self)
  }

  @IBAction func addRow(_ sender: AnyObject) {
    keyMappingList = KeyMappingListEditor.adding(to: keyMappingList)
    tableReload()
  }
}
