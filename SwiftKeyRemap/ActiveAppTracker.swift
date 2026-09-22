//
//  ActiveAppTracker.swift
//  SwiftKeyRemap
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Foundation

/// 最前面アプリの切り替えに伴う、除外状態と「最近使ったアプリ」一覧の更新。NSWorkspace やグローバル状態には依存しない
enum ActiveAppTracker {
  /// 「最近使ったアプリ」一覧に残す件数
  static let recentAppsLimit = 10

  /// 最前面になったアプリを一覧に反映した結果
  struct Update: Equatable {
    /// そのアプリが除外アプリか
    let isExclusion: Bool
    /// 更新後の「最近使ったアプリ」一覧
    let recentApps: [AppData]
  }

  /// name / id のアプリが最前面になったときの除外状態と一覧を返す。
  /// 自分自身と除外アプリは一覧に入れない。既に一覧にあるアプリは先頭へ移し、件数は recentAppsLimit に収める
  static func update(
    recentApps: [AppData], activatedName name: String, activatedId id: String,
    selfBundleId: String, exclusionAppsDict: [String: String]
  ) -> Update {
    let isExclusion = exclusionAppsDict[id] != nil

    guard id != selfBundleId && !isExclusion else {
      return Update(isExclusion: isExclusion, recentApps: recentApps)
    }

    var result = recentApps.filter { $0.id != id }
    result.insert(AppData(name: name, id: id), at: 0)

    if result.count > recentAppsLimit {
      result.removeLast()
    }

    return Update(isExclusion: isExclusion, recentApps: result)
  }
}
