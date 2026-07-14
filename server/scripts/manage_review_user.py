#!/usr/bin/env python3
"""Create or repair an App Store Review user without storing its password."""

from __future__ import annotations

import argparse
import getpass
import os
import re
import sys
from pathlib import Path

from dotenv import load_dotenv
from supabase import create_client


SERVER_DIRECTORY = Path(__file__).resolve().parents[1]
EMAIL_PATTERN = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


def normalized_email(value: str) -> str:
    email = value.strip().lower()
    if not EMAIL_PATTERN.fullmatch(email):
        raise ValueError("请输入有效的审核账号邮箱。")
    return email


def read_password() -> str:
    password = getpass.getpass("审核账号密码（输入时不会显示）：")
    confirmation = getpass.getpass("再次输入密码：")
    if password != confirmation:
        raise ValueError("两次输入的密码不一致。")
    if len(password) < 12:
        raise ValueError("审核账号密码至少需要 12 个字符。")
    return password


def find_user(admin, email: str):
    page = 1
    while True:
        users = admin.list_users(page=page, per_page=1000)
        for user in users:
            if (user.email or "").strip().lower() == email:
                return user
        if len(users) < 1000:
            return None
        page += 1


def main() -> int:
    parser = argparse.ArgumentParser(
        description="创建或修复一个已确认邮箱的 App Store 审核账号。"
    )
    parser.add_argument("email", help="审核账号邮箱；密码会在终端中隐藏输入。")
    parser.add_argument(
        "--status-only",
        action="store_true",
        help="只检查账号是否存在以及邮箱是否已确认，不修改任何数据。",
    )
    args = parser.parse_args()

    try:
        email = normalized_email(args.email)
        load_dotenv(SERVER_DIRECTORY / ".env")
        supabase_url = os.getenv("SUPABASE_URL")
        secret_key = os.getenv("SUPABASE_SECRET_KEY")
        if not supabase_url or not secret_key or not secret_key.startswith("sb_secret_"):
            raise ValueError(
                "server/.env 必须配置 SUPABASE_URL 和 sb_secret_ 格式的 SUPABASE_SECRET_KEY。"
            )

        admin = create_client(supabase_url, secret_key).auth.admin
        existing_user = find_user(admin, email)
        if args.status_only:
            if existing_user is None:
                print(f"审核账号不存在：{email}")
            else:
                confirmed = bool(
                    existing_user.email_confirmed_at or existing_user.confirmed_at
                )
                status = "已确认" if confirmed else "未确认"
                print(f"审核账号已存在，邮箱{status}：{email}")
            return 0

        if existing_user is not None:
            answer = input(
                f"账号 {email} 已存在。确认重设密码并标记邮箱已确认？[y/N] "
            ).strip().lower()
            if answer not in {"y", "yes"}:
                print("已取消，未修改 Supabase。")
                return 0

        password = read_password()
        if existing_user is None:
            response = admin.create_user(
                {
                    "email": email,
                    "password": password,
                    "email_confirm": True,
                    "user_metadata": {"purpose": "app_store_review"},
                }
            )
            action = "创建"
        else:
            response = admin.update_user_by_id(
                str(existing_user.id),
                {
                    "password": password,
                    "email_confirm": True,
                },
            )
            action = "更新"

        user = response.user
        if user is None or not (user.email_confirmed_at or user.confirmed_at):
            raise RuntimeError("Supabase 已返回用户，但邮箱确认状态未生效。")
        print(f"审核账号已{action}并确认邮箱：{email}")
        return 0
    except (KeyboardInterrupt, EOFError):
        print("\n已取消，未继续操作。", file=sys.stderr)
        return 130
    except Exception as error:
        print(f"操作失败：{error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
