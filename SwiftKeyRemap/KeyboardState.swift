//
//  KeyboardState.swift
//  SwiftKeyRemap
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Cocoa

var shortcutList: [CGKeyCode: [KeyMapping]] = [:]

var keyMappingList: [KeyMapping] = []

/// 設定の保存先。テストでは記録するだけの UserDefaults に差し替える
var settingsDefaults = UserDefaults.standard

func saveKeyMappings() {
  KeyMappingListEditor.save(keyMappingList, to: settingsDefaults)
}

func keyMappingListToShortcutList() {
  shortcutList = KeyMappingListEditor.shortcutTable(from: keyMappingList)

  #if DEBUG
    for val in keyMappingList where val.enable {
      print("\(val.input.keyCode): \(val.input.toString()) => \(val.output.toString())")
    }
  #endif
}
