#!/usr/bin/env python3
"""Play Console 스토어 등록정보 이미지를 만든다.

    python3 tool/make_store_art.py

만드는 것(`store/`):
  play_icon_512.png            앱 아이콘 512×512 (32비트 PNG)
  play_feature_1024x500.png    그래픽 이미지 1024×500

둘 다 `assets/icon/`의 앱 로고에서 만들어, 스토어와 기기의 아이콘이 어긋나지
않게 한다. 로고를 바꾸면 이 스크립트를 다시 돌린다.
"""

import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
ICON = ROOT / "assets" / "icon" / "app_icon.png"
MARK = ROOT / "assets" / "icon" / "app_icon_foreground.png"
OUT = ROOT / "store"

# 앱 아이콘의 빨강 계열(어댑티브 아이콘 배경 #B10619과 같은 색조).
RED_DARK = (129, 6, 20)
RED_MID = (177, 6, 25)
RED_LIGHT = (214, 28, 47)

# 이 환경에서 한글이 나오는 유일한 폰트. 시스템에 한국어 전용 폰트가 없어
# CJK 폰트를 쓴다 — 한국어 폰트를 설치할 수 있으면 그쪽이 자모 균형이 낫다.
FONT_PATH = "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc"


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_PATH, size)


def make_icon() -> None:
    """Play 앱 아이콘 512×512.

    Play는 **32비트 PNG**를 요구하므로 RGBA로 저장한다. 모서리를 둥글리거나
    그림자를 넣지 않는다 — Play가 표시 위치마다 알아서 마스킹하는데, 미리
    둥글려 두면 이중으로 깎여 가장자리가 지저분해진다.
    """
    icon = Image.open(ICON).convert("RGBA").resize((512, 512), Image.LANCZOS)
    OUT.mkdir(parents=True, exist_ok=True)
    icon.save(OUT / "play_icon_512.png", optimize=True)
    print(f"play_icon_512.png {icon.size} {icon.mode}")


def _background(w: int, h: int) -> Image.Image:
    """대각선 붉은 그라데이션 + 은은한 바람 결."""
    bg = Image.new("RGB", (w, h))
    px = bg.load()
    for y in range(h):
        for x in range(w):
            # 왼쪽 위가 밝고 오른쪽 아래로 갈수록 짙어진다.
            t = (x / w * 0.65 + y / h * 0.35)
            px[x, y] = tuple(
                round(RED_LIGHT[i] + (RED_DARK[i] - RED_LIGHT[i]) * t)
                for i in range(3)
            )

    # 바람이 흐르는 느낌의 곡선 몇 줄. 아주 옅게 깔아 글자를 방해하지 않는다.
    streaks = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(streaks)
    for i, (y0, amp, alpha, width) in enumerate(
        [(120, 26, 34, 7), (250, 34, 26, 9), (380, 22, 30, 6), (60, 18, 20, 5)]
    ):
        pts = []
        for x in range(-40, w + 40, 12):
            y = y0 + amp * math.sin((x / w) * math.pi * 1.6 + i)
            pts.append((x, y))
        d.line(pts, fill=(255, 255, 255, alpha), width=width, joint="curve")
    streaks = streaks.filter(ImageFilter.GaussianBlur(3))
    bg = Image.alpha_composite(bg.convert("RGBA"), streaks)
    return bg


def make_feature() -> None:
    """그래픽 이미지 1024×500.

    **바깥 여백을 넉넉히 둔다.** Play는 표시 위치에 따라 이 이미지를 잘라
    쓰기도 하고 위에 앱 이름을 얹기도 한다. 가장자리에 붙은 글자는 잘린다.
    """
    w, h = 1024, 500
    img = _background(w, h)
    d = ImageDraw.Draw(img)

    # 왼쪽: 로고 마크(투명 배경 전경 레이어에서 내용만 잘라 쓴다).
    mark = Image.open(MARK).convert("RGBA")
    mark = mark.crop(mark.getbbox())
    size = 270
    mark = mark.resize((size, size), Image.LANCZOS)
    # 붉은 배경 위 흰 마크라, 뒤에 옅은 그림자를 깔아 떠 보이게 한다.
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow.paste(mark, (84, h // 2 - size // 2 + 8), mark)
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    shadow.putalpha(shadow.getchannel("A").point(lambda v: v * 45 // 100))
    img = Image.alpha_composite(img, shadow)
    img.alpha_composite(mark, (80, h // 2 - size // 2))
    d = ImageDraw.Draw(img)

    # 오른쪽: 앱 이름 + 한 줄 설명 + 기능 칩.
    x = 408
    d.text((x, 150), "골프윈디", font=font(96), fill=(255, 255, 255, 255))
    d.text(
        (x + 4, 264),
        "전국 골프장 바람 · 날씨",
        font=font(38),
        fill=(255, 226, 230, 255),
    )

    # **반투명 도형은 반드시 별도 레이어에 그려 합성한다.** ImageDraw는
    # RGBA 이미지에 그릴 때 알파를 섞지 않고 **덮어쓴다** — 같은 이미지에
    # 바로 그리면 칩이 불투명한 흰 덩어리가 되고 그 위 글자가 묻힌다.
    chips = ["라운딩 지수", "시간대별 바람", "바람 지도"]
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    cx = x + 4
    cy = 330
    cf = font(24)
    for label in chips:
        tw = od.textbbox((0, 0), label, font=cf)[2]
        pad = 15
        od.rounded_rectangle(
            (cx, cy, cx + tw + pad * 2, cy + 52),
            radius=26,
            fill=(255, 255, 255, 46),
            outline=(255, 255, 255, 130),
            width=2,
        )
        od.text((cx + pad, cy + 11), label, font=cf, fill=(255, 255, 255, 255))
        cx += tw + pad * 2 + 12
    img = Image.alpha_composite(img, overlay)

    # **가장자리 여백 확인.** Play는 표시 위치에 따라 이 이미지를 잘라 쓰므로
    # 글자가 가장자리에 붙으면 잘린다. 오른쪽 끝이 안전 영역을 넘으면 알린다.
    safe = w - 60
    if cx - 12 > safe:
        raise SystemExit(
            f"그래픽 이미지의 내용이 오른쪽 여백을 침범한다: "
            f"{cx - 12}px > {safe}px. 글자 크기나 시작 위치를 줄일 것."
        )
    print(f"  내용 오른쪽 끝 {cx - 12}px / 안전 한계 {safe}px")

    OUT.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(OUT / "play_feature_1024x500.png", optimize=True)
    print(f"play_feature_1024x500.png {img.size}")


if __name__ == "__main__":
    make_icon()
    make_feature()
