import os
import json
import math
import re
from functools import wraps
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from dotenv import load_dotenv
from flask import Flask, jsonify, request
from openai import OpenAI
from supabase import Client, create_client


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
DASHSCOPE_BASE_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
DASHSCOPE_MODEL = os.getenv("DASHSCOPE_MODEL", "qwen-omni-turbo-0119")


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

        audio_url = _temporary_audio_url(bucket, audio_path)
        prompt = _expense_prompt(normalized_categories)
        client = OpenAI(
            api_key=api_key,
            base_url=DASHSCOPE_BASE_URL,
            timeout=120.0,
            max_retries=1,
        )
        completion = client.chat.completions.create(
            model=DASHSCOPE_MODEL,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "input_audio",
                            "input_audio": {"data": audio_url, "format": "m4a"},
                        },
                        {"type": "text", "text": prompt},
                    ],
                }
            ],
            modalities=["text"],
            max_tokens=2048,
            stream=True,
            stream_options={"include_usage": True},
        )
        raw_text = _collect_stream_text(completion)
        entries = _normalize_ai_entries(raw_text, normalized_categories)
        return jsonify(entries)
    except (ValueError, json.JSONDecodeError) as exc:
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


def _expense_prompt(categories):
    category_json = json.dumps(categories, ensure_ascii=False, separators=(",", ":"))
    return f"""
你是一个中文记账助手。请完整理解音频，将其中每一笔支出拆成独立条目。
客户端可选分类如下：{category_json}

只输出 JSON 数组，不要 Markdown、解释或其他文字。每个数组元素必须严格包含：
{{"amount": 正数数字, "title": "简洁消费标题", "category_id": "分类id", "category_name": "分类名称"}}

规则：
1. 音频提到多笔消费时返回多条，不能合并金额；只提到一笔则返回一条。
2. amount 只使用数字，单位默认为元；title 不包含金额。
3. category_id 和 category_name 必须来自给定分类中的同一项，选择语义最接近的一项。
4. 不要臆造音频中没有的消费；完全没有可识别的记账明细时返回 []。
""".strip()


def _collect_stream_text(completion):
    parts = []
    for chunk in completion:
        choices = getattr(chunk, "choices", None) or []
        for choice in choices:
            delta = getattr(choice, "delta", None)
            content = getattr(delta, "content", None)
            if isinstance(content, str):
                parts.append(content)
            elif isinstance(content, list):
                for item in content:
                    text = item.get("text") if isinstance(item, dict) else getattr(item, "text", None)
                    if isinstance(text, str):
                        parts.append(text)
    result = "".join(parts).strip()
    if not result:
        raise ValueError("empty AI response")
    return result


def _normalize_ai_entries(raw_text, categories):
    cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw_text.strip(), flags=re.IGNORECASE)
    try:
        value = json.loads(cleaned)
    except json.JSONDecodeError:
        start, end = cleaned.find("["), cleaned.rfind("]")
        if start < 0 or end <= start:
            raise
        value = json.loads(cleaned[start : end + 1])

    if not isinstance(value, list):
        raise ValueError("AI response must be an array")
    if len(value) > 50:
        raise ValueError("AI response contains too many entries")

    by_id = {item["id"]: item for item in categories}
    by_name = {item["name"].casefold(): item for item in categories}
    normalized = []
    for entry in value:
        if not isinstance(entry, dict):
            raise ValueError("expense entry must be an object")
        amount = entry.get("amount")
        title = entry.get("title")
        if (
            isinstance(amount, bool)
            or not isinstance(amount, (int, float))
            or not math.isfinite(amount)
            or amount <= 0
        ):
            raise ValueError("expense amount must be positive")
        if not isinstance(title, str) or not title.strip():
            raise ValueError("expense title is required")

        category = by_id.get(str(entry.get("category_id", "")).strip())
        if category is None:
            category_name = str(entry.get("category_name", entry.get("category", ""))).strip().casefold()
            category = by_name.get(category_name)
        if category is None:
            raise ValueError("expense category is not in the client category list")

        normalized.append(
            {
                "amount": round(float(amount), 2),
                "title": title.strip()[:100],
                "category_id": category["id"],
                "category_name": category["name"],
            }
        )
    return normalized


@app.errorhandler(413)
def audio_too_large(_error):
    return jsonify({"error": "audio file exceeds the 25 MB limit"}), 413


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
