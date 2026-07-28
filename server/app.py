import os
from functools import wraps
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse
from uuid import uuid4
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from dotenv import load_dotenv
from flask import Flask, jsonify, request
from openai import OpenAI
from supabase import Client, create_client

try:
    from .omni import (
        expense_prompt as _expense_prompt,
        normalize_entries as _normalize_ai_entries,
        request_audio_expenses,
    )
except ImportError:
    from omni import (
        expense_prompt as _expense_prompt,
        normalize_entries as _normalize_ai_entries,
        request_audio_expenses,
    )


load_dotenv(Path(__file__).resolve().parent / ".env")

supabase_url = os.getenv("SUPABASE_URL")
supabase_secret_key = os.getenv("SUPABASE_SECRET_KEY")

if not supabase_url or not supabase_secret_key:
    raise RuntimeError(
        "SUPABASE_URL and SUPABASE_SECRET_KEY must be set in server/.env"
    )

supabase: Client = create_client(supabase_url, supabase_secret_key)

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 25 * 1024 * 1024

USER_AUDIO_BUCKET = "user-audio"
ALLOWED_AUDIO_MIME_TYPES = {"audio/mp4", "audio/m4a", "audio/x-m4a"}
DASHSCOPE_MODEL = os.getenv("DASHSCOPE_MODEL", "qwen3.5-omni-plus").strip()
DASHSCOPE_BASE_URL = os.getenv(
    "DASHSCOPE_BASE_URL",
    "https://dashscope.aliyuncs.com/compatible-mode/v1",
).strip().rstrip("/")
BUSINESS_TIMEZONE = os.getenv("BUSINESS_TIMEZONE", "Asia/Shanghai").strip()
SERVER_PORT = int(os.getenv("PORT", "8000"))


@app.get("/")
@app.get("/healthz")
def health_check():
    return jsonify({"status": "ok"})


