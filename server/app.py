import os
from pathlib import Path

from dotenv import load_dotenv
from flask import Flask, jsonify
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


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
