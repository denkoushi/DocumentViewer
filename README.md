# DocumentViewer

Raspberry Pi 上で部品ごとの PDF 手順書を表示するためのビューアです。バーコード付き移動票を読み取ると、対応する PDF を即座に全画面表示します。

## はじめに
- Raspberry Pi への導入手順: `docs/setup-raspberrypi.md`
- 機能要件・ロードマップ: `docs/requirements.md`
- ドキュメント運用ルール: `docs/documentation-guidelines.md`
- エージェント向け指針: `docs/AGENTS.md`

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

## 連携するシステム
- **tool-management-system02（Window A）**: 右ペインの所在ビューと連動し、OnSiteLogistics から送られた `part_locations` を Socket.IO 経由で参照します。USB 同期スクリプト（`scripts/usb-import.sh`）は Window A の `usb_master_sync.sh` から呼び出され、要領書 PDF を共通運用します。
- **OnSiteLogistics（ハンディリーダ）**: 製造オーダーと棚位置を `feature/scan-intake` API で登録し、DocumentViewer と同じ Raspberry Pi 上の右ペインにリアルタイム反映されます（詳細は Window A の RUNBOOK 3.4 を参照）。
- **RaspberryPizero2W_withDropbox（Window C）**: 将来的に Window A と協調して所在/作業情報をサイネージへ配信する計画です。Dropbox ベースの JSON を活用する場合は、Window A 側でデータ提供方法を定義してから本ビューアと整合させます。

## ライセンス
このプロジェクトのライセンスについては別途定義されている場合があります。必要に応じて管理者へ確認してください。
