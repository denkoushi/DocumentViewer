# DocumentViewer

Raspberry Pi 上で部品ごとの PDF 手順書を表示するためのビューアです。バーコード付き移動票を読み取ると、対応する PDF を即座に全画面表示します。

## はじめに
- Raspberry Pi への導入手順: `docs/setup-raspberrypi.md`
- 機能要件・ロードマップ: `docs/requirements.md`
- ドキュメント運用ルール: `docs/documentation-guidelines.md`
- エージェント向け指針: `docs/AGENTS.md`
- 適用済み変更: `CHANGELOG.md`
- テスト実行手順: `pytest`（詳細は以下参照）
- サービス環境ファイルのサンプル: `config/docviewer.env.sample`

## リポジトリ構成
```
app/        Flask ベースのビューア本体
scripts/    USB 取り込み等の補助スクリプト
systemd/    常駐化用ユニットファイル（例）
ui/         プロトタイプやスタイル関連のリソース
```

## 開発メモ
- 開発時は `app/` ディレクトリで仮想環境を作成し、`FLASK_APP=viewer.py flask run --port 5000` などで起動できます。
- Raspberry Pi 上で常時運用する場合は、`docs/setup-raspberrypi.md` の手順に従って systemd サービス登録と kiosk 起動を設定してください。
- `VIEWER_API_BASE` / `VIEWER_SOCKET_BASE` などの環境変数で RaspberryPiServer 連携先を切り替えられます（下表参照）。
- `VIEWER_LOCAL_DOCS_DIR` を指定すると PDF の配置ディレクトリを任意パスへ変更できます。未指定時はリポジトリ直下の `documents/` を自動作成します。
- `VIEWER_LOG_PATH` を指定するとドキュメント検索・配信イベントがローテーション付きログ（最大 3 MB × 3 世代）として出力されます。未指定時は標準ログのみ利用します。

### 主要な環境変数

| 変数名 | 役割 | 省略時の既定値 |
| --- | --- | --- |
| `VIEWER_API_BASE` | REST API の接続先ベース URL | `http://raspi-server.local:8501` |
| `VIEWER_API_TOKEN` | REST API 呼び出し時の Bearer トークン | 未設定（認証無し） |
| `VIEWER_SOCKET_BASE` | Socket.IO の接続先ベース URL | `VIEWER_API_BASE` |
| `VIEWER_SOCKET_PATH` | Socket.IO のパス | `/socket.io` |
| `VIEWER_SOCKET_AUTO_OPEN` | Socket.IO を自動で開くか (`0`/`1`) | `1` |
| `VIEWER_ACCEPT_DEVICE_IDS` | 受信対象の `device_id` をカンマ区切りで指定 | 未指定で全受信 |
| `VIEWER_ACCEPT_LOCATION_CODES` | 受信対象の `location_code` をカンマ区切りで指定 | 未指定で全受信 |
| `VIEWER_LOCAL_DOCS_DIR` | PDF を格納するディレクトリ | `~/DocumentViewer/documents` |
| `VIEWER_LOG_PATH` | ローテーション付きログの出力先 | 未出力 |

### テスト

`pytest` を使って Flask ビューアの設定や API 応答を検証できます。

```bash
cd ~/DocumentViewer
python -m venv venv
source venv/bin/activate
pip install -r app/requirements.txt pytest
pytest
```

## 連携するシステム
- **tool-management-system02（Window A）**: 右ペインの所在ビューと連動し、OnSiteLogistics から送られた `part_locations` を Socket.IO 経由で参照します。DocumentViewer 自体も RaspberryPiServer の `part_location_updated` / `scan_update` を受信して該当 PDF を自動表示します。USB 同期スクリプト（`scripts/usb-import.sh`）は Window A の `usb_master_sync.sh` から呼び出され、要領書 PDF を共通運用します。
- **OnSiteLogistics（ハンディリーダ）**: 製造オーダーと棚位置を `feature/scan-intake` API で登録し、DocumentViewer と同じ Raspberry Pi 上の右ペインにリアルタイム反映されます（詳細は Window A の RUNBOOK 3.4 を参照）。
- **RaspberryPizero2W_withDropbox（Window C）**: 将来的に Window A と協調して所在/作業情報をサイネージへ配信する計画です。Dropbox ベースの JSON を活用する場合は、Window A 側でデータ提供方法を定義してから本ビューアと整合させます。

## ライセンス
このプロジェクトのライセンスについては別途定義されている場合があります。必要に応じて管理者へ確認してください。
