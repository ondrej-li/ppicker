#!/usr/bin/env python3
"""Render the App Store screenshot set (2880 x 1800, RGB PNG).

These are deliberately staged marketing images rather than literal captures:
the UI is redrawn with generic profile names ("Personal", "Work", "Client")
so no real browser profile name, account or URL appears.

Run with a Python that has Pillow installed:
    python3 scripts/make-appstore-screenshots.py
"""

from __future__ import annotations

import os
import re
from functools import lru_cache

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_PATH = os.path.join(
    ROOT, "ProfilePicker", "Assets.xcassets", "AppIcon.appiconset", "icon_512x512@2x.png"
)
OUT_DIR = os.path.join(ROOT, "AppStore", "Submission", "screenshots")

FINAL_W, FINAL_H = 2880, 1800
SCALE = 2
W, H = FINAL_W * SCALE, FINAL_H * SCALE

SF = "/System/Library/Fonts/SFNS.ttf"
SF_MONO = "/System/Library/Fonts/SFNSMono.ttf"

INK = (246, 246, 251)
MUTED = (178, 178, 198)
DIM = (139, 139, 160)
FAINT = (104, 104, 124)
ACCENT = (126, 112, 255)
ACCENT_2 = (88, 196, 255)
GREEN = (48, 209, 88)
PURPLE = (191, 90, 242)
BLUE = (10, 132, 255)
ORANGE = (255, 159, 10)
RED = (255, 69, 58)
TEAL = (50, 199, 184)

BG_TOP = (7, 7, 18)
BG_BOTTOM = (26, 23, 51)
WINDOW = (27, 27, 35)
WINDOW_BAR = (35, 35, 45)
SIDEBAR = (20, 20, 27)
CARD = (37, 37, 47)
CARD_HI = (49, 49, 63)
BORDER = (60, 60, 78)
FIELD = (18, 18, 25)


@lru_cache(maxsize=None)
def font(size: int, weight: str = "Regular", mono: bool = False) -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(SF_MONO if mono else SF, size)
    if weight != "Regular":
        try:
            face.set_variation_by_name(weight)
        except Exception:
            pass
    return face


def text_width(draw: ImageDraw.ImageDraw, text: str, face: ImageFont.FreeTypeFont) -> float:
    return draw.textlength(text, font=face)


def wrap(draw: ImageDraw.ImageDraw, text: str, face: ImageFont.FreeTypeFont, max_width: float) -> list[str]:
    lines: list[str] = []
    for paragraph in text.split("\n"):
        words = paragraph.split()
        if not words:
            lines.append("")
            continue
        line = words[0]
        for word in words[1:]:
            candidate = f"{line} {word}"
            if text_width(draw, candidate, face) <= max_width:
                line = candidate
            else:
                lines.append(line)
                line = word
        lines.append(line)
    return lines


def paragraph(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    text: str,
    face: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int],
    max_width: float,
    line_height: float,
) -> float:
    x, y = xy
    for line in wrap(draw, text, face, max_width):
        draw.text((x, y), line, font=face, fill=fill)
        y += line_height
    return y


def tracking_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    text: str,
    face: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int],
    tracking: float,
) -> None:
    x, y = xy
    for char in text:
        draw.text((x, y), char, font=face, fill=fill)
        x += text_width(draw, char, face) + tracking


def load_icon(size: int) -> Image.Image:
    icon = Image.open(ICON_PATH).convert("RGBA")
    return icon.resize((size, size), Image.Resampling.LANCZOS)


def background() -> Image.Image:
    gradient = Image.linear_gradient("L").resize((W, H))
    img = ImageOps.colorize(gradient, BG_TOP, BG_BOTTOM).convert("RGBA")

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    draw.ellipse((W * 0.60, -H * 0.28, W * 1.12, H * 0.62), fill=(102, 74, 236, 118))
    glow = glow.filter(ImageFilter.GaussianBlur(190))
    img = Image.alpha_composite(img, glow)

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    draw.ellipse((-W * 0.22, H * 0.62, W * 0.52, H * 1.22), fill=(35, 118, 200, 62))
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    img = Image.alpha_composite(img, glow)

    # A barely visible top highlight keeps the large dark field from looking flat.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    draw.rectangle((0, 0, W, 8), fill=(255, 255, 255, 20))
    img = Image.alpha_composite(img, glow)
    return img


def shadow(
    img: Image.Image,
    box: tuple[float, float, float, float],
    radius: float,
    blur: float = 100,
    offset: tuple[float, float] = (0, 40),
    alpha: int = 160,
) -> Image.Image:
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    x0, y0, x1, y1 = box
    draw.rounded_rectangle(
        (x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]),
        radius=radius,
        fill=(0, 0, 0, alpha),
    )
    overlay = overlay.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(img, overlay)


