#!/usr/bin/env bash
#
# 从 SVG 生成全尺寸 iOS App Icon PNG
#
# 用法：
#   ./scripts/render_app_icon.sh                    # 用默认输出目录 Resources/AppIcon
#   ./scripts/render_app_icon.sh /path/to/output    # 指定输出目录
#
# 依赖：
#   - macOS 自带的 rsvg-convert (brew install librsvg) 或 sips + qlmanage
#   - 备选：python3 + Pillow（pip3 install Pillow）
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$PROJECT_DIR/Resources/AppIcon/AppIcon.svg"
OUTPUT_DIR="${1:-$PROJECT_DIR/Resources/AppIcon/AppIcon.appiconset}"

log()  { printf "\033[1;36m▸ %s\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; }

[[ ! -f "$SVG" ]] && { err "找不到 $SVG"; exit 1; }

# iOS 必需的图标尺寸（@1x / @2x / @3x + iPad + App Store）
SIZES=(
    "40:icon-40@1x.png"
    "80:icon-40@2x.png"
    "120:icon-40@3x.png"
    "29:icon-29@1x.png"
    "58:icon-29@2x.png"
    "87:icon-29@3x.png"
    "76:icon-76@1x.png"
    "152:icon-76@2x.png"
    "167:icon-83.5@2x.png"
    "120:icon-60@2x.png"
    "180:icon-60@3x.png"
    "20:icon-20@1x.png"
    "40:icon-20@2x.png"
    "60:icon-20@3x.png"
    "1024:AppIcon-1024.png"
)

mkdir -p "$OUTPUT_DIR"
log "渲染到 $OUTPUT_DIR"

# 检测可用工具
if command -v rsvg-convert &>/dev/null; then
    CONVERTER="rsvg"
    log "使用 rsvg-convert"
elif python3 -c "import PIL" 2>/dev/null; then
    CONVERTER="pillow"
    log "使用 Pillow"
else
    err "需要安装转换工具："
    err "  推荐：brew install librsvg"
    err "  备选：pip3 install Pillow"
    exit 1
fi

# 生成 PNG
for entry in "${SIZES[@]}"; do
    size="${entry%%:*}"
    name="${entry##*:}"
    out="$OUTPUT_DIR/$name"

    if [[ "$CONVERTER" == "rsvg" ]]; then
        rsvg-convert -w "$size" -h "$size" "$SVG" -o "$out"
    else
        python3 -c "
from PIL import Image
img = Image.open('$SVG')
img = img.resize(($size, $size), Image.LANCZOS)
img.save('$out', 'PNG')
"
    fi
done
ok "渲染完成"

# 生成 Contents.json
cat > "$OUTPUT_DIR/Contents.json" <<'EOF'
{
  "images" : [
    { "filename" : "icon-20@1x.png",   "idiom" : "iphone", "scale" : "1x", "size" : "20x20" },
    { "filename" : "icon-20@2x.png",   "idiom" : "iphone", "scale" : "2x", "size" : "20x20" },
    { "filename" : "icon-20@3x.png",   "idiom" : "iphone", "scale" : "3x", "size" : "20x20" },
    { "filename" : "icon-29@1x.png",   "idiom" : "iphone", "scale" : "1x", "size" : "29x29" },
    { "filename" : "icon-29@2x.png",   "idiom" : "iphone", "scale" : "2x", "size" : "29x29" },
    { "filename" : "icon-29@3x.png",   "idiom" : "iphone", "scale" : "3x", "size" : "29x29" },
    { "filename" : "icon-40@1x.png",   "idiom" : "iphone", "scale" : "1x", "size" : "40x40" },
    { "filename" : "icon-40@2x.png",   "idiom" : "iphone", "scale" : "2x", "size" : "40x40" },
    { "filename" : "icon-40@3x.png",   "idiom" : "iphone", "scale" : "3x", "size" : "40x40" },
    { "filename" : "icon-60@2x.png",   "idiom" : "iphone", "scale" : "2x", "size" : "60x60" },
    { "filename" : "icon-60@3x.png",   "idiom" : "iphone", "scale" : "3x", "size" : "60x60" },
    { "filename" : "icon-20@1x.png",   "idiom" : "ipad", "scale" : "1x", "size" : "20x20" },
    { "filename" : "icon-20@2x.png",   "idiom" : "ipad", "scale" : "2x", "size" : "20x20" },
    { "filename" : "icon-29@1x.png",   "idiom" : "ipad", "scale" : "1x", "size" : "29x29" },
    { "filename" : "icon-29@2x.png",   "idiom" : "ipad", "scale" : "2x", "size" : "29x29" },
    { "filename" : "icon-40@1x.png",   "idiom" : "ipad", "scale" : "1x", "size" : "40x40" },
    { "filename" : "icon-40@2x.png",   "idiom" : "ipad" },
    { "filename" : "icon-76@1x.png",   "idiom" : "ipad", "scale" : "1x", "size" : "76x76" },
    { "filename" : "icon-76@2x.png",   "idiom" : "ipad", "scale" : "2x", "size" : "76x76" },
    { "filename" : "icon-83.5@2x.png", "idiom" : "ipad", "scale" : "2x", "size" : "83.5x83.5" },
    { "filename" : "AppIcon-1024.png", "idiom" : "ios-marketing", "scale" : "1x", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

ok "生成 Contents.json"
echo ""
ok "下一步：把 AppIcon.appiconset 拖到 Xcode → Asset Catalog"
