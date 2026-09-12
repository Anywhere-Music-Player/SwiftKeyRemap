//
//  MappingMenu.swift
//  ⌘英かな
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Cocoa

class MappingMenu: NSPopUpButton {
  var row: Int?

  func move(_ targetIndex: Int) {
    var index = targetIndex
    if let row = self.row {
      let keyMapping = keyMappingList[row]

      if index < 0 {
        index = 0
      } else if index > keyMappingList.count - 1 {
        index = keyMappingList.count - 1
      }

      keyMappingList.remove(at: row)
      keyMappingList.insert(keyMapping, at: index)
    }
  }

  func remove() {
    keyMappingList.remove(at: self.row!)
  }
}
