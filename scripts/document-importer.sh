#!/usr/bin/env bash
# Copies PDF files from a mounted USB drive into the viewer's document folder.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

LOG_FILE="${IMPORT_LOG:-/var/log/document-viewer/import.log}"
DEST_DIR="${DEST_DIR:-${PROJECT_DIR}/documents}"
STAGING_DIR="${STAGING_DIR:-${PROJECT_DIR}/imports}"
FAILED_DIR="${FAILED_DIR:-${STAGING_DIR}/failed}"
LOCAL_META="${LOCAL_META:-${DEST_DIR}/meta.json}"
USB_SUBDIR="${USB_SUBDIR:-docviewer}"
VIEWER_SERVICE="${VIEWER_SERVICE:-docviewer.service}"
TMP_DIR=""

log() {
  local timestamp message
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  message="$*"
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '%s %s\n' "$timestamp" "$message" | tee -a "$LOG_FILE"
}

usage() {
  cat <<USAGE
Usage: $0 <mount-point>

Copy all PDF files from <mount-point> into ${DEST_DIR}.
USAGE
}

read_timestamp() {
  local file="$1"
  if [[ -f "$file" ]]; then
    python3 - "$file" <<'PY' || echo 0
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
try:
    data = json.loads(path.read_text())
except Exception:
    print(0)
else:
    print(int(data.get("updated_at", 0)))
PY
  else
    echo 0
  fi
}

write_timestamp() {
  local file="$1" ts="$2"
  python3 - "$file" "$ts" <<'PY'
import json, sys, time
from pathlib import Path
path = Path(sys.argv[1])
ts_arg = sys.argv[2]
ts = int(ts_arg) if ts_arg.isdigit() else int(time.time())
path.parent.mkdir(parents=True, exist_ok=True)
with open(path, 'w', encoding='utf-8') as f:
    json.dump({"updated_at": ts}, f)
PY
}

max_pdf_mtime() {
  local dir="$1"
  python3 - "$dir" <<'PY'
import pathlib, sys
dir_path = pathlib.Path(sys.argv[1])
latest = 0
if dir_path.exists():
    for path in dir_path.glob('*.pdf'):
        try:
            ts = int(path.stat().st_mtime)
        except FileNotFoundError:
            continue
        else:
            if ts > latest:
                latest = ts
print(latest)
PY
}

main() {
  if [[ $# -ne 1 ]]; then
    usage >&2
    exit 1
  fi

  local mount_point="$1"
  local usb_dir="${mount_point%/}/${USB_SUBDIR}"

  if [[ ! -d "$mount_point" ]]; then
    log "ERROR mount point '$mount_point' does not exist"
    exit 1
  fi

  if ! mountpoint -q "$mount_point"; then
    log "ERROR '$mount_point' is not a mount point"
    exit 1
  fi

  if [[ ! -d "$DEST_DIR" ]]; then
    log "ERROR destination directory '$DEST_DIR' does not exist"
    exit 1
  fi

  if [[ ! -d "$usb_dir" ]]; then
    log "ERROR USB directory '$usb_dir' does not exist"
    return 0
  fi

  mkdir -p "$STAGING_DIR" "$FAILED_DIR"
  mkdir -p "$DEST_DIR"

  if [[ ! -w "$DEST_DIR" ]]; then
    log "ERROR destination directory '$DEST_DIR' is not writable"
    exit 1
  fi

  if [[ ! -r "$mount_point" ]]; then
    log "ERROR mount point '$mount_point' is not readable"
    exit 1
  fi

  local meta_usb="${usb_dir}/meta.json"
  local usb_ts
  local local_ts
  local latest_pdf_ts
  usb_ts=$(read_timestamp "$meta_usb")
  local_ts=$(read_timestamp "$LOCAL_META")
  latest_pdf_ts=$(max_pdf_mtime "$usb_dir")
  (( latest_pdf_ts > usb_ts )) && usb_ts=$latest_pdf_ts

  if (( usb_ts <= local_ts )); then
    log "INFO local PDFs are up to date (usb_ts=$usb_ts, local_ts=$local_ts)"
    return 0
  fi

  shopt -s nullglob nocaseglob
  local pdfs=("$usb_dir"/*.pdf)
  shopt -u nocaseglob
  shopt -u nullglob

  if (( ${#pdfs[@]} == 0 )); then
    log "INFO no PDF files found in $mount_point"
    return 0
  fi

  log "INFO found ${#pdfs[@]} pdf file(s) in $usb_dir"

  TMP_DIR="$(mktemp -d "$STAGING_DIR/import.XXXXXX")"
  trap 'if [[ -n ${TMP_DIR:-} && -d ${TMP_DIR:-} ]]; then rm -rf "$TMP_DIR"; fi' EXIT

  local success=0
  local failure=0

  for src in "${pdfs[@]}"; do
    local base
    base="$(basename "$src")"
    local staged="$TMP_DIR/$base"

    if cp -f "$src" "$staged"; then
      if install -m 0644 "$staged" "$DEST_DIR/$base"; then
        log "INFO copied $base to $DEST_DIR"
        ((success++))
      else
        log "ERROR failed to install $base to $DEST_DIR"
        mkdir -p "$FAILED_DIR"
        mv -f "$staged" "$FAILED_DIR/$base" || true
        ((failure++))
      fi
    else
      log "ERROR failed to copy $base to staging"
      ((failure++))
    fi
  done

  sync || log "WARN sync command failed"

  log "INFO copy summary: success=$success failure=$failure"

  if (( failure > 0 )); then
    log "WARN some files failed to import; see $FAILED_DIR"
  fi

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl list-units --full --all | grep -Fq "$VIEWER_SERVICE"; then
      if systemctl restart "$VIEWER_SERVICE"; then
        log "INFO restarted $VIEWER_SERVICE"
      else
        log "ERROR failed to restart $VIEWER_SERVICE"
      fi
    else
      log "WARN viewer service '$VIEWER_SERVICE' not found"
    fi
  else
    log "WARN systemctl not available; skipping viewer restart"
  fi

  new_ts=$(date +%s)
  (( new_ts < usb_ts )) && new_ts=$usb_ts
  write_timestamp "$LOCAL_META" "$new_ts"

  log "INFO import complete; it is now safe to remove the USB drive"
}

main "$@"
