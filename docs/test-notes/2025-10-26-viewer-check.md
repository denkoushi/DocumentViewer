# 2025-10-26 DocumentViewer 検討メモ

## 目的
- DocumentViewer を RaspberryPiServer と連携させるための開発タスクを整理する。

## 現状
- Socket.IO / REST の接続先は旧サーバー (Window A) を前提としている。
- RaspberryPiServer で `/api/v1/scans` が稼働し、Pi Zero からの送信が成功している。

## 次のアクション
1. `VIEWER_API_BASE` / `VIEWER_API_TOKEN` を環境変数で設定できるようアプリを改修する。
2. DocumentViewer の右ペインで RaspberryPiServer 提供のデータを参照できるよう、Socket.IO 接続先切替と UI 調整を実施する。
3. `docviewer.service` のログに同期完了時刻などを記録し、14 日チェックシートで参照できるようにする。
