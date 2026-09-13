//
//  GlobalStateTests.swift
//  cmd-eikanaTests
//

import Testing

/// グローバル状態（キー設定の一覧、除外アプリの一覧、設定の保存先、フォーカス中の入力欄）を
/// 書き換えて戻すスイートの親。Swift Testing はスイート同士を並列に走らせるので、
/// 同じグローバルを触るスイートはこの下に置いて直列にする
@Suite(.serialized)
enum GlobalStateTests {}