def require_authenticated_user(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        authorization = request.headers.get("Authorization", "")
        scheme, _, token = authorization.partition(" ")
        if scheme.lower() != "bearer" or not token.strip():
            return jsonify({"error": "a valid Supabase bearer token is required"}), 401
        try:
            auth_response = supabase.auth.get_user(token.strip())
            user = getattr(auth_response, "user", None)
            user_id = getattr(user, "id", None)
            if not user_id:
                raise ValueError("missing user")
        except Exception:
            app.logger.info("Rejected an invalid Supabase bearer token")
            return jsonify({"error": "the Supabase session is invalid or expired"}), 401
        return view(str(user_id), *args, **kwargs)

    return wrapped


def _temporary_audio_url(bucket, audio_path):
    try:
        signed = bucket.create_signed_url(audio_path, 300)
    except Exception as exc:
        raise RuntimeError("failed to create a temporary audio URL") from exc
    if isinstance(signed, dict):
        value = signed.get("signedURL") or signed.get("signedUrl") or signed.get("signed_url")
    else:
        value = getattr(signed, "signed_url", None)
    if not isinstance(value, str) or not value.startswith("https://"):
        raise RuntimeError("storage returned an invalid temporary audio URL")
    return value


@app.post("/upload-audio")
@require_authenticated_user
def upload_audio(user_id):
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
    storage_path = f"{user_id}/{now:%Y/%m/%d}/{uuid4().hex}.m4a"

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
        return (
            jsonify(
                {
                    "path": storage_path,
                    "bucket": USER_AUDIO_BUCKET,
                }
            ),
            201,
        )
    except Exception as exc:
        app.logger.exception("Audio upload to Supabase failed")
        return jsonify({"error": "failed to store audio file"}), 502


@app.post("/parse-audio-expenses")
@require_authenticated_user
def parse_audio_expenses(user_id):
    """Turn one uploaded recording into one or more normalized expense drafts."""
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify({"error": "a JSON request body is required"}), 400

    audio_path = payload.get("audio_path")
    categories = payload.get("categories")
    if not _is_user_audio_path(audio_path, user_id):
        return jsonify({"error": "audio_path must identify the current user's uploaded audio"}), 400

    bucket = supabase.storage.from_(USER_AUDIO_BUCKET)
    try:
        try:
            normalized_categories = _validate_categories(categories)
        except ValueError as exc:
            return jsonify({"error": str(exc)}), 400

        api_key = os.getenv("DASHSCOPE_API_KEY")
        if not api_key:
            return jsonify({"error": "DASHSCOPE_API_KEY is not configured"}), 503

        try:
            base_url = _validated_dashscope_base_url(DASHSCOPE_BASE_URL)
            business_timezone = ZoneInfo(BUSINESS_TIMEZONE)
        except (ValueError, ZoneInfoNotFoundError) as exc:
            app.logger.error("Invalid DashScope configuration: %s", exc)
            return jsonify({"error": "DashScope endpoint or timezone is not configured"}), 503

        audio_url = _temporary_audio_url(bucket, audio_path)
        prompt = _expense_prompt(
            normalized_categories,
            datetime.now(business_timezone).date(),
            BUSINESS_TIMEZONE,
        )
        client = OpenAI(
            api_key=api_key,
            base_url=base_url,
            timeout=120.0,
            max_retries=1,
        )
        result = request_audio_expenses(
            client,
            model=DASHSCOPE_MODEL,
            audio_data=audio_url,
            audio_format="m4a",
            prompt=prompt,
        )
        entries = _normalize_ai_entries(result.raw_text, normalized_categories)
        return jsonify(entries)
    except ValueError as exc:
        app.logger.warning("DashScope returned an invalid expense payload: %s", exc)
        return jsonify({"error": "AI returned an invalid expense list"}), 502
    except Exception:
        app.logger.exception("DashScope audio parsing failed")
        return jsonify({"error": "failed to parse the audio with AI"}), 502
    finally:
        try:
            bucket.remove([audio_path])
        except Exception:
            app.logger.exception("Failed to delete temporary audio object %s", audio_path)


def _validate_categories(value):
    if not isinstance(value, list) or not value:
        raise ValueError("categories must be a non-empty array")
    if len(value) > 100:
        raise ValueError("categories may contain at most 100 items")

    normalized = []
    seen_ids = set()
    for item in value:
        if not isinstance(item, dict):
            raise ValueError("each category must be an object")
        category_id = item.get("id")
        name = item.get("name")
        if not isinstance(category_id, str) or not category_id.strip():
            raise ValueError("each category requires an id")
        if not isinstance(name, str) or not name.strip():
            raise ValueError("each category requires a name")
        category_id = category_id.strip()
        if category_id in seen_ids:
            raise ValueError("category ids must be unique")
        seen_ids.add(category_id)
        normalized.append({"id": category_id, "name": name.strip()[:50]})
    return normalized


def _is_user_audio_path(value, user_id):
    if not isinstance(value, str):
        return False
    expected_prefix = f"{user_id}/"
    return (
        value.startswith(expected_prefix)
        and value.lower().endswith(".m4a")
        and ".." not in value
        and "//" not in value
        and len(value) <= 300
    )


def _validated_dashscope_base_url(value):
    if not value:
        raise ValueError("DASHSCOPE_BASE_URL is missing")
    parsed = urlparse(value)
    hostname = (parsed.hostname or "").lower()
    if parsed.scheme != "https" or parsed.query or parsed.fragment:
        raise ValueError("DASHSCOPE_BASE_URL must be an HTTPS API base URL")
    if parsed.path.rstrip("/") != "/compatible-mode/v1":
        raise ValueError("DASHSCOPE_BASE_URL must end in /compatible-mode/v1")
    if hostname not in {
        "dashscope.aliyuncs.com",
        "dashscope-intl.aliyuncs.com",
        "dashscope-us.aliyuncs.com",
    } and not hostname.endswith(".maas.aliyuncs.com"):
        raise ValueError("DASHSCOPE_BASE_URL must use an Alibaba Cloud Model Studio host")
    return value


@app.errorhandler(413)
def audio_too_large(_error):
    return jsonify({"error": "audio file exceeds the 25 MB limit"}), 413


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=SERVER_PORT, debug=True)
