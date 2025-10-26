# 2025-10-26 DocumentViewer 検討メモ

## 目的
- DocumentViewer を RaspberryPiServer と連携させるための開発タスクを整理する。

## 現状
- Socket.IO / REST の接続先は旧サーバー (Window A) を前提としている。
- RaspberryPiServer で `/api/v1/scans` が稼働し、Pi Zero からの送信が成功している。

## 次のアクション
1. `VIEWER_API_BASE` / `VIEWER_API_TOKEN` を環境変数で設定できるようアプリを改修する。→ **完了**（frontend で `window.DOCVIEWER_CONFIG` を参照、API ベース・トークン対応済み）
2. DocumentViewer の右ペインで RaspberryPiServer 提供のデータを参照できるよう、Socket.IO 接続先切替と UI 調整を実施する。（設計方針は `docs/documentviewer-migration.md` を参照）
3. `docviewer.service` のログに同期完了時刻などを記録し、14 日チェックシートで参照できるようにする。
