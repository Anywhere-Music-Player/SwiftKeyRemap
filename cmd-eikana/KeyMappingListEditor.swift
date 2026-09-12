//
//  KeyMappingListEditor.swift
//  ⌘英かな
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import CoreGraphics
import Foundation

/// キーリマップ一覧のメニューから選べる操作
enum MappingMenuOperation {
  case remove
  case moveToTop
  case moveUp
  case moveDown
  case moveToBottom

  /// メニュー項目の表示文字列（英語と日本語）から操作を決める。該当しなければ nil
  init?(menuTitle: String) {
    switch menuTitle {
    case "この項目を削除", "remove":
      self = .remove
    case "最上部に移動", "move to the top":
      self = .moveToTop
    case "1つ上に移動", "move one up":
      self = .moveUp
    case "1つ下に移動", "move one down":
      self = .moveDown
    case "最下部に移動", "move to bottom":
      self = .moveToBottom
    default:
      return nil
    }
  }
}

/// キーリマップ一覧に対する操作を、グローバル状態や UI に触らない関数として提供する。
/// KeyMapping はクラスなので、返す配列の要素は元の配列と同じインスタンスを指す。
enum KeyMappingListEditor {
  /// メニュー操作を row 行に適用した配列を返す。移動先は配列の範囲内に収める
  static func apply(_ operation: MappingMenuOperation, at row: Int, to list: [KeyMapping])
    -> [KeyMapping]
  {
    switch operation {
    case .remove:
      var result = list
      result.remove(at: row)
      return result
    case .moveToTop:
      return moved(list, from: row, to: 0)
    case .moveUp:
      return moved(list, from: row, to: row - 1)
    case .moveDown:
      return moved(list, from: row, to: row + 1)
    case .moveToBottom:
      return moved(list, from: row, to: list.count - 1)
    }
  }

  /// 末尾に既定値の項目を足した配列を返す
  static func adding(to list: [KeyMapping]) -> [KeyMapping] {
    return list + [KeyMapping()]
  }

  /// 有効な項目だけを入力キーコードで引ける表にする。同じキーコードの項目は一覧の順序を保つ
  static func shortcutTable(from list: [KeyMapping]) -> [CGKeyCode: [KeyMapping]] {
    var table: [CGKeyCode: [KeyMapping]] = [:]

    for mapping in list where mapping.enable {
      table[mapping.input.keyCode, default: []].append(mapping)
    }

    return table
  }

  /// UserDefaults に保存する形式に変換する
  static func serialized(_ list: [KeyMapping]) -> [[AnyHashable: Any]] {
    return list.map { $0.toDictionary() }
  }

  /// 一覧を UserDefaults の "mappings" キーに保存する
  static func save(_ list: [KeyMapping], to defaults: UserDefaults) {
    defaults.set(serialized(list), forKey: "mappings")
  }

  /// row 行の項目を取り出して targetIndex に入れ直す。targetIndex は 0 から count-1 の範囲に収める
  private static func moved(_ list: [KeyMapping], from row: Int, to targetIndex: Int)
    -> [KeyMapping]
  {
    var index = targetIndex
    if index < 0 {
      index = 0
    } else if index > list.count - 1 {
      index = list.count - 1
    }

    var result = list
    let mapping = result[row]
    result.remove(at: row)
    result.insert(mapping, at: index)

    return result
  }
}
