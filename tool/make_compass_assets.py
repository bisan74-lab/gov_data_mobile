#!/usr/bin/env python3
"""바람나침판 이미지 자산을 원본 그림에서 다시 만든다.

    python3 tool/make_compass_assets.py

입력 `tool/source_art/*.png`(사용자가 준 원본, **흰 배경 불투명**)를 읽어
`assets/compass/*.png`를 만든다. 원본을 바꾸면 이 스크립트를 다시 돌린다.

원본을 그대로 못 쓰는 이유:
- 흰 배경이 불투명해서, 그대로 겹치면 **화살표의 흰 사각형이 나침반을
  가린다.**
- 나침반이 흑백 선화라, 어두운 테마에서 검은 선이 배경에 묻힌다.
"""

import pathlib

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "tool" / "source_art"
OUT = ROOT / "assets" / "compass"


def make_rose() -> None:
    """나침반: 흑백 선화 → **알파 마스크**.

    밝기가 어두울수록 불투명하게 만들고 색은 흰색으로 통일한다. 그러면
    Flutter에서 `Image.asset(color: ...)`으로 테마 색을 입힐 수 있어
    **한 장이 밝은 테마·어두운 테마를 다 처리한다.**

    정사각형으로 패딩하는 이유: 원판 중심이 위젯 중심과 어긋나면 회전할 때
    나침반이 비틀거린다.
    """
    src = Image.open(SRC / "compass_rose_source.png").convert("RGB")
    w, h = src.size
    side = max(w, h)
    ox, oy = (side - w) // 2, (side - h) // 2
    rose = Image.new("RGBA", (side, side), (255, 255, 255, 0))
    sp, rp = src.load(), rose.load()
    for y in range(h):
        for x in range(w):
            r, g, b = sp[x, y]
            lum = (r * 299 + g * 587 + b * 114) // 1000
            a = 255 - lum
            if a > 4:
                rp[x + ox, y + oy] = (255, 255, 255, a)
    OUT.mkdir(parents=True, exist_ok=True)
    rose.save(OUT / "compass_rose.png", optimize=True)
    print(f"compass_rose.png {rose.size}")


def make_arrow() -> None:
    """화살표: 흰 배경만 걷어 내고 **파란색은 살린다**.

    원본은 색을 흰 바탕에 섞어 놓은 상태이므로 그 합성을 되돌린다:
        p = a*C + (1-a)*255  →  a = 1 - min(r,g,b)/255,  C = (p - (1-a)*255)/a
    단순히 "흰색이면 지우기"로 하면 **경계에 흰 테두리가 남는다.**

    원본은 왼쪽을 가리키는데 나침반에서는 바깥에서 가운데로 꽂혀야 하므로,
    90도 돌려 **아래쪽**을 향하게 저장한다(9시 → 6시).
    """
    src = Image.open(SRC / "wind_arrow_source.png").convert("RGB")
    w, h = src.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sp, op = src.load(), out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = sp[x, y]
            a = 1 - min(r, g, b) / 255
            if a <= 0.02:
                continue
            inv = (1 - a) * 255
            c = tuple(max(0, min(255, round((v - inv) / a))) for v in (r, g, b))
            op[x, y] = (c[0], c[1], c[2], round(a * 255))
    out = out.rotate(90, expand=True)
    OUT.mkdir(parents=True, exist_ok=True)
    out.save(OUT / "wind_arrow.png", optimize=True)
    print(f"wind_arrow.png {out.size}")


if __name__ == "__main__":
    make_rose()
    make_arrow()
