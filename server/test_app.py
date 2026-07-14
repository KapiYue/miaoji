import os
import unittest
from io import BytesIO
from types import SimpleNamespace
from unittest.mock import Mock, patch


os.environ.setdefault("SUPABASE_URL", "https://example.supabase.co")
os.environ.setdefault("SUPABASE_SECRET_KEY", "sb_secret_test-key")
os.environ.setdefault("DASHSCOPE_API_KEY", "test-dashscope-key")

from server import app as app_module


class FakeBucket:
    def __init__(self):
        self.upload_call = None
        self.removed_paths = []

    def upload(self, **kwargs):
        self.upload_call = kwargs

    def create_signed_url(self, path, expires_in):
        return {
            "signedURL": f"https://example.supabase.co/storage/v1/object/sign/user-audio/{path}?token=test"
        }

    def remove(self, paths):
        self.removed_paths.extend(paths)


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
        self.auth = SimpleNamespace(
            get_user=lambda token: SimpleNamespace(
                user=SimpleNamespace(id="11111111-1111-1111-1111-111111111111")
            )
        )


AUTH_HEADERS = {"Authorization": "Bearer test-access-token"}
USER_ID = "11111111-1111-1111-1111-111111111111"


class UploadAudioTests(unittest.TestCase):
    def setUp(self):
        self.supabase = FakeSupabase()
        self.original_supabase = app_module.supabase
        app_module.supabase = self.supabase
        self.client = app_module.app.test_client()

    def tearDown(self):
        app_module.supabase = self.original_supabase

    def test_requires_audio_file(self):
        response = self.client.post("/upload-audio", headers=AUTH_HEADERS)

        self.assertEqual(response.status_code, 400)
        self.assertIn("file", response.get_json()["error"])

    def test_rejects_non_m4a_file(self):
        response = self.client.post(
            "/upload-audio",
            data={"file": (BytesIO(b"audio"), "clip.wav", "audio/wav")},
            content_type="multipart/form-data",
            headers=AUTH_HEADERS,
        )

        self.assertEqual(response.status_code, 400)

    def test_requires_authenticated_session(self):
        response = self.client.post("/upload-audio")

        self.assertEqual(response.status_code, 401)

    def test_uploads_m4a_to_private_user_audio_path(self):
        response = self.client.post(
            "/upload-audio",
            data={"file": (BytesIO(b"m4a-audio"), "clip.m4a", "audio/mp4")},
            content_type="multipart/form-data",
            headers=AUTH_HEADERS,
        )

        self.assertEqual(response.status_code, 201)
        payload = response.get_json()
        self.assertEqual(payload["bucket"], "user-audio")
        self.assertTrue(payload["path"].startswith(f"{USER_ID}/"))
        self.assertTrue(payload["path"].endswith(".m4a"))
        self.assertEqual(self.supabase.storage.requested_bucket, "user-audio")
        self.assertEqual(self.supabase.bucket.upload_call["file"], b"m4a-audio")
        self.assertEqual(
            self.supabase.bucket.upload_call["file_options"]["content-type"],
            "audio/mp4",
        )


class ParseAudioExpensesTests(unittest.TestCase):
    def setUp(self):
        self.supabase = FakeSupabase()
        self.original_supabase = app_module.supabase
        app_module.supabase = self.supabase
        self.client = app_module.app.test_client()
        self.audio_path = f"{USER_ID}/2026/07/13/test.m4a"
        self.categories = [
            {"id": "category-food", "name": "餐饮"},
            {"id": "category-travel", "name": "交通"},
        ]

    def tearDown(self):
        app_module.supabase = self.original_supabase

    def test_requires_current_users_uploaded_audio_path(self):
        response = self.client.post(
            "/parse-audio-expenses",
            json={"audio_path": "another-user/2026/07/13/test.m4a", "categories": self.categories},
            headers=AUTH_HEADERS,
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("audio_path", response.get_json()["error"])

    def test_requires_categories(self):
        response = self.client.post(
            "/parse-audio-expenses",
            json={"audio_path": self.audio_path, "categories": []},
            headers=AUTH_HEADERS,
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
                json={"audio_path": self.audio_path, "categories": self.categories},
                headers=AUTH_HEADERS,
            )

        self.assertEqual(response.status_code, 200)
        payload = response.get_json()
        self.assertEqual(len(payload), 2)
        self.assertEqual(payload[0]["amount"], 45.0)
        self.assertEqual(payload[1]["category_id"], "category-travel")
        call = create.call_args.kwargs
        self.assertTrue(call["stream"])
        self.assertEqual(call["modalities"], ["text"])
        audio_url = call["messages"][0]["content"][0]["input_audio"]["data"]
        self.assertIn("/storage/v1/object/sign/user-audio/", audio_url)
        self.assertEqual(self.supabase.bucket.removed_paths, [self.audio_path])

    def test_rejects_category_not_supplied_by_client(self):
        invalid = '[{"amount":10,"title":"电影","category_id":"unknown","category_name":"娱乐"}]'
        with self.assertRaises(ValueError):
            app_module._normalize_ai_entries(invalid, self.categories)


if __name__ == "__main__":
    unittest.main()