def draw_brand(img: Image.Image, draw: ImageDraw.ImageDraw) -> None:
    icon = load_icon(168)
    img.alpha_composite(icon, (320, 220))
    tracking_text(draw, (540, 278), "PROFILE PICKER", font(44, "Semibold"), (214, 214, 230), 6)


def draw_headline(
    draw: ImageDraw.ImageDraw,
    lines: list[str],
    subhead: str,
    size: int = 192,
    sub_width: float = 2300,
) -> None:
    draw.rounded_rectangle((320, 400, 464, 412), radius=6, fill=ACCENT)
    y = 470
    face = font(size, "Bold")
    for line in lines:
        draw.text((320, y), line, font=face, fill=INK)
        y += size * 1.16
    paragraph(draw, (320, y + 28), subhead, font(72), MUTED, sub_width, 96)


# ---------------------------------------------------------------------------
# Small UI drawing helpers
# ---------------------------------------------------------------------------


def circle_avatar(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    radius: float,
    letter: str,
    color: tuple[int, int, int],
) -> None:
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
    draw.text((x, y - 2), letter, font=font(int(radius * 0.92), "Bold"), fill=(255, 255, 255), anchor="mm")


def checkmark(draw: ImageDraw.ImageDraw, box: tuple[float, float, float, float], color=(255, 255, 255)) -> None:
    x0, y0, x1, y1 = box
    draw.line(
        ((x0 + (x1 - x0) * 0.18, y0 + (y1 - y0) * 0.52),
         (x0 + (x1 - x0) * 0.42, y0 + (y1 - y0) * 0.76),
         (x0 + (x1 - x0) * 0.84, y0 + (y1 - y0) * 0.26)),
        fill=color,
        width=max(3, int((x1 - x0) * 0.14)),
        joint="curve",
    )


def toggle(draw: ImageDraw.ImageDraw, box: tuple[float, float, float, float], on: bool) -> None:
    x0, y0, x1, y1 = box
    fill = GREEN if on else (74, 74, 90)
    draw.rounded_rectangle(box, radius=(y1 - y0) / 2, fill=fill)
    radius = (y1 - y0) / 2 - 6
    cx = x1 - (y1 - y0) / 2 if on else x0 + (y1 - y0) / 2
    cy = (y0 + y1) / 2
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=(255, 255, 255))


def chip(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    text: str,
    face: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int] = CARD_HI,
    color: tuple[int, int, int] = MUTED,
) -> float:
    x, y = xy
    width = text_width(draw, text, face) + 40
    draw.rounded_rectangle((x, y, x + width, y + 48), radius=12, fill=fill)
    draw.text((x + 20, y + 25), text, font=face, fill=color, anchor="lm")
    return width


def chevron(draw: ImageDraw.ImageDraw, x: float, y: float, size: float, color: tuple[int, int, int]) -> None:
    draw.line((x, y, x + size / 2, y + size / 2, x + size, y), fill=color, width=max(2, int(size * 0.14)), joint="curve")


def link_icon(img: Image.Image, x: float, y: float, size: float, color: tuple[int, int, int]) -> None:
    # Two rounded capsules, drawn as a small rotated image.
    icon = Image.new("RGBA", (int(size * 1.7), int(size * 1.7)), (0, 0, 0, 0))
    d = ImageDraw.Draw(icon)
    w = size * 0.42
    h = size * 0.72
    d.rounded_rectangle((size * 0.18, size * 0.10, size * 0.18 + w, size * 0.10 + h), radius=w / 2, outline=color, width=max(3, int(size * 0.10)))
    d.rounded_rectangle((size * 0.96, size * 0.78, size * 0.96 + w, size * 0.78 + h), radius=w / 2, outline=color, width=max(3, int(size * 0.10)))
    icon = icon.rotate(-45, resample=Image.Resampling.BICUBIC, center=(size * 0.85, size * 0.85))
    img.alpha_composite(icon, (int(x), int(y)))


def copy_icon(draw: ImageDraw.ImageDraw, x: float, y: float, size: float, color: tuple[int, int, int]) -> None:
    draw.rounded_rectangle((x, y + size * 0.18, x + size * 0.68, y + size), radius=size * 0.12, outline=color, width=max(2, int(size * 0.10)))
    draw.rounded_rectangle((x + size * 0.30, y, x + size, y + size * 0.78), radius=size * 0.12, outline=color, width=max(2, int(size * 0.10)))


def filter_icon(draw: ImageDraw.ImageDraw, x: float, y: float, size: float, color: tuple[int, int, int]) -> None:
    draw.line((x, y + size * 0.22, x + size, y + size * 0.22), fill=color, width=max(2, int(size * 0.12)))
    draw.line((x + size * 0.18, y + size * 0.52, x + size * 0.82, y + size * 0.52), fill=color, width=max(2, int(size * 0.12)))
    draw.line((x + size * 0.36, y + size * 0.82, x + size * 0.64, y + size * 0.82), fill=color, width=max(2, int(size * 0.12)))


