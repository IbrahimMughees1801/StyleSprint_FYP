from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "app_logos"


ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

IOS_SIZES = {
    "AppIcon-20x20@1x": 20,
    "AppIcon-20x20@2x": 40,
    "AppIcon-20x20@3x": 60,
    "AppIcon-29x29@1x": 29,
    "AppIcon-29x29@2x": 58,
    "AppIcon-29x29@3x": 87,
    "AppIcon-40x40@1x": 40,
    "AppIcon-40x40@2x": 80,
    "AppIcon-40x40@3x": 120,
    "AppIcon-60x60@2x": 120,
    "AppIcon-60x60@3x": 180,
    "AppIcon-76x76@1x": 76,
    "AppIcon-76x76@2x": 152,
    "AppIcon-83.5x83.5@2x": 167,
    "AppIcon-1024x1024@1x": 1024,
}

IOS_CONTENTS = {
    "images": [
        {"size": "20x20", "idiom": "iphone", "filename": "AppIcon-20x20@2x.png", "scale": "2x"},
        {"size": "20x20", "idiom": "iphone", "filename": "AppIcon-20x20@3x.png", "scale": "3x"},
        {"size": "29x29", "idiom": "iphone", "filename": "AppIcon-29x29@1x.png", "scale": "1x"},
        {"size": "29x29", "idiom": "iphone", "filename": "AppIcon-29x29@2x.png", "scale": "2x"},
        {"size": "29x29", "idiom": "iphone", "filename": "AppIcon-29x29@3x.png", "scale": "3x"},
        {"size": "40x40", "idiom": "iphone", "filename": "AppIcon-40x40@2x.png", "scale": "2x"},
        {"size": "40x40", "idiom": "iphone", "filename": "AppIcon-40x40@3x.png", "scale": "3x"},
        {"size": "60x60", "idiom": "iphone", "filename": "AppIcon-60x60@2x.png", "scale": "2x"},
        {"size": "60x60", "idiom": "iphone", "filename": "AppIcon-60x60@3x.png", "scale": "3x"},
        {"size": "20x20", "idiom": "ipad", "filename": "AppIcon-20x20@1x.png", "scale": "1x"},
        {"size": "20x20", "idiom": "ipad", "filename": "AppIcon-20x20@2x.png", "scale": "2x"},
        {"size": "29x29", "idiom": "ipad", "filename": "AppIcon-29x29@1x.png", "scale": "1x"},
        {"size": "29x29", "idiom": "ipad", "filename": "AppIcon-29x29@2x.png", "scale": "2x"},
        {"size": "40x40", "idiom": "ipad", "filename": "AppIcon-40x40@1x.png", "scale": "1x"},
        {"size": "40x40", "idiom": "ipad", "filename": "AppIcon-40x40@2x.png", "scale": "2x"},
        {"size": "76x76", "idiom": "ipad", "filename": "AppIcon-76x76@1x.png", "scale": "1x"},
        {"size": "76x76", "idiom": "ipad", "filename": "AppIcon-76x76@2x.png", "scale": "2x"},
        {"size": "83.5x83.5", "idiom": "ipad", "filename": "AppIcon-83.5x83.5@2x.png", "scale": "2x"},
        {"size": "1024x1024", "idiom": "ios-marketing", "filename": "AppIcon-1024x1024@1x.png", "scale": "1x"},
    ],
    "info": {"version": 1, "author": "xcode"},
}


def poly(points: list[tuple[float, float]]) -> list[tuple[int, int]]:
    return [(round(x), round(y)) for x, y in points]


def make_circle_gradient(size: int, circle_bbox: tuple[int, int, int, int]) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pixels = layer.load()
    left, top, right, bottom = circle_bbox
    width = right - left
    height = bottom - top

    c1 = (207, 166, 209)
    c2 = (178, 128, 190)
    c3 = (229, 193, 205)

    for y in range(top, bottom):
        for x in range(left, right):
            nx = (x - left) / max(width, 1)
            ny = (y - top) / max(height, 1)
            mix = (nx * 0.4) + (ny * 0.6)
            r = int(c1[0] * (1 - mix) + c2[0] * mix)
            g = int(c1[1] * (1 - mix) + c2[1] * mix)
            b = int(c1[2] * (1 - mix) + c2[2] * mix)
            highlight = max(0, 1 - ((nx - 0.18) ** 2 + (ny - 0.15) ** 2) * 4)
            r = int(r * (1 - highlight * 0.16) + c3[0] * highlight * 0.16)
            g = int(g * (1 - highlight * 0.16) + c3[1] * highlight * 0.16)
            b = int(b * (1 - highlight * 0.16) + c3[2] * highlight * 0.16)
            pixels[x, y] = (r, g, b, 255)

    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse(circle_bbox, fill=255)
    layer.putalpha(mask)
    return layer


