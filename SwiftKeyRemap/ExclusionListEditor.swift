//
//  ExclusionListEditor.swift
//  SwiftKeyRemap
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Foundation

/// 除外アプリ画面の一覧操作。除外一覧と「最近使ったアプリ」一覧を、除外を先頭に並べた 1 つの表として扱う。
/// グローバル状態や UI には依存しない
enum ExclusionListEditor {
  /// 表の 1 行が指す項目
  struct Row {
    let app: AppData
    /// 除外一覧側の項目か（false なら「最近使ったアプリ」側）
    let isExclusion: Bool
  }

  /// 表の行数
  static func rowCount(exclusion: [AppData], recent: [AppData]) -> Int {
    return exclusion.count + recent.count
  }

  /// row 行の項目。範囲外なら nil
  static func row(_ row: Int, exclusion: [AppData], recent: [AppData]) -> Row? {
    if row < 0 {
      return nil
    }
    if row < exclusion.count {
      return Row(app: exclusion[row], isExclusion: true)
    }
    let recentIndex = row - exclusion.count
    if recentIndex < recent.count {
      return Row(app: recent[recentIndex], isExclusion: false)
    }
    return nil
  }

  /// row 行のチェックを切り替えた後の 2 つの一覧。除外から外した項目は「最近使ったアプリ」の先頭に、
  /// 除外に入れた項目は除外一覧の末尾に置く。範囲外なら変えない
  static func toggled(row: Int, exclusion: [AppData], recent: [AppData])
    -> (exclusion: [AppData], recent: [AppData])
  {
    guard let entry = self.row(row, exclusion: exclusion, recent: recent) else {
      return (exclusion, recent)
    }

    var exclusion = exclusion
    var recent = recent

    if entry.isExclusion {
      exclusion.remove(at: row)
      recent.insert(entry.app, at: 0)
    } else {
      recent.remove(at: row - exclusion.count)
      exclusion.append(entry.app)
    }

    return (exclusion, recent)
  }

  /// 保存形式（UserDefaults の "exclusionApps"）
  static func serialized(_ list: [AppData]) -> [[AnyHashable: Any]] {
    return list.map { $0.toDictionary() }
  }
}
