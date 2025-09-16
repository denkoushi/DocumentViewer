#!/usr/bin/env bash
# Copies PDF files from a mounted USB drive into the viewer's document folder.
set -euo pipefail

LOG_FILE="${IMPORT_LOG:-/var/log/document-viewer/import.log}"
DEST_DIR="${DEST_DIR:-/home/pi/document-viewer/documents}"
STAGING_DIR="${STAGING_DIR:-/home/pi/document-viewer/imports}"
FAILED_DIR="${FAILED_DIR:-${STAGING_DIR}/failed}"
VIEWER_SERVICE="${VIEWER_SERVICE:-document-viewer.service}"

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

main() {
  if [[ $# -ne 1 ]]; then
    usage >&2
    exit 1
  fi

  local mount_point="$1"

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

  mkdir -p "$STAGING_DIR" "$FAILED_DIR"

  if [[ ! -w "$DEST_DIR" ]]; then
    log "ERROR destination directory '$DEST_DIR' is not writable"
    exit 1
  fi

  if [[ ! -r "$mount_point" ]]; then
    log "ERROR mount point '$mount_point' is not readable"
    exit 1
  fi

  shopt -s nullglob nocaseglob
  local pdfs=("$mount_point"/*.pdf)
  shopt -u nocaseglob
  shopt -u nullglob

  if (( ${#pdfs[@]} == 0 )); then
    log "INFO no PDF files found in $mount_point"
    return 0
  fi

  log "INFO found ${#pdfs[@]} pdf file(s) in $mount_point"

  local tmp_dir
  tmp_dir="$(mktemp -d "$STAGING_DIR/import.XXXXXX")"
  trap 'rm -rf "$tmp_dir"' EXIT

  local success=0
  local failure=0

  for src in "${pdfs[@]}"; do
    local base
    base="$(basename "$src")"
    local staged="$tmp_dir/$base"

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

  log "INFO import complete; it is now safe to remove the USB drive"
}

main "$@"
