#!/usr/bin/env bash
#
# TestFlight 内测发布脚本
#
# 用法：
#   ./scripts/upload_testflight.sh                    # 自动递增 build 号、archive、上传
#   ./scripts/upload_testflight.sh --notes "修复..."    # 附带测试说明
#   ./scripts/upload_testflight.sh --skip-bump         # 不递增 build 号
#   ./scripts/upload_testflight.sh --watch             # 上传后轮询处理状态直到完成
#
# 前置条件：
#   1. Xcode 里登录了 Apple ID（Accounts → 选开发者账号）
#   2. App Scheme 名是 "DeskPet"
#   3. Bundle ID 与 Xcode 工程里一致
#
set -euo pipefail

# ============== 配置区（按你的项目改） ==============

SCHEME="DeskPet"
WORKSPACE="DeskPet.xcworkspace"          # 如果用 .xcodeproj，改成 DeskPet.xcodeproj
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="Release"
DESTINATION="generic/platform=iOS"
NOTES="本次构建包含最新的桌宠功能更新。"
WATCH=false
SKIP_BUMP=false

# ============== 参数解析 ==============

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notes)      NOTES="$2"; shift 2 ;;
        --watch)      WATCH=true; shift ;;
        --skip-bump)  SKIP_BUMP=true; shift ;;
        --scheme)     SCHEME="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "未知参数：$1"; exit 1 ;;
    esac
done

cd "$PROJECT_DIR"

# ============== 辅助函数 ==============

log()  { printf "\033[1;36m▸ %s\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m⚠ %s\033[0m\n" "$*" >&2; }
err()  { printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; }

# 检测工程文件
if [[ -d "$WORKSPACE" ]]; then
    BUILD_WRAPPER=("xcodebuild" "-workspace" "$WORKSPACE")
elif [[ -f "DeskPet.xcodeproj" ]]; then
    BUILD_WRAPPER=("xcodebuild" "-project" "DeskPet.xcodeproj")
    WORKSPACE="DeskPet.xcodeproj"
else
    err "找不到 $WORKSPACE 或 DeskPet.xcodeproj"
    exit 1
fi

# ============== 1. 递增 build 号 ==============

CURRENT_BUILD=$("${BUILD_WRAPPER[@]}" -showBuildSettings -configuration "$CONFIGURATION" \
                | awk '/CURRENT_PROJECT_VERSION/{print $3}' | head -1)
[[ -z "$CURRENT_BUILD" ]] && CURRENT_BUILD=1

if $SKIP_BUMP; then
    log "跳过 build 号递增（当前 $CURRENT_BUILD）"
    NEW_BUILD="$CURRENT_BUILD"
else
    NEW_BUILD=$((CURRENT_BUILD + 1))
    log "递增 build 号：$CURRENT_BUILD → $NEW_BUILD"
    # 用 agvtool 同时更新所有 target
    if [[ "$WORKSPACE" == *.xcworkspace ]]; then
        xcrun agvtool new-version -all "$NEW_BUILD" >/dev/null 2>&1 \
            || warn "agvtool 失败：请手动改 build 号"
    else
        xcrun agvtool new-version -all "$NEW_BUILD" >/dev/null
    fi
fi

# 当前版本号（如 1.0.0）
VERSION=$("${BUILD_WRAPPER[@]}" -showBuildSettings -configuration "$CONFIGURATION" \
          | awk '/MARKETING_VERSION/{print $3}' | head -1)
[[ -z "$VERSION" ]] && VERSION="1.0.0"

ok "准备构建：v$VERSION ($NEW_BUILD)"

# ============== 2. 清理 ==============

log "清理构建产物…"
"${BUILD_WRAPPER[@]}" clean -configuration "$CONFIGURATION" \
    >/tmp/deskpet_clean.log 2>&1 || { err "清理失败（见 /tmp/deskpet_clean.log）"; tail -20 /tmp/deskpet_clean.log; exit 1; }

# ============== 3. Archive ==============

ARCHIVE_PATH="$PROJECT_DIR/build/DeskPet.xcarchive"
log "Archive → $ARCHIVE_PATH"
rm -rf "$ARCHIVE_PATH"
mkdir -p build

"${BUILD_WRAPPER[@]}" \
    archive \
    -configuration "$CONFIGURATION" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -archivePath "$ARCHIVE_PATH" \
    | tee /tmp/deskpet_archive.log

