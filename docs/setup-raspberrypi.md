# Raspberry Pi Setup Guide

このドキュメントでは、Raspberry Pi 上で Document Viewer を自動起動し、PDF を閲覧できるようにするまでの手順をまとめる。

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

## 備考
- iframe の sandbox 属性を外さないと Chromium が PDF 読み込みをブロックするため、`app/templates/index.html` の iframe は以下のように設定している。
  ```html
  <iframe id="pdf-frame" title="PDF Viewer" allow="clipboard-write"></iframe>
  ```
- USB 自動インポートの systemd サービスは別途 `document-importer.service` を導入予定。


## 運用時の安全な更新手順
1. ターミナルまたは SSH で Raspberry Pi に接続し、`tools02` ユーザーでログインする。
2. Document Viewer を停止: `sudo systemctl stop document-viewer.service`
3. リポジトリを更新: `cd ~/DocumentViewer && git fetch && git pull`
4. 依存パッケージを更新: `source ~/document-viewer-venv/bin/activate && pip install -r ~/DocumentViewer/app/requirements.txt`
5. サービスを再起動: `sudo systemctl daemon-reload` (必要に応じて) および `sudo systemctl restart document-viewer.service`
6. 状態確認: `sudo systemctl status document-viewer.service` が `active (running)` であることを確認。
7. Chromium が自動で再接続しない場合は `Ctrl+R` または再起動 (`sudo reboot`) で画面を更新する。

> 注意: 仮想環境は `/home/tools02/document-viewer-venv` に配置している。誤ってリポジトリ直下に `.venv` を作成すると `git pull` で競合するので、常にこちらの環境を利用する。