def file_icon(draw: ImageDraw.ImageDraw, x: float, y: float, size: float, color: tuple[int, int, int]) -> None:
    fold = size * 0.30
    draw.rounded_rectangle((x, y, x + size, y + size * 1.22), radius=size * 0.08, outline=color, width=max(2, int(size * 0.08)))
    draw.line((x + size - fold, y, x + size - fold, y + fold, x + size, y + fold), fill=color, width=max(2, int(size * 0.08)), joint="curve")


def lock_icon(draw: ImageDraw.ImageDraw, x: float, y: float, size: float, color: tuple[int, int, int]) -> None:
    draw.rounded_rectangle((x + size * 0.14, y + size * 0.42, x + size * 0.86, y + size * 0.94), radius=size * 0.10, fill=color)
    draw.arc((x + size * 0.26, y + size * 0.10, x + size * 0.74, y + size * 0.64), start=180, end=360, fill=color, width=max(3, int(size * 0.10)))
    draw.ellipse((x + size * 0.44, y + size * 0.62, x + size * 0.56, y + size * 0.74), fill=(30, 30, 40))


def gear_icon(draw: ImageDraw.ImageDraw, x: float, y: float, size: float, color: tuple[int, int, int]) -> None:
    c = (x + size / 2, y + size / 2)
    draw.ellipse((c[0] - size * 0.20, c[1] - size * 0.20, c[0] + size * 0.20, c[1] + size * 0.20), outline=color, width=max(2, int(size * 0.09)))
    for i in range(8):
        import math

        angle = i * math.pi / 4
        x0 = c[0] + math.cos(angle) * size * 0.30
        y0 = c[1] + math.sin(angle) * size * 0.30
        x1 = c[0] + math.cos(angle) * size * 0.46
        y1 = c[1] + math.sin(angle) * size * 0.46
        draw.line((x0, y0, x1, y1), fill=color, width=max(2, int(size * 0.11)))


def globe_icon(draw: ImageDraw.ImageDraw, x: float, y: float, size: float, color: tuple[int, int, int]) -> None:
    draw.ellipse((x, y, x + size, y + size), outline=color, width=max(2, int(size * 0.08)))
    draw.ellipse((x + size * 0.28, y, x + size * 0.72, y + size), outline=color, width=max(2, int(size * 0.08)))
    draw.line((x, y + size / 2, x + size, y + size / 2), fill=color, width=max(2, int(size * 0.08)))


def rules_icon(draw: ImageDraw.ImageDraw, x: float, y: float, size: float, color: tuple[int, int, int]) -> None:
    draw.line((x + size * 0.30, y + size * 0.10, x + size * 0.30, y + size * 0.90), fill=color, width=max(2, int(size * 0.09)))
    draw.line((x + size * 0.30, y + size * 0.34, x + size * 0.80, y + size * 0.12), fill=color, width=max(2, int(size * 0.09)), joint="curve")
    draw.line((x + size * 0.30, y + size * 0.66, x + size * 0.80, y + size * 0.88), fill=color, width=max(2, int(size * 0.09)), joint="curve")
    for cx, cy in ((size * 0.30, size * 0.10), (size * 0.30, size * 0.90), (size * 0.82, size * 0.12), (size * 0.82, size * 0.88)):
        draw.ellipse((x + cx - size * 0.08, y + cy - size * 0.08, x + cx + size * 0.08, y + cy + size * 0.08), fill=color)


def pointer(draw: ImageDraw.ImageDraw, x: float, y: float, scale: float = 1.0) -> None:
    points = [
        (x, y),
        (x + 0.18 * scale, y + 1.0 * scale),
        (x + 0.42 * scale, y + 0.62 * scale),
        (x + 0.72 * scale, y + 0.64 * scale),
    ]
    draw.polygon(points, fill=(255, 255, 255), outline=(20, 20, 28))
    draw.line(points + [points[0]], fill=(20, 20, 28), width=max(2, int(0.04 * scale)))


# ---------------------------------------------------------------------------
# Windows and screens
# ---------------------------------------------------------------------------