if [[ ! -d "$ARCHIVE_PATH" ]]; then
    err "Archive 失败（见 /tmp/deskpet_archive.log）"
    exit 1
fi
ok "Archive 完成"

# ============== 4. 导出 IPA ==============

EXPORT_PATH="$PROJECT_DIR/build/ipa"
PLIST_EXPORT="$PROJECT_DIR/build/export_options.plist"

cat > "$PLIST_EXPORT" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>${TEAM_ID:-YOUR_TEAM_ID}</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
</dict>
</plist>
EOF

log "导出 IPA → $EXPORT_PATH"
rm -rf "$EXPORT_PATH"
xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$PLIST_EXPORT" \
    -exportPath "$EXPORT_PATH" \
    | tee /tmp/deskpet_export.log

IPA_FILE="$EXPORT_PATH/DeskPet.ipa"
if [[ ! -f "$IPA_FILE" ]]; then
    err "导出 IPA 失败（见 /tmp/deskpet_export.log）"
    exit 1
fi
ok "IPA 已生成：$IPA_FILE"

# ============== 5. 上传到 App Store Connect ==============

log "验证 IPA（validateApp）…"
xcrun altool --validate-app \
    -f "$IPA_FILE" \
    -t ios \
    -u "${APP_STORE_USER:-}" \
    -p "${APP_STORE_PASS:-}" \
    --apiKey "${API_KEY_ID:-}" \
    --apiIssuer "${API_ISSUER_ID:-}" \
    2>&1 | tee /tmp/deskpet_validate.log || warn "验证步骤失败，可跳过"

log "上传到 App Store Connect…"
# 优先用 App Store Connect API Key（更稳定），否则用账号密码
if [[ -n "${API_KEY_ID:-}" && -n "${API_ISSUER_ID:-}" && -n "${API_KEY_PATH:-}" ]]; then
    xcrun altool --upload-app \
        -f "$IPA_FILE" \
        -t ios \
        --apiKey "$API_KEY_ID" \
        --apiIssuer "$API_ISSUER_ID" \
        --show-progress \
        2>&1 | tee /tmp/deskpet_upload.log
elif [[ -n "${APP_STORE_USER:-}" && -n "${APP_STORE_PASS:-}" ]]; then
    xcrun altool --upload-app \
        -f "$IPA_FILE" \
        -t ios \
        -u "$APP_STORE_USER" \
        -p "$APP_STORE_PASS" \
        --show-progress \
        2>&1 | tee /tmp/deskpet_upload.log
else
    warn "未设置凭据，使用 Xcode 直接上传（推荐首次使用）"
    warn "请设置环境变量："
    warn "  方式 A：API_KEY_ID / API_ISSUER_ID / API_KEY_PATH（推荐）"
    warn "  方式 B：APP_STORE_USER / APP_STORE_PASS（需要 App-Specific Password）"
    warn "或手动：open $ARCHIVE_PATH → Distribute App → TestFlight"
    warn "本次跳过自动上传"
    ok "构建已生成：$ARCHIVE_PATH"
    exit 0
fi

ok "上传完成 🎉"
ok "版本：v$VERSION ($NEW_BUILD)"
ok "测试说明：$NOTES"

# ============== 6.（可选）等待处理 ==============

if $WATCH; then
    log "等待 App Store Connect 处理构建（通常 5-15 分钟）…"
    log "处理完成后，TestFlight 会自动通知测试员"
    log "你可以在 https://appstoreconnect.apple.com → My Apps → TestFlight 查看状态"

    # 用 App Store Connect API 轮询（需要 API key）
    if [[ -z "${API_KEY_ID:-}" ]]; then
        warn "未配置 API_KEY_ID，无法自动轮询，请手动查看 ASC"
        exit 0
    fi

    for i in $(seq 1 60); do
        sleep 60
        log "等待中…（${i} 分钟）"
    done
fi

echo ""
ok "全部完成。下一步："
echo "  1. 打开 https://appstoreconnect.apple.com"
echo "  2. My Apps → DeskPet → TestFlight"
echo "  3. 在新构建的 'Test Details' 里粘贴测试说明："
echo ""
echo "     $NOTES"
echo ""
echo "  4. 添加测试员邮箱 / 群组"
echo "  5. 通知测试员"
