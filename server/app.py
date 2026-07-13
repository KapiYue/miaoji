import os
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from dotenv import load_dotenv
from flask import Flask, jsonify, request
from supabase import Client, create_client


load_dotenv(Path(__file__).resolve().parent / ".env")

supabase_url = os.getenv("SUPABASE_URL")
supabase_service_role_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not supabase_url or not supabase_service_role_key:
    raise RuntimeError(
        "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in server/.env"
    )

supabase: Client = create_client(supabase_url, supabase_service_role_key)

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 25 * 1024 * 1024

USER_AUDIO_BUCKET = "user-audio"
ALLOWED_AUDIO_MIME_TYPES = {"audio/mp4", "audio/m4a", "audio/x-m4a"}


@app.route("/")
def hello():
    return "hello flask"


@app.route("/supabase-test")
def supabase_test():
    try:
        users = supabase.auth.admin.list_users()
        return jsonify({"connected": True, "user_count": len(users)})
    except Exception as exc:
        app.logger.exception("Supabase connection test failed")
        return jsonify({"connected": False, "error": str(exc)}), 500


@app.post("/upload-audio")
def upload_audio():
    audio_file = request.files.get("file")
    if audio_file is None:
        return jsonify({"error": "multipart field 'file' is required"}), 400

    filename = audio_file.filename or ""
    if Path(filename).suffix.lower() != ".m4a":
        return jsonify({"error": "only .m4a audio files are accepted"}), 400
    if audio_file.mimetype not in ALLOWED_AUDIO_MIME_TYPES:
        return jsonify({"error": "unsupported audio content type"}), 415

    audio_data = audio_file.read()
    if not audio_data:
        return jsonify({"error": "audio file is empty"}), 400

    now = datetime.now(timezone.utc)
    storage_path = f"{now:%Y/%m/%d}/{uuid4().hex}.m4a"

    try:
        supabase.storage.from_(USER_AUDIO_BUCKET).upload(
            path=storage_path,
            file=audio_data,
            file_options={
                "cache-control": "3600",
                "content-type": "audio/mp4",
                "upsert": "false",
            },
        )
        public_url = supabase.storage.from_(USER_AUDIO_BUCKET).get_public_url(
            storage_path
        )
        return (
            jsonify(
                {
                    "url": public_url,
                    "path": storage_path,
                    "bucket": USER_AUDIO_BUCKET,
                }
            ),
            201,
        )
    except Exception as exc:
        app.logger.exception("Audio upload to Supabase failed")
        return jsonify({"error": "failed to store audio file"}), 502


@app.errorhandler(413)
def audio_too_large(_error):
    return jsonify({"error": "audio file exceeds the 25 MB limit"}), 413


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
