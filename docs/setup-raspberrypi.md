# Raspberry Pi Setup Guide

このドキュメントでは、Raspberry Pi 上で Document Viewer を自動起動し、PDF を閲覧できるようにするまでの手順をまとめる。ドキュメント種別ごとの役割については `docs/documentation-guidelines.md` を参照してください。

## 1. OS 更新
```bash
sudo apt update
sudo apt upgrade -y
```

## 2. 必要パッケージのインストール
```bash
sudo apt install -y python3-venv python3-pip inotify-tools chromium-browser git
```

## 3. リポジトリ取得
```bash
cd ~
git clone https://github.com/denkoushi/DocumentViewer
cd DocumentViewer
```

## 4. 仮想環境と依存インストール
```bash
cd app
python3 -m venv ../.venv
source ../.venv/bin/activate
pip install -r requirements.txt
```

## 5. テスト起動
```bash
FLASK_APP=viewer.py flask run --host 0.0.0.0 --port 5000
```
ブラウザで `http://<raspberrypiのIP>:5000` を開き、待機画面が表示されることを確認する。Ctrl+C で停止。

## 6. ドキュメントフォルダと PDF 配置
```bash
cd ~/DocumentViewer
mkdir -p documents
cp <元PDF> documents/TEST-001.pdf  # サンプル
```

## 7. Flask アプリの systemd サービス化
`/etc/systemd/system/document-viewer.service` を作成し、以下を記述する。
```
[Unit]
Description=Document Viewer Flask App
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/tools02/DocumentViewer/app
ExecStart=/home/tools02/DocumentViewer/.venv/bin/flask run --host 0.0.0.0 --port 5000
Environment=FLASK_APP=viewer.py
Environment=PYTHONPATH=/home/tools02/DocumentViewer/app
Restart=on-failure
User=tools02

[Install]
WantedBy=multi-user.target
```
その後、次を実行。
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now document-viewer.service
sudo systemctl status document-viewer.service
```
`Active: active (running)` になっていることを確認。

## 8. Chromium の自動起動 (LXDE-pi-labwc 環境)
`~/.config/autostart/document-viewer.desktop` を作成し、以下を記述。
```
[Desktop Entry]
Type=Application
Name=Document Viewer Kiosk
Exec=chromium-browser --kiosk --incognito --disable-restore-session-state http://localhost:5000
X-GNOME-Autostart-enabled=true
```

## 9. 動作確認
1. `sudo reboot` で再起動。
2. ログイン完了後、Chromium が kiosk モードで起動し Document Viewer が表示されることを確認。
3. `documents/<部品番号>.pdf` を更新すると、ブラウザ内で閲覧できる。

## 10. ミラー検証期間中の日次チェック
- RaspberryPiServer 側の日次チェックリスト（`docs/test-notes/mirror-check-template.md`）に合わせ、DocumentViewer では以下を確認・記録する。
  - 工具管理 UI と同じオーダーが一覧に反映されていること（必要に応じてスクリーンショットを取得）。
  - `~/DocumentViewer/documents/` 配下の PDF が最新タイムスタンプに更新されていること。
  - `journalctl -u docviewer.service -n 50` でエラーがないこと。
- チェック結果はチェックシートの DocumentViewer 欄へ○/×とメモを記入。異常時は `sudo systemctl restart docviewer.service` などで復旧後、再度確認する。

## 備考
- iframe の sandbox 属性を外さないと Chromium が PDF 読み込みをブロックするため、`app/templates/index.html` の iframe は以下のように設定している。
  ```html
  <iframe id="pdf-frame" title="PDF Viewer" allow="clipboard-write"></iframe>
  ```
- USB 自動インポートの systemd サービスは別途 `document-importer.service` を導入予定。


## 運用時の安全な更新手順
1. ターミナルまたは SSH で Raspberry Pi に接続し、`tools01` ユーザーでログインする。
2. Document Viewer を停止: `sudo systemctl stop docviewer.service`
3. リポジトリを更新: `cd ~/DocumentViewer && git fetch && git pull`
4. 依存パッケージを更新: `source ~/DocumentViewer/venv/bin/activate && pip install -r ~/DocumentViewer/app/requirements.txt`
5. サービスを再起動: `sudo systemctl daemon-reload` (必要に応じて) および `sudo systemctl restart docviewer.service`
6. 状態確認: `sudo systemctl status docviewer.service` が `active (running)` であることを確認。
7. Chromium が自動で再接続しない場合は `Ctrl+R` または再起動 (`sudo reboot`) で画面を更新する。

> 注意: 仮想環境は `~/DocumentViewer/venv` に配置している。誤ってリポジトリ直下に `.venv` を作成すると `git pull` で競合するので、常にこちらの環境を利用する。

## USB インポートの手動実行
USB メモリのルートに以下の構成でファイルを配置する。

```
TOOLMASTER/
├── master/          # 工具管理システム用（既存）
└── docviewer/       # ドキュメントビューア用
    ├── meta.json    # {"updated_at": <UNIX 時刻>}
    └── *.pdf        # 表示したい PDF ファイル
