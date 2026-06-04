#!/usr/bin/env python3
"""Recolour motorhome iPad cutaway assets to match zone palette."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / "loadMate3" / "Assets.xcassets"

# Matches rear band on artwork and AppColors.zonePastelOrange family.
CAB_ORANGE = (253, 175, 110)
# Deeper bike-rack purple (AppColors.zonePurpleDeep #7B3FB8 and tint).
BIKE_PURPLE = (123, 63, 184)
BIKE_PURPLE_LIGHT = (200, 170, 225)

PINK_SOURCES = (
    (255, 229, 234),
    (255, 230, 235),
    (240, 168, 168),
    (240, 160, 160),
    (248, 168, 104),
)

PURPLE_LIGHT_SOURCES = (
    (247, 233, 255),
    (239, 210, 255),
    (235, 208, 255),
    (234, 207, 255),
    (233, 207, 255),
    (237, 209, 255),
    (224, 200, 248),
    (227, 223, 255),
)

PURPLE_ACCENT = (175, 82, 222)


def near(rgb: tuple[int, int, int], target: tuple[int, int, int], tol: int) -> bool:
    return abs(rgb[0] - target[0]) + abs(rgb[1] - target[1]) + abs(rgb[2] - target[2]) <= tol * 3


def matches_any(rgb: tuple[int, int, int], targets: tuple[tuple[int, int, int], ...], tol: int) -> bool:
    return any(near(rgb, t, tol) for t in targets)


def is_near_white(rgb: tuple[int, int, int], threshold: int = 10) -> bool:
    """Skip background pixels that loosely match pink/purple sources."""
    return min(rgb) > 255 - threshold


def blend_toward(
    rgb: tuple[int, int, int],
    target: tuple[int, int, int],
    strength: float,
) -> tuple[int, int, int]:
    return tuple(
        int(round(rgb[i] * (1 - strength) + target[i] * strength))
        for i in range(3)
    )


def is_pink_cab_pixel(x: int, y: int, w: int, h: int, rgb: tuple[int, int, int]) -> bool:
    if x > int(w * 0.30):
        return False
    if is_near_white(rgb):
        return False
    if not matches_any(rgb, PINK_SOURCES, 18):
        return False
    # Salmon/orange rear tones can appear in the cab strip — keep those.
    if rgb[0] > 245 and rgb[1] > 165 and rgb[1] < 185 and rgb[2] < 125:
        return False
    return True


def is_floating_bike_box(x: int, y: int, w: int, h: int, rgb: tuple[int, int, int], alpha: int) -> bool:
    if alpha < 80:
        return False
    if near(rgb, PURPLE_ACCENT, 28):
        return 1080 <= x <= 1410 and 210 <= y <= 400
    if matches_any(rgb, PURPLE_LIGHT_SOURCES, 28):
        return 1090 <= x <= 1405 and 220 <= y <= 395
    return False


def is_bike_rack_pixel(x: int, y: int, w: int, h: int, rgb: tuple[int, int, int], alpha: int) -> bool:
    if alpha < 160 or x < int(w * 0.84):
        return False
    if is_near_white(rgb):
        return False
    if is_floating_bike_box(x, y, w, h, rgb, alpha):
        return False
    return matches_any(rgb, PURPLE_LIGHT_SOURCES, 22) or near(rgb, PURPLE_ACCENT, 22)


def process_image(path: Path, has_bike_rack: bool) -> None:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()

    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            rgb = (r, g, b)

            if is_pink_cab_pixel(x, y, w, h, rgb):
                nr, ng, nb = blend_toward(rgb, CAB_ORANGE, 0.92)
                px[x, y] = (nr, ng, nb, a)
                continue

            if not has_bike_rack:
                continue

            if is_floating_bike_box(x, y, w, h, rgb, a):
                px[x, y] = (255, 255, 255, 0)
                continue

            if is_bike_rack_pixel(x, y, w, h, rgb, a):
                target = BIKE_PURPLE if max(rgb) < 210 else BIKE_PURPLE_LIGHT
                nr, ng, nb = blend_toward(rgb, target, 0.88)
                px[x, y] = (nr, ng, nb, a)

    im.save(path, optimize=True)
    print(f"Updated {path.name}")


def main() -> None:
    assets = [
        ("Motorhome.imageset/Motorhome.png", False),
        ("MotorhomeTow.imageset/MotorhomeTow.png", False),
        ("MotorhomeBike.imageset/MotorhomeBike.png", True),
        ("MotorhomeTowBike.imageset/MotorhomeTowBike.png", True),
    ]
    for rel, has_bike in assets:
        process_image(ROOT / rel, has_bike)


if __name__ == "__main__":
    main()