def window_frame(
    img: Image.Image,
    box: tuple[float, float, float, float],
    title: str,
    selected: str,
) -> tuple[Image.Image, ImageDraw.ImageDraw, float, float]:
    img = shadow(img, box, 50, 110, (0, 44), 170)
    draw = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    draw.rounded_rectangle(box, radius=50, fill=WINDOW, outline=BORDER, width=2)
    draw.rounded_rectangle((x0, y0, x1, y0 + 112), radius=50, fill=WINDOW_BAR)
    draw.rectangle((x0, y0 + 58, x1, y0 + 112), fill=WINDOW_BAR)
    draw.line((x0, y0 + 112, x1, y0 + 112), fill=BORDER, width=2)

    for i, color in enumerate(((255, 95, 87), (254, 188, 46), (40, 200, 64))):
        cx = x0 + 56 + i * 50
        cy = y0 + 56
        draw.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), fill=color)

    draw.text(((x0 + x1) / 2, y0 + 56), "Profile Picker Settings", font=font(42, "Medium"), fill=(192, 192, 208), anchor="mm")

    draw.rectangle((x0, y0 + 112, x0 + 600, y1 - 50), fill=SIDEBAR)
    draw.rectangle((x0, y0 + 112, x0 + 600, y0 + 150), fill=SIDEBAR)
    draw.rounded_rectangle((x0, y1 - 100, x0 + 600, y1), radius=48, fill=SIDEBAR)
    draw.line((x0 + 600, y0 + 112, x0 + 600, y1), fill=BORDER, width=2)

    items = (("General", "gear"), ("Browsers", "globe"), ("Rules", "rules"))
    for index, (name, icon_name) in enumerate(items):
        iy = y0 + 210 + index * 116
        if name == selected:
            draw.rounded_rectangle((x0 + 42, iy - 12, x0 + 558, iy + 78), radius=18, fill=CARD_HI)
        icon_color = ACCENT if name == selected else MUTED
        if icon_name == "gear":
            gear_icon(draw, x0 + 78, iy + 8, 40, icon_color)
        elif icon_name == "globe":
            globe_icon(draw, x0 + 78, iy + 8, 40, icon_color)
        else:
            rules_icon(draw, x0 + 78, iy + 8, 40, icon_color)
        draw.text(
            (x0 + 144, iy + 34),
            name,
            font=font(42, "Semibold" if name == selected else "Regular"),
            fill=INK if name == selected else MUTED,
            anchor="lm",
        )
    draw.rounded_rectangle(box, radius=50, outline=BORDER, width=2)
    return img, draw, x0 + 600 + 80, y0 + 150


def content_header(
    draw: ImageDraw.ImageDraw,
    x: float,
    y: float,
    width: float,
    title: str,
    subtitle: str,
) -> float:
    draw.text((x, y), title, font=font(80, "Bold"), fill=INK)
    return paragraph(draw, (x, y + 112), subtitle, font(44), MUTED, width, 58)


def draw_rules(img: Image.Image, box: tuple[float, float, float, float]) -> Image.Image:
    img, draw, cx, cy = window_frame(img, box, "Rules", "Rules")
    x0, y0, x1, y1 = box
    content_width = x1 - cx - 80
    y = content_header(
        draw,
        cx,
        cy,
        content_width,
        "Rules",
        "Checked from top to bottom; the first match wins. When nothing matches: Show the picker.",
    )

    rules = (
        ("Links from Slack", "from Slack  →  Brave Browser — Work"),
        ("GitHub", "host *.github.com  →  Brave Browser — Work"),
        ("Client wiki", "URL corp.example/*  →  Google Chrome — Personal"),
    )
    card_y = y + 54
    card_h = 176
    for title, subtitle in rules:
        draw.rounded_rectangle((cx, card_y, cx + content_width, card_y + card_h), radius=18, fill=CARD, outline=(48, 48, 62), width=2)
        draw.rounded_rectangle((cx + 28, card_y + 44, cx + 60, card_y + 76), radius=9, fill=GREEN)
        checkmark(draw, (cx + 28, card_y + 44, cx + 60, card_y + 76))
        draw.text((cx + 92, card_y + 38), title, font=font(40, "Semibold"), fill=INK)
        draw.text((cx + 92, card_y + 94), subtitle, font=font(32), fill=MUTED)
        card_y += 194

    # Add / remove buttons
    button_y = card_y + 12
    for label, bx in (("+", cx), ("−", cx + 78)):
        draw.rounded_rectangle((bx, button_y, bx + 64, button_y + 54), radius=12, fill=CARD, outline=(52, 52, 66), width=2)
        draw.text((bx + 32, button_y + 26), label, font=font(34, "Medium"), fill=MUTED, anchor="mm")
    draw.rounded_rectangle((cx + content_width - 150, button_y, cx + content_width, button_y + 54), radius=12, fill=CARD, outline=(52, 52, 66), width=2)
    draw.text((cx + content_width - 75, button_y + 26), "Edit…", font=font(30), fill=INK, anchor="mm")

    test_y = button_y + 100
    test_h = 480
    draw.rounded_rectangle((cx, test_y, cx + content_width, test_y + test_h), radius=20, fill=(22, 22, 29), outline=(48, 48, 62), width=2)
    draw.text((cx + 32, test_y + 28), "Test a link", font=font(36, "Semibold"), fill=INK)

    rows = (
        ("Link", "https://example.com/page"),
        ("Clicked in", "Any app"),
    )
    row_y = test_y + 104
    for label, value in rows:
        draw.text((cx + 40, row_y + 26), label, font=font(30), fill=DIM, anchor="lm")
        field_x = cx + 210
        draw.rounded_rectangle((field_x, row_y, cx + content_width - 40, row_y + 66), radius=12, fill=FIELD, outline=(50, 50, 64), width=2)
        draw.text((field_x + 22, row_y + 33), value, font=font(30), fill=INK, anchor="lm")
        if label == "Clicked in":
            chevron(draw, cx + content_width - 84, row_y + 24, 24, DIM)
        row_y += 96

    draw.text((cx + 40, row_y + 26), "Result", font=font(30), fill=DIM, anchor="lm")
    draw.text((cx + 210, row_y + 26), "Brave Browser — Work", font=font(32, "Semibold"), fill=GREEN, anchor="lm")
    draw.text((cx + 610, row_y + 26), "(rule “GitHub”)", font=font(28), fill=DIM, anchor="lm")
    return img


