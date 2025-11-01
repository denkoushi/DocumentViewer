# DocumentViewer 要件（2025-10-31 更新）

## 1. 背景
- DocumentViewer は RaspberryPiServer（Pi5）上の Flask アプリとして `/viewer` を提供し、Window A (tool-management-system02) の右ペインから iframe で利用する。
- Pi Zero（OnSiteLogistics）から送信された所在イベントは RaspberryPiServer で集約され、Socket.IO で DocumentViewer と Window A の UI に同時通知される。
- 本リポジトリは DocumentViewer のソースコード・systemd サービス・インポートスクリプトを提供し、Pi5 側の運用を担う。

## 2. ステークホルダー
- **現場オペレーター**: Window A 右ペインを通じて PDF 要領書を閲覧する。
- **生産管理担当**: Excel 原稿を PDF 化し、USB (`TM-INGEST`/`TM-DIST`) または RaspberryPiServer importer へ登録する。
- **システム管理者**: RaspberryPiServer 上の DocumentViewer を保守し、ログ・設定・サービス監視を行う。

## 3. 使用環境
- **サーバー**: Raspberry Pi 5（RaspberryPiServer リポジトリ）上で Docker Compose または systemd で常駐。
- **クライアント**: Window A (Pi4) のブラウザ iframe (`http://raspi-server-*.local:8501/viewer`) で表示。
- **データ保管**: PDF は `/srv/rpi-server/documents/` に集約。USB ingest や REST API 経由で更新する。

## 4. ドキュメント更新フロー
1. PC で Excel テンプレートから PDF を生成（ファイル名＝部品番号）。
2. USB `TM-INGEST/docviewer/` へ配置し RaspberryPiServer で ingest、または API を利用して直接アップロード。
3. RaspberryPiServer が `/srv/rpi-server/documents` を更新し、Window A の USB 配布 (`tool-dist-sync.sh`) と共有する。
4. DocumentViewer は最新 PDF を参照し、Socket.IO イベントで通知された部品番号の PDF を自動表示。

## 5. 機能要件
- **Socket.IO 連携**: `part_location_updated` / `scan_update` を受信し、遅延なく対象 PDF を表示。直近イベントをキューに保ち、UI にステータスを表示。
- **REST API**: `/api/documents/<part>` が JSON を返却し、Window A のフォールバック検索やテストスクリプトから利用できる。
- **検索 UI**: `/viewer` には手動検索欄と履歴（直近10件）を提供。PDF 未登録時は「PDFが見つかりません」とログ出力。
- **設定**: `.env` / systemd EnvironmentFile で `VIEWER_API_BASE`, `VIEWER_SOCKET_BASE`, `VIEWER_ACCEPT_DEVICE_IDS` などを切り替え。Pi5 のホスト名が `raspi-server-*.local` に変わった場合でも再設定で追随できる。
- **ログ**: `VIEWER_LOG_PATH` が設定されていれば JSON ローテーションログを `/var/log/document-viewer/client.log` に出力。未設定でも標準出力に INFO を記録。

## 6. 非機能要件
- **応答時間**: イベント受信から 3 秒以内に PDF の 1 ページ目を表示。
- **可用性**: Socket.IO 断時は UI で警告し 5 秒間隔で自動再接続。復旧時は成功メッセージを表示。
- **保守性**: 実機検証ログを `docs/test-notes/` に残し、14 日耐久チェック (`docs/test-notes/2025-11-01-14day-check.md`) へ転記。
- **セキュリティ**: REST API へのアクセスは RaspberryPiServer と同一トークンポリシーを用いる。ログに失敗理由を記録。

## 7. ファイル構成
```
/srv/rpi-server/documents/          # PDF 集約先
/home/tools02/DocumentViewer/app/    # Flask アプリケーション
/var/log/document-viewer/client.log  # ログ（VIEWER_LOG_PATH 指定時）
```

## 8. 運用・メンテナンス
- **サービス操作**: `sudo systemctl restart docviewer.service`
- **ログ確認**: `sudo tail -n 50 /var/log/document-viewer/client.log`
- **USB 連携**: RaspberryPiServer の `tool-dist-sync.sh` により Window A と共通の `TM-DIST` を利用。
- **障害対応**: PDF が表示されない場合は `/srv/rpi-server/documents` にファイルが存在するかとログを確認。必要に応じて importer 再実行。

## 9. 今後の課題
- Socket.IO 断状態を UI で明示し、リトライ状況を表示する。
- Playwright による E2E テストを `docs/e2e-plan.md` に沿って追加。
- 多言語 UI・アクセシビリティ対応の検討。
