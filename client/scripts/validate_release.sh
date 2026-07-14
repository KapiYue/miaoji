#!/bin/sh

set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
  exit 0
fi

fail() {
  echo "error: App Store Release 配置错误：$1" >&2
  exit 1
}

case "${MIAOJI_API_BASE_URL:-}" in
  https://*) ;;
  *) fail "MIAOJI_API_BASE_URL 必须是公开可访问的 HTTPS 地址。" ;;
esac

case "${SUPABASE_URL:-}" in
  https://*.supabase.co) ;;
  *) fail "SUPABASE_URL 必须是有效的 HTTPS Supabase 项目地址。" ;;
esac

if [ -z "${SUPABASE_PUBLISHABLE_KEY:-}" ] || echo "$SUPABASE_PUBLISHABLE_KEY" | grep -qE 'YOUR_|service_role|secret'; then
  fail "请配置客户端 Publishable/anon key，且不得使用 secret/service_role key。"
fi

case "${PRODUCT_BUNDLE_IDENTIFIER:-}" in
  ""|*test*|personal.*) fail "请将测试 Bundle ID 替换为已在 Apple Developer 注册的正式显式 App ID。" ;;
esac

echo "Release 配置检查通过：HTTPS 服务、Supabase 客户端配置和 Bundle ID 均已设置。"