def draw_browsers(img: Image.Image, box: tuple[float, float, float, float]) -> Image.Image:
    img, draw, cx, cy = window_frame(img, box, "Browsers", "Browsers")
    x0, y0, x1, y1 = box
    content_width = x1 - cx - 80
    y = content_header(
        draw,
        cx,
        cy,
        content_width,
        "Browsers",
        "Choose which browsers and profiles appear in the picker. The list comes from each browser.",
    )

    helper_y = y + 28
    draw.rounded_rectangle((cx, helper_y, cx + content_width, helper_y + 104), radius=16, fill=(22, 34, 28), outline=(45, 75, 58), width=2)
    draw.ellipse((cx + 26, helper_y + 30, cx + 74, helper_y + 78), fill=GREEN)
    checkmark(draw, (cx + 26, helper_y + 30, cx + 74, helper_y + 78))
    draw.text((cx + 96, helper_y + 26), "Helper installed", font=font(34, "Semibold"), fill=INK)
    draw.text((cx + 96, helper_y + 66), "Profiles from Chrome, Brave, Edge and Vivaldi are available.", font=font(26), fill=MUTED)

    sections = (
        ("B", ORANGE, "Brave Browser", (("Personal", "personal@example.com"), ("Work", "work@example.com"))),
        ("C", GREEN, "Google Chrome", (("Personal", "personal@example.com"), ("Client", "client@example.com"))),
        ("E", BLUE, "Microsoft Edge", (("Work", "work@example.com"),)),
        ("V", RED, "Vivaldi", (("Personal", "personal@example.com"),)),
        ("S", TEAL, "Safari", ()),
    )
    row_y = helper_y + 150
    for letter, color, name, profiles in sections:
        circle_avatar(draw, (cx + 28, row_y + 31), 24, letter, color)
        draw.text((cx + 70, row_y + 31), name, font=font(34, "Semibold"), fill=INK, anchor="lm")
        count = f"{len(profiles)} profiles" if profiles else "No profiles"
        draw.text((cx + content_width - 22, row_y + 31), count, font=font(24), fill=FAINT, anchor="rm")
        draw.line((cx, row_y + 66, cx + content_width, row_y + 66), fill=(44, 44, 56), width=2)
        row_y += 70

        for profile_name, email in profiles:
            circle_avatar(draw, (cx + 78, row_y + 46), 22, letter, color)
            draw.text((cx + 118, row_y + 22), profile_name, font=font(30, "Semibold"), fill=INK)
            draw.text((cx + 118, row_y + 58), email, font=font(24), fill=DIM)
            toggle(draw, (cx + content_width - 150, row_y + 22, cx + content_width - 60, row_y + 70), True)
            draw.line((cx, row_y + 92, cx + content_width, row_y + 92), fill=(40, 40, 52), width=1)
            row_y += 92

        if not profiles:
            draw.text((cx + 78, row_y + 46), "Show in picker", font=font(30), fill=INK, anchor="lm")
            toggle(draw, (cx + content_width - 150, row_y + 22, cx + content_width - 60, row_y + 70), True)
            draw.line((cx, row_y + 92, cx + content_width, row_y + 92), fill=(40, 40, 52), width=1)
            row_y += 92
        row_y += 10

    note_y = row_y + 18
    draw.rounded_rectangle((cx, note_y, cx + content_width, note_y + 116), radius=16, fill=(22, 22, 29), outline=(48, 48, 62), width=2)
    draw.ellipse((cx + 30, note_y + 43, cx + 62, note_y + 75), fill=GREEN)
    checkmark(draw, (cx + 30, note_y + 43, cx + 62, note_y + 75))
    draw.text((cx + 86, note_y + 58), "Profiles stay on your Mac. Nothing is uploaded.", font=font(30), fill=MUTED, anchor="lm")
    return img


