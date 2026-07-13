import os
import unittest
from io import BytesIO


os.environ.setdefault("SUPABASE_URL", "https://example.supabase.co")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "test-service-role-key")

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


if __name__ == "__main__":
    unittest.main()
