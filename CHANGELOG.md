# DocumentViewer CHANGELOG

本プロジェクトで適用済みの主要な変更を時系列で記録します。開発中の計画や未実装事項は `docs/requirements.md` や `docs/test-notes/` を参照してください。

## 2025-10-26

- DocumentViewer Flask アプリに `VIEWER_LOCAL_DOCS_DIR` を追加し、PDF 保存先を環境変数で切り替え可能にした。
- `VIEWER_LOG_PATH` を新設し、ドキュメント検索/配信/拒否イベントをローテーション付きファイルへ記録。
- `tests/test_viewer_app.py` を追加し、環境変数適用・API 応答・ログ出力を含む 5 ケースの `pytest` を整備。
- `README.md` を更新し、主要な環境変数一覧と `pytest` 実行手順を追記。
- `docs/test-notes/2025-10-26-viewer-check.md` にログ対応状況を反映。
