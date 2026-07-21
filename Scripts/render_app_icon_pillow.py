#!/usr/bin/env python3
"""
桌宠 App Icon PNG 生成器（不依赖 SVG 解析，直接用 Pillow 绘制）

生成：
  - AppIcon-1024.png            App Store 主图（1024x1024）
  - icon-60@3x.png              iPhone 主屏（180x180）
  - icon-60@2x.png              120x120
  - icon-40@3x.png / @2x        120 / 80
  - icon-29@3x.png / @2x / @1x  87 / 58 / 29
  - icon-20@3x.png / @2x / @1x  60 / 40 / 20
  - icon-76@2x.png / @1x        152 / 76    iPad
  - icon-83.5@2x.png            167          iPad Pro
  - Contents.json               Xcode 索引

用法：
  python3 scripts/render_app_icon_pillow.py [output_dir]

效果：暖橙色圆角背景 + 一只圆滚滚的卡通小宠物（米白身体、粉色耳朵、
       黑眼睛、笑嘴、腮红）+ 右下角白色爪印 + 左上角闪光。
"""
import sys, os, math, json
from PIL import Image, ImageDraw, ImageFilter

def lerp_color(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def draw_appicon(size):
    """渲染指定尺寸的 App Icon，返回 RGBA Image"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # ============ 1. 圆角矩形背景 ============
    # iOS squircle 的角半径约为边长 * 0.2237
    radius = int(size * 0.2237)
    bg_top = (255, 179, 71)        # #FFB347
    bg_bot = (255, 140, 66)        # #FF8C42
    # 用 mask 画圆角矩形 + 垂直渐变
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)

    grad = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / max(size - 1, 1)
        grad.putpixel((0, y), lerp_color(bg_top, bg_bot, t))
    grad = grad.resize((size, size))

    bg_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_img.paste(grad, (0, 0))
    bg_img.putalpha(mask)
    img.alpha_composite(bg_img)

    # ============ 2. 顶部高光（直接画半透明白色弧线，避免图层叠加 bug）============
    # 之前用 alpha_composite 导致背景被压暗，改为直接在主图上画浅色弧
    hl_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl_layer)
    # 画一个上半椭圆作为高光，颜色为暖白色低透明度
    hd.pieslice([-int(size*0.1), -int(size*0.55), size + int(size*0.1), int(size*0.5)],
                180, 360, fill=(255, 245, 220, 90))
    # 模糊让它更柔和
    hl_layer = hl_layer.filter(ImageFilter.GaussianBlur(radius=size//25))
    # 把高光的 alpha 限制在 80 以内
    r, g, b, a = hl_layer.split()
    a = a.point(lambda p: min(p, 80))
    img.alpha_composite(Image.merge("RGBA", (r, g, b, a)))

    # ============ 3. 宠物身体（圆椭圆，居中略偏下） ============
    cx, cy = size // 2, int(size * 0.55)
    body_w = int(size * 0.275)
    body_h = int(size * 0.245)

    # 软阴影
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([cx - body_w, cy - body_h + int(size*0.025),
                cx + body_w, cy + body_h + int(size*0.025)],
               fill=(0, 0, 0, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=size//40))
    img.alpha_composite(shadow)

    # 身体本体（米白）
    body_color = (255, 228, 196)        # #FFE4C4
    d.ellipse([cx - body_w, cy - body_h, cx + body_w, cy + body_h], fill=body_color)

    # ============ 4. 耳朵 ============
    ear_color = (255, 228, 196)
    ear_inner = (255, 182, 182)
    ear_w = int(size * 0.085)
    ear_h = int(size * 0.105)

    def draw_ear(ex, ey, side):
        # 外耳（三角）
        pts = [
            (ex - ear_w, ey + ear_h),
            (ex + ear_w, ey + ear_h),
            (ex + side * ear_w * 0.3, ey - ear_h * 0.6),
        ]
        d.polygon(pts, fill=ear_color)
        # 内耳（粉色小三角）
        ipts = [
            (ex - ear_w * 0.5, ey + ear_h * 0.5),
            (ex + ear_w * 0.5, ey + ear_h * 0.5),
            (ex + side * ear_w * 0.15, ey - ear_h * 0.3),
        ]
        d.polygon(ipts, fill=ear_inner)

    ear_y = int(size * 0.36)
    draw_ear(int(size * 0.32), ear_y, -1)   # 左耳
    draw_ear(int(size * 0.68), ear_y, 1)    # 右耳

    # ============ 5. 脸部 ============
    eye_y = int(size * 0.52)
    eye_offset_x = int(size * 0.085)
    eye_w = int(size * 0.028)
    eye_h = int(size * 0.034)

    # 左右眼（黑色椭圆）
    for side in (-1, 1):
        ex = cx + side * eye_offset_x
        d.ellipse([ex - eye_w, eye_y - eye_h, ex + eye_w, eye_y + eye_h],
                  fill=(61, 40, 23))       # #3D2817
        # 眼睛高光
        hl_r = max(2, int(size * 0.008))
        d.ellipse([ex - hl_r - int(size*0.005),
                   eye_y - int(size*0.012),
                   ex + hl_r - int(size*0.005),
                   eye_y - int(size*0.012) + hl_r * 2],
                  fill=(255, 255, 255))

    # 鼻子
    nose_y = int(size * 0.575)
    nose_w = int(size * 0.014)
    nose_h = int(size * 0.010)
    d.ellipse([cx - nose_w, nose_y - nose_h, cx + nose_w, nose_y + nose_h],
              fill=(61, 40, 23))

    # 嘴（笑弧）
    mouth_y = int(size * 0.605)
    mouth_w = int(size * 0.040)
    d.arc([cx - mouth_w, mouth_y - mouth_w//2, cx + mouth_w, mouth_y + mouth_w//2],
          0, 180, fill=(61, 40, 23), width=max(2, int(size*0.006)))

    # 腮红
    blush_color = (255, 182, 182, 160)
    blush_w = int(size * 0.033)
    blush_h = int(size * 0.020)
    for side in (-1, 1):
        bx = cx + side * int(size * 0.13)
        blush = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        bd = ImageDraw.Draw(blush)
        bd.ellipse([bx - blush_w, eye_y + int(size*0.06) - blush_h,
                    bx + blush_w, eye_y + int(size*0.06) + blush_h],
                   fill=blush_color)
        blush = blush.filter(ImageFilter.GaussianBlur(radius=size//80))
        img.alpha_composite(blush)

    # ============ 6. 右下角爪印 ============
    paw_cx = int(size * 0.78)
    paw_cy = int(size * 0.78)
    paw_color = (255, 255, 255, 220)
    paw = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pd = ImageDraw.Draw(paw)
    # 主掌心
    main_w = int(size * 0.022)
    main_h = int(size * 0.027)
    pd.ellipse([paw_cx - main_w, paw_cy - main_h, paw_cx + main_w, paw_cy + main_h],
               fill=paw_color)
    # 4 个脚趾
    toe_r = max(2, int(size * 0.010))
    for dx, dy in [(-3, -3.2), (3, -3.2), (-4.5, 0), (4.5, 0)]:
        tx = paw_cx + int(size * dx * 0.022)
        ty = paw_cy + int(size * dy * 0.022)
        pd.ellipse([tx - toe_r, ty - int(toe_r*1.3),
                    tx + toe_r, ty + int(toe_r*1.3)],
                   fill=paw_color)
    img.alpha_composite(paw)

    # ============ 7. 左上角闪光 ============
    spark_cx = int(size * 0.22)
    spark_cy = int(size * 0.235)
    spark_color = (255, 255, 255, 200)
    sd = ImageDraw.Draw(img)
    R = int(size * 0.030)
    r = int(size * 0.012)
    points = []
    for i in range(8):
        ang = i * math.pi / 4 - math.pi / 2
        rad = R if i % 2 == 0 else r
        points.append((spark_cx + rad * math.cos(ang),
                       spark_cy + rad * math.sin(ang)))
    sd.polygon(points, fill=spark_color)

    return img


# ============ 主流程 ============

# (输出文件名, 像素尺寸)
ENTRIES = [
    ("icon-20@1x.png",    20),
    ("icon-20@2x.png",    40),
    ("icon-20@3x.png",    60),
    ("icon-29@1x.png",    29),
    ("icon-29@2x.png",    58),
    ("icon-29@3x.png",    87),
    ("icon-40@1x.png",    40),
    ("icon-40@2x.png",    80),
    ("icon-40@3x.png",    120),
    ("icon-60@2x.png",    120),
    ("icon-60@3x.png",    180),
    ("icon-76@1x.png",    76),
    ("icon-76@2x.png",    152),
    ("icon-83.5@2x.png",  167),
    ("AppIcon-1024.png",  1024),
]

CONTENTS_JSON = {
    "images": [
        {"filename": "icon-20@1x.png",   "idiom": "iphone", "scale": "1x", "size": "20x20"},
        {"filename": "icon-20@2x.png",   "idiom": "iphone", "scale": "2x", "size": "20x20"},
        {"filename": "icon-20@3x.png",   "idiom": "iphone", "scale": "3x", "size": "20x20"},
        {"filename": "icon-29@1x.png",   "idiom": "iphone", "scale": "1x", "size": "29x29"},
        {"filename": "icon-29@2x.png",   "idiom": "iphone", "scale": "2x", "size": "29x29"},
        {"filename": "icon-29@3x.png",   "idiom": "iphone", "scale": "3x", "size": "29x29"},
        {"filename": "icon-40@2x.png",   "idiom": "iphone", "scale": "2x", "size": "40x40"},
        {"filename": "icon-40@3x.png",   "idiom": "iphone", "scale": "3x", "size": "40x40"},
        {"filename": "icon-60@2x.png",   "idiom": "iphone", "scale": "2x", "size": "60x60"},
        {"filename": "icon-60@3x.png",   "idiom": "iphone", "scale": "3x", "size": "60x60"},
        {"filename": "icon-20@1x.png",   "idiom": "ipad", "scale": "1x", "size": "20x20"},
        {"filename": "icon-20@2x.png",   "idiom": "ipad", "scale": "2x", "size": "20x20"},
        {"filename": "icon-29@1x.png",   "idiom": "ipad", "scale": "1x", "size": "29x29"},
        {"filename": "icon-29@2x.png",   "idiom": "ipad", "scale": "2x", "size": "29x29"},
        {"filename": "icon-40@1x.png",   "idiom": "ipad", "scale": "1x", "size": "40x40"},
        {"filename": "icon-40@2x.png",   "idiom": "ipad", "scale": "2x", "size": "40x40"},
        {"filename": "icon-76@1x.png",   "idiom": "ipad", "scale": "1x", "size": "76x76"},
        {"filename": "icon-76@2x.png",   "idiom": "ipad", "scale": "2x", "size": "76x76"},
        {"filename": "icon-83.5@2x.png", "idiom": "ipad", "scale": "2x", "size": "83.5x83.5"},
        {"filename": "AppIcon-1024.png", "idiom": "ios-marketing", "scale": "1x", "size": "1024x1024"},
    ],
    "info": {"author": "xcode", "version": 1},
}

def main():
    project_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    default_out = os.path.join(project_dir, "Resources", "AppIcon", "AppIcon.appiconset")
    out_dir = sys.argv[1] if len(sys.argv) > 1 else default_out
    os.makedirs(out_dir, exist_ok=True)

    print(f"▸ 输出目录：{out_dir}")
    for name, sz in ENTRIES:
        img = draw_appicon(sz)
        img.save(os.path.join(out_dir, name), "PNG")
        print(f"  ✓ {name} ({sz}x{sz})")

    with open(os.path.join(out_dir, "Contents.json"), "w") as f:
        json.dump(CONTENTS_JSON, f, indent=2, ensure_ascii=False)
    print(f"  ✓ Contents.json")

    print(f"\n✓ 全部生成完成")
    print(f"下一步：把 AppIcon.appiconset 拖到 Xcode 的 Asset Catalog")

if __name__ == "__main__":
    main()