def draw_general(img: Image.Image, box: tuple[float, float, float, float]) -> Image.Image:
    img, draw, cx, cy = window_frame(img, box, "General", "General")
    x0, y0, x1, y1 = box
    content_width = 1040
    draw.text((cx, cy), "General", font=font(80, "Bold"), fill=INK)

    status_y = cy + 128
    draw.rounded_rectangle((cx, status_y, cx + content_width, status_y + 154), radius=18, fill=(22, 34, 28), outline=(45, 75, 58), width=2)
    draw.ellipse((cx + 28, status_y + 45, cx + 80, status_y + 97), fill=GREEN)
    checkmark(draw, (cx + 28, status_y + 45, cx + 80, status_y + 97))
    draw.text((cx + 104, status_y + 46), "Profile Picker is your default browser", font=font(34, "Semibold"), fill=INK)
    draw.text((cx + 104, status_y + 96), "Links from other apps are routed by your rules.", font=font(28), fill=MUTED)

    section_y = status_y + 210
    draw.text((cx, section_y), "WHEN NO RULE MATCHES", font=font(24, "Semibold"), fill=FAINT)
    draw.rounded_rectangle((cx, section_y + 44, cx + content_width, section_y + 128), radius=14, fill=FIELD, outline=(50, 50, 64), width=2)
    draw.text((cx + 24, section_y + 86), "Show the picker", font=font(32), fill=INK, anchor="lm")
    chevron(draw, cx + content_width - 62, section_y + 73, 24, DIM)

    section_y += 200
    draw.text((cx, section_y), "APP", font=font(24, "Semibold"), fill=FAINT)
    for index, label in enumerate(("Open at login", "Show in menu bar")):
        row_y = section_y + 50 + index * 96
        draw.text((cx + 4, row_y + 26), label, font=font(32), fill=INK, anchor="lm")
        toggle(draw, (cx + content_width - 124, row_y, cx + content_width - 34, row_y + 48), True)

    section_y += 274
    draw.text((cx, section_y), "SETTINGS FILE", font=font(24, "Semibold"), fill=FAINT)
    draw.text((cx + 4, section_y + 48), "Export your rules and settings as JSON.", font=font(28), fill=MUTED)
    draw.rounded_rectangle((cx + 4, section_y + 94, cx + 440, section_y + 168), radius=14, fill=ACCENT)
    draw.text((cx + 222, section_y + 131), "Export Settings…", font=font(30, "Semibold"), fill=(255, 255, 255), anchor="mm")
    draw.rounded_rectangle((cx + 456, section_y + 94, cx + 880, section_y + 168), radius=14, fill=CARD, outline=(58, 58, 74), width=2)
    draw.text((cx + 668, section_y + 131), "Import Settings…", font=font(30, "Semibold"), fill=INK, anchor="mm")

    draw.text((cx + 4, y1 - 92), "Profile Picker 1.0.0 (3)", font=font(26), fill=FAINT)
    return img


def draw_json_card(img: Image.Image, box: tuple[float, float, float, float]) -> Image.Image:
    img = shadow(img, box, 34, 90, (0, 34), 190)
    draw = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    draw.rounded_rectangle(box, radius=34, fill=(15, 15, 22), outline=(66, 66, 86), width=2)
    draw.rounded_rectangle((x0, y0, x1, y0 + 92), radius=34, fill=(24, 24, 34))
    draw.rectangle((x0, y0 + 46, x1, y0 + 92), fill=(24, 24, 34))
    draw.line((x0, y0 + 92, x1, y0 + 92), fill=(58, 58, 76), width=2)
    file_icon(draw, x0 + 34, y0 + 26, 34, ACCENT_2)
    draw.text((x0 + 94, y0 + 46), "Profile Picker Settings.json", font=font(30, "Medium"), fill=INK, anchor="lm")
    draw.rounded_rectangle((x1 - 122, y0 + 26, x1 - 30, y0 + 66), radius=10, fill=(44, 44, 60))
    draw.text((x1 - 76, y0 + 46), "JSON", font=font(22, "Semibold"), fill=ACCENT_2, anchor="mm")

    lines = [
        "{",
        '  "format": "cz.ondralinek.ppicker.settings",',
        '  "version": 1,',
        '  "exportedAt": "2026-11-24T16:00:00Z",',
        '  "settings": {',
        '    "fallback": { "showPicker": {} },',
        '    "hiddenTargets": [',
        '      { "bundleID": "com.apple.Safari" }',
        "    ],",
        '    "rules": [ ... ],',
        '    "showMenuBarIcon": true',
        "  }",
        "}",
    ]
    face = font(36, "Regular", mono=True)
    line_height = 50
    y = y0 + 128
    for line in lines:
        x = x0 + 38
        parts = re.split(r'("(?:[^"\\]|\\.)*")', line)
        for index, part in enumerate(parts):
            if not part:
                continue
            color = (150, 150, 170)
            if part.startswith('"'):
                rest = "".join(parts[index + 1:]).lstrip()
                color = ACCENT_2 if rest.startswith(":") else (158, 206, 106)
            draw.text((x, y), part, font=face, fill=color)
            x += text_width(draw, part, face)
        y += line_height
    return img


