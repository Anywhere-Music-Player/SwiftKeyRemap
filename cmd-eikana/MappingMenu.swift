//
//  MappingMenu.swift
//  ⌘英かな
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Cocoa

/// キーリマップ一覧の各行に置く操作メニュー。操作の中身は ShortcutsController が KeyMappingListEditor で行う
class MappingMenu: NSPopUpButton {
  var row: Int?
}