```

手動で最新 PDF を取り込む場合は次のコマンドを利用する。

```bash
cd ~/DocumentViewer
sudo bash scripts/usb-import.sh /dev/sda1
```

- コピー結果は `/var/log/document-viewer/import.log` に追記される。
- `docviewer/` 配下は PDF と `meta.json` のみ受け付ける。許可外ファイルや MIME タイプの不一致を検出すると取り込みを中断し、ログへ警告を残す。
  - 警告が出た場合は `tail -n 20 /var/log/document-viewer/import.log` を確認し、記録されたファイルを USB から削除または正しい形式に修正してから再度挿し直す。
- `docviewer/meta.json` の `updated_at` がローカルより新しいときのみ取り込みを行う。初回はファイルがなくても自動作成される。
- 取り込み後は `~/DocumentViewer/documents/meta.json` に最新タイムスタンプが記録され、ブラウザを更新すると PDF が表示される。

> 今後 systemd 常駐化する場合は、上記スクリプトをラップする Unit を作成し、tools01 ユーザーが `/media` を監視する構成へ更新する。

## DocumentViewer を常駐サービス化する

### 10.1 API 接続設定 (任意)
- REST API を RaspberryPiServer へ切り替える場合は `/etc/default/docviewer` に以下を定義してからサービスを再起動します。
  ```bash
  sudo tee /etc/default/docviewer <<'EOF'
  VIEWER_API_BASE=http://raspi-server.local:8501
  VIEWER_API_TOKEN=raspi-token-20251026
  EOF
  sudo systemctl restart docviewer.service
  ```
- `VIEWER_API_TOKEN` が不要な場合は行を削除してください。既存の `.service` テンプレートで `EnvironmentFile=-/etc/default/docviewer` を読み込むため、ファイルがない場合でもエラーになりません。
工場現場では電源投入のみで利用できることが求められます。以下のスクリプトで DocumentViewer を systemd サービスとして登録すると、ラズパイ起動時に自動で Viewer が開始されます。

```bash
cd ~/DocumentViewer
sudo DOCUMENT_VIEWER_USER=tools01 ./scripts/install_docviewer_service.sh
```

- `DOCUMENT_VIEWER_USER` を省略すると `tools01` が利用されます。別ユーザーの場合は環境に合わせて指定してください。
- スクリプトが `/etc/systemd/system/docviewer.service` を作成し、`systemctl enable --now docviewer.service` まで実行します。
- サービス設定では `~/DocumentViewer/venv/bin/python ~/DocumentViewer/app/viewer.py` を常時起動します。仮想環境が無い場合は先に `python3 -m venv venv` などで作成してください。
- 状態確認: `sudo systemctl status docviewer.service`
- ログ確認: `sudo journalctl -u docviewer.service -n 50`
- 停止/再起動: `sudo systemctl stop docviewer.service` / `sudo systemctl restart docviewer.service`

> 既に手動で `python app/viewer.py` を動かしている場合は、サービス導入後にそのプロセスを停止してください。