def create_icon(size: int = 1024) -> Image.Image:
    scale = 4
    canvas = size * scale
    img = Image.new("RGBA", (canvas, canvas), (249, 249, 255, 255))
    draw = ImageDraw.Draw(img)

    def s(value: float) -> float:
        return value * scale

    circle = tuple(round(s(v)) for v in (118, 112, 906, 900))
    shadow = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(circle, fill=(7, 2, 53, 42))
    shadow = shadow.filter(ImageFilter.GaussianBlur(s(18)))
    img.alpha_composite(shadow)
    img.alpha_composite(make_circle_gradient(canvas, circle))

    navy = (68, 31, 205, 255)
    white = (255, 255, 255, 255)

    left_shirt = poly(
        [
            (s(272), s(332)),
            (s(408), s(242)),
            (s(528), s(222)),
            (s(556), s(282)),
            (s(618), s(307)),
            (s(546), s(646)),
            (s(528), s(792)),
            (s(364), s(792)),
            (s(346), s(488)),
            (s(306), s(548)),
            (s(214), s(426)),
        ]
    )
    right_shirt = poly(
        [
            (s(590), s(252)),
            (s(730), s(292)),
            (s(810), s(408)),
            (s(712), s(504)),
            (s(670), s(470)),
            (s(636), s(790)),
            (s(498), s(790)),
            (s(528), s(625)),
            (s(570), s(462)),
        ]
    )
    bolt = poly(
        [
            (s(548), s(282)),
            (s(507), s(510)),
            (s(558), s(516)),
            (s(476), s(754)),
            (s(594), s(528)),
            (s(542), s(520)),
            (s(608), s(292)),
        ]
    )

    draw.polygon(left_shirt, fill=white)
    draw.polygon(right_shirt, fill=navy)
    draw.polygon(bolt, fill=(249, 249, 255, 255))

    # Single clean neck cutout, matching the rounded notch in the reference.
    draw.ellipse(
        [round(s(476)), round(s(224)), round(s(590)), round(s(346))],
        fill=(200, 156, 203, 255),
    )

    return img.resize((size, size), Image.Resampling.LANCZOS).convert("RGBA")


def save_png(img: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.resize((size, size), Image.Resampling.LANCZOS).save(path, "PNG")


def update_web_manifest() -> None:
    manifest_path = ROOT / "web" / "manifest.json"
    if not manifest_path.exists():
        return
    manifest = json.loads(manifest_path.read_text())
    manifest["name"] = "StyleSprint"
    manifest["short_name"] = "StyleSprint"
    manifest["icons"] = [
        {
            "src": "icons/Icon-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "maskable any",
        },
        {
            "src": "icons/Icon-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "maskable any",
        },
    ]
    manifest_path.write_text(json.dumps(manifest, indent=2))


def main() -> None:
    base = create_icon(1024)
    OUT.mkdir(exist_ok=True)

    base.save(OUT / "stylesprint_logo_1024.png", "PNG")
    for size in [512, 192, 144, 96, 72, 48]:
        save_png(base, OUT / f"icon_{size}x{size}.png", size)

    for folder, size in ANDROID_SIZES.items():
        save_png(base, OUT / "android" / folder / "ic_launcher.png", size)
        save_png(base, ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png", size)

    ios_source = OUT / "ios"
    ios_dest = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, size in IOS_SIZES.items():
        save_png(base, ios_source / f"{name}.png", size)
        save_png(base, ios_dest / f"{name}.png", size)
    ios_dest.mkdir(parents=True, exist_ok=True)
    (ios_dest / "Contents.json").write_text(json.dumps(IOS_CONTENTS, indent=2))

    save_png(base, ROOT / "web" / "icons" / "Icon-192.png", 192)
    save_png(base, ROOT / "web" / "icons" / "Icon-512.png", 512)
    save_png(base, ROOT / "web" / "icons" / "Icon-maskable-192.png", 192)
    save_png(base, ROOT / "web" / "icons" / "Icon-maskable-512.png", 512)
    save_png(base, ROOT / "web" / "favicon.png", 48)
    update_web_manifest()

    print(f"Generated launcher icons from reference into {OUT}")
    print("Installed Android, iOS, and web app icon assets.")


if __name__ == "__main__":
    main()
