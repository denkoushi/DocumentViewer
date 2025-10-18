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

## ライセンス
このプロジェクトのライセンスについては別途定義されている場合があります。必要に応じて管理者へ確認してください。
