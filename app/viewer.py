from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Optional

from flask import Flask, abort, jsonify, render_template, send_from_directory, url_for

BASE_DIR = Path(__file__).resolve().parent.parent
DOCUMENTS_DIR = BASE_DIR / "documents"
DOCUMENTS_DIR.mkdir(exist_ok=True)

app = Flask(__name__, static_folder="static", template_folder="templates")
app.config["SEND_FILE_MAX_AGE_DEFAULT"] = 0


def find_document_filename(part_number: str) -> Optional[str]:
    """Return the PDF filename for the given part number if it exists."""
    normalized = part_number.strip()
    if not normalized:
        return None

    candidate = DOCUMENTS_DIR / f"{normalized}.pdf"
    if candidate.exists():
        return candidate.name

    lower = normalized.lower()
    for pdf_path in DOCUMENTS_DIR.glob("*.pdf"):
        if pdf_path.stem.lower() == lower:
            return pdf_path.name
    return None


@app.after_request
def disable_cache(response):
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
    return response


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/health")
def health():
    return {"status": "ok"}


@app.route("/documents/<path:filename>")
def serve_document(filename: str):
    safe_path = DOCUMENTS_DIR / filename
    if not safe_path.exists() or not safe_path.is_file():
        abort(404)
    return send_from_directory(DOCUMENTS_DIR, filename, mimetype="application/pdf")


@app.route("/api/documents/<path:part_number>")
def api_get_document(part_number: str):
    filename = find_document_filename(part_number)
    if not filename:
        return jsonify({"found": False, "message": "document not found"}), 404

    document_url = url_for("serve_document", filename=filename)
    # Append a timestamp to avoid aggressive kiosk caching
    cache_bust = datetime.utcnow().strftime("%Y%m%d%H%M%S")
    document_url_with_cache = f"{document_url}?v={cache_bust}"
    return jsonify({
        "found": True,
        "partNumber": part_number,
        "filename": filename,
        "url": document_url_with_cache,
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
