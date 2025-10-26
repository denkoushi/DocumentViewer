# 2025-10-26 DocumentViewer 検討メモ

## 目的
- DocumentViewer を RaspberryPiServer と連携させるための開発タスクを整理する。

## 現状
- REST / Socket.IO の接続先を RaspberryPiServer へ統一。`VIEWER_API_BASE`（REST）、`VIEWER_SOCKET_BASE`（Socket.IO）が同一ホストを指す想定。
- `/api/v1/scans` 実行時に配信される `part_location_updated` / `scan_update` を受信し、DocumentViewer が自動で該当 PDF を開くことを確認済み。
- RaspberryPiServer で `/api/v1/scans` が稼働し、Pi Zero からの送信が成功している。

## 次のアクション
1. `VIEWER_API_BASE` / `VIEWER_API_TOKEN` を環境変数で設定できるようアプリを改修する。→ **完了**（frontend で `window.DOCVIEWER_CONFIG` を参照、API ベース・トークン対応済み）
2. DocumentViewer の右ペインで RaspberryPiServer 提供のデータを参照できるよう、Socket.IO 接続先切替と UI 調整を実施する。→ **完了**  
   - `VIEWER_SOCKET_BASE` / `VIEWER_SOCKET_PATH` / `VIEWER_SOCKET_AUTO_OPEN` / `VIEWER_ACCEPT_DEVICE_IDS` / `VIEWER_ACCEPT_LOCATION_CODES` を新設。  
   - `app/static/app.js` で `socket.io-client` を動的ロードし、`part_location_updated` / `scan_update` イベントを購読。  
   - 接続状態を画面上部に表示し、フィルタ条件を満たすイベントで `lookupDocument()` を自動実行する。
3. `docviewer.service` のログに同期完了時刻などを記録し、14 日チェックシートで参照できるようにする。