def draw_picker(
    img: Image.Image,
    box: tuple[float, float, float, float],
    rows: tuple[tuple[str, str, str, tuple[int, int, int], str], ...],
) -> Image.Image:
    img = shadow(img, box, 42, 105, (0, 40), 185)
    draw = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    draw.rounded_rectangle(box, radius=42, fill=(30, 30, 38), outline=(72, 72, 92), width=2)

    link_icon(img, x0 + 54, y0 + 36, 34, MUTED)
    draw.text((x0 + 142, y0 + 38), "example.com", font=font(48, "Semibold"), fill=INK)
    draw.text((x0 + 142, y0 + 96), "https://example.com", font=font(30), fill=DIM)
    copy_icon(draw, x1 - 88, y0 + 46, 34, MUTED)

    row_y = y0 + 176
    row_h = 210
    for index, (name, subtitle, letter, color, key) in enumerate(rows):
        selected = index == 0
        if selected:
            draw.rounded_rectangle((x0 + 28, row_y, x1 - 28, row_y + row_h - 18), radius=22, fill=(48, 48, 62), outline=(72, 72, 92), width=2)
        circle_avatar(draw, (x0 + 92, row_y + 78), 42, letter, color)
        draw.text((x0 + 168, row_y + 50), name, font=font(42, "Semibold"), fill=INK)
        draw.text((x0 + 168, row_y + 106), subtitle, font=font(30), fill=MUTED)
        draw.rounded_rectangle((x1 - 128, row_y + 50, x1 - 64, row_y + 114), radius=14, fill=(58, 58, 74))
        draw.text((x1 - 96, row_y + 82), key, font=font(30, "Semibold"), fill=(225, 225, 238), anchor="mm")
        row_y += row_h

    bottom_y = y1 - 96
    filter_icon(draw, x0 + 48, bottom_y - 4, 34, MUTED)
    draw.text((x0 + 102, bottom_y + 16), "Just this once", font=font(30), fill=INK, anchor="lm")
    chevron(draw, x0 + 358, bottom_y + 4, 24, DIM)
    draw.text((x1 - 54, bottom_y + 16), "esc to cancel", font=font(26), fill=FAINT, anchor="rm")
    pointer(draw, x1 - 24, y1 - 54, 54)
    return img


def draw_keycaps(img: Image.Image, y: float, center_x: float = W / 2) -> Image.Image:
    draw = ImageDraw.Draw(img)
    keys = (("1", 160), ("2", 160), ("3", 160), ("↑", 160), ("↓", 160), ("Return", 260), ("Esc", 180))
    total = sum(width for _, width in keys) + 20 * (len(keys) - 1)
    x = center_x - total / 2
    face = font(44, "Semibold")
    for label, width in keys:
        draw.rounded_rectangle((x, y, x + width, y + 140), radius=20, fill=(42, 42, 56), outline=(72, 72, 92), width=2)
        draw.line((x + 14, y + 14, x + width - 14, y + 14), fill=(70, 70, 90), width=4)
        draw.text((x + width / 2, y + 78), label, font=face, fill=INK, anchor="mm")
        x += width + 20
    return img


