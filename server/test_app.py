import os
import unittest
from io import BytesIO
from types import SimpleNamespace
from unittest.mock import Mock, patch
from urllib.parse import urlparse


os.environ.setdefault("SUPABASE_URL", "https://example.supabase.co")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key")
os.environ.setdefault("DASHSCOPE_API_KEY", "test-dashscope-key")

from server import app as app_module


class FakeBucket:
    def __init__(self):
        self.upload_call = None

    def upload(self, **kwargs):
        self.upload_call = kwargs

    def get_public_url(self, path):
        return f"https://example.supabase.co/storage/v1/object/public/user-audio/{path}"


class FakeStorage:
    def __init__(self, bucket):
        self.bucket = bucket
        self.requested_bucket = None

    def from_(self, bucket_name):
        self.requested_bucket = bucket_name
        return self.bucket


class FakeSupabase:
    def __init__(self):
        self.bucket = FakeBucket()
        self.storage = FakeStorage(self.bucket)


class UploadAudioTests(unittest.TestCase):
    def setUp(self):
        self.supabase = FakeSupabase()
        self.original_supabase = app_module.supabase
        app_module.supabase = self.supabase
        self.client = app_module.app.test_client()

    def tearDown(self):
        app_module.supabase = self.original_supabase

    def test_requires_audio_file(self):
        response = self.client.post("/upload-audio")

        self.assertEqual(response.status_code, 400)
        self.assertIn("file", response.get_json()["error"])

    def test_rejects_non_m4a_file(self):
        response = self.client.post(
            "/upload-audio",
            data={"file": (BytesIO(b"audio"), "clip.wav", "audio/wav")},
            content_type="multipart/form-data",
        )

        self.assertEqual(response.status_code, 400)

    def test_uploads_m4a_to_user_audio_bucket_and_returns_url(self):
        response = self.client.post(
            "/upload-audio",
            data={"file": (BytesIO(b"m4a-audio"), "clip.m4a", "audio/mp4")},
            content_type="multipart/form-data",
        )

        self.assertEqual(response.status_code, 201)
        payload = response.get_json()
        self.assertEqual(payload["bucket"], "user-audio")
        self.assertTrue(payload["path"].endswith(".m4a"))
        self.assertEqual(self.supabase.storage.requested_bucket, "user-audio")
        self.assertEqual(self.supabase.bucket.upload_call["file"], b"m4a-audio")
        self.assertEqual(
            self.supabase.bucket.upload_call["file_options"]["content-type"],
            "audio/mp4",
        )
        self.assertTrue(payload["url"].endswith(payload["path"]))


class ParseAudioExpensesTests(unittest.TestCase):
    def setUp(self):
        self.client = app_module.app.test_client()
        host = urlparse(app_module.supabase_url).hostname
        self.audio_url = f"https://{host}/storage/v1/object/public/user-audio/2026/07/13/test.m4a"
        self.categories = [
            {"id": "category-food", "name": "餐饮"},
            {"id": "category-travel", "name": "交通"},
        ]

    def test_requires_uploaded_audio_url(self):
        response = self.client.post(
            "/parse-audio-expenses",
            json={"audio_url": "https://attacker.example/audio.m4a", "categories": self.categories},
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("audio_url", response.get_json()["error"])

    def test_requires_categories(self):
        response = self.client.post(
            "/parse-audio-expenses",
            json={"audio_url": self.audio_url, "categories": []},
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("categories", response.get_json()["error"])

    def test_returns_multiple_normalized_expenses(self):
        ai_text = (
            '```json\n['
            '{"amount":45,"title":"午餐","category_id":"category-food","category_name":"餐饮"},'
            '{"amount":28,"title":"打车","category_id":"category-travel","category_name":"交通"}'
            ']\n```'
        )
        chunks = [
            SimpleNamespace(
                choices=[SimpleNamespace(delta=SimpleNamespace(content=ai_text))]
            )
        ]
        create = Mock(return_value=chunks)
        fake_openai = Mock(
            return_value=SimpleNamespace(
                chat=SimpleNamespace(completions=SimpleNamespace(create=create))
            )
        )

        with patch.object(app_module, "OpenAI", fake_openai):
            response = self.client.post(
                "/parse-audio-expenses",
                json={"audio_url": self.audio_url, "categories": self.categories},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.get_json()
        self.assertEqual(len(payload), 2)
        self.assertEqual(payload[0]["amount"], 45.0)
        self.assertEqual(payload[1]["category_id"], "category-travel")
        call = create.call_args.kwargs
        self.assertTrue(call["stream"])
        self.assertEqual(call["modalities"], ["text"])
        self.assertEqual(call["messages"][0]["content"][0]["input_audio"]["data"], self.audio_url)

    def test_rejects_category_not_supplied_by_client(self):
        invalid = '[{"amount":10,"title":"电影","category_id":"unknown","category_name":"娱乐"}]'
        with self.assertRaises(ValueError):
            app_module._normalize_ai_entries(invalid, self.categories)


if __name__ == "__main__":
    unittest.main()