def draw_privacy(img: Image.Image) -> Image.Image:
    draw = ImageDraw.Draw(img)
    card = (3300, 650, 5000, 2350)
    img = shadow(img, card, 110, 120, (0, 46), 180)
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(card, radius=110, fill=(28, 28, 52), outline=(78, 70, 132), width=3)
    # soft inner glow
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((card[0] + 120, card[1] + 80, card[2] - 120, card[3] - 80), fill=(108, 82, 255, 80))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(150)))
    draw = ImageDraw.Draw(img)

    icon = load_icon(900)
    img.alpha_composite(icon, (card[0] + 400, card[1] + 400))
    draw = ImageDraw.Draw(img)

    badge = (card[2] - 300, card[3] - 300, card[2] - 120, card[3] - 120)
    draw.ellipse(badge, fill=ACCENT)
    lock_icon(draw, badge[0] + 32, badge[1] + 34, 116, (255, 255, 255))

    checks = (
        "No account",
        "No analytics",
        "No network requests",
        "Rules stay on your Mac",
    )
    x = 320
    y = 1320
    w = 1050
    h = 150
    for index, label in enumerate(checks):
        cx = x + (index % 2) * (w + 40)
        cy = y + (index // 2) * (h + 40)
        draw.rounded_rectangle((cx, cy, cx + w, cy + h), radius=24, fill=(25, 25, 40), outline=(58, 54, 88), width=2)
        draw.ellipse((cx + 28, cy + 42, cx + 94, cy + 108), fill=(28, 62, 44))
        checkmark(draw, (cx + 28, cy + 42, cx + 94, cy + 108), GREEN)
        draw.text((cx + 122, cy + 76), label, font=font(40, "Semibold"), fill=INK, anchor="lm")

    draw.text((320, 3200), "macOS 26  ·  Apple silicon and Intel  ·  No account required", font=font(32), fill=FAINT)
    return img


# ---------------------------------------------------------------------------
# Composition
# ---------------------------------------------------------------------------


def save(img: Image.Image, name: str) -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    final = img.convert("RGB").resize((FINAL_W, FINAL_H), Image.Resampling.LANCZOS)
    path = os.path.join(OUT_DIR, name)
    final.save(path, "PNG", optimize=True)
    print(f"{path}  {final.width}x{final.height}  {final.mode}")


def screen_picker() -> Image.Image:
    img = background()
    draw = ImageDraw.Draw(img)
    draw_brand(img, draw)
    draw = ImageDraw.Draw(img)
    draw_headline(draw, ["Every link in", "the right profile."], "Pick a browser and profile without breaking your flow.", 176)
    rows = (
        ("Personal", "Brave Browser", "P", GREEN, "1"),
        ("Work", "Brave Browser", "W", PURPLE, "2"),
        ("Client", "Microsoft Edge", "C", BLUE, "3"),
    )
    img = draw_picker(img, (3200, 1300, 5400, 2300), rows)
    return img


def screen_rules() -> Image.Image:
    img = background()
    draw = ImageDraw.Draw(img)
    draw_brand(img, draw)
    draw = ImageDraw.Draw(img)
    draw_headline(draw, ["Rules that match", "how you work."], "Match the app, the host, or the whole URL. The first match wins.")
    img = draw_rules(img, (2700, 700, 5460, 2600))
    return img


def screen_browsers() -> Image.Image:
    img = background()
    draw = ImageDraw.Draw(img)
    draw_brand(img, draw)
    draw = ImageDraw.Draw(img)
    draw_headline(draw, ["Your browsers.", "Your profiles."], "Use the profiles you already have. Hide the ones you do not need.")
    img = draw_browsers(img, (2700, 700, 5460, 2480))
    return img


def screen_keyboard() -> Image.Image:
    img = background()
    draw = ImageDraw.Draw(img)
    draw_brand(img, draw)
    draw = ImageDraw.Draw(img)
    draw_headline(draw, ["One keystroke.", "Done."], "1–9, arrows, Return, Esc. Hold ⌥ Option to force the picker.", 180)
    rows = (
        ("Personal", "Brave Browser", "P", GREEN, "1"),
        ("Work", "Chrome", "W", PURPLE, "2"),
        ("Client", "Edge", "C", BLUE, "3"),
    )
    img = draw_picker(img, (3200, 1000, 5400, 2000), rows)
    img = draw_keycaps(img, 2100, 4300)
    return img


def screen_settings_file() -> Image.Image:
    img = background()
    draw = ImageDraw.Draw(img)
    draw_brand(img, draw)
    draw = ImageDraw.Draw(img)
    draw_headline(draw, ["Take your rules", "with you."], "Export and import settings as JSON — move them to another Mac or keep a backup.", sub_width=1950)
    img = draw_general(img, (2500, 700, 4800, 2380))
    img = draw_json_card(img, (4300, 1450, 5600, 2550))
    return img


def screen_privacy() -> Image.Image:
    img = background()
    draw = ImageDraw.Draw(img)
    draw_brand(img, draw)
    draw = ImageDraw.Draw(img)
    draw_headline(draw, ["Private by", "design."], "No tracking layer. No cloud account. Just your rules, on your Mac.")
    img = draw_privacy(img)
    return img


def main() -> None:
    save(screen_picker(), "01-picker.png")
    save(screen_rules(), "02-rules.png")
    save(screen_browsers(), "03-browsers.png")
    save(screen_keyboard(), "04-keyboard.png")
    save(screen_settings_file(), "05-settings-file.png")
    save(screen_privacy(), "06-privacy.png")


if __name__ == "__main__":
    main()
