from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from models.yolo import YOLODetector


IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def collect_images(root: Path, limit_per_folder: int) -> list[Path]:
    folders = sorted(path for path in root.iterdir() if path.is_dir())
    paths: list[Path] = []
    if not folders:
        folders = [root]

    for folder in folders:
        images = sorted(path for path in folder.iterdir() if path.suffix.lower() in IMAGE_EXTENSIONS)
        if limit_per_folder > 0 and len(images) > limit_per_folder:
            step = len(images) / limit_per_folder
            images = [images[int(index * step)] for index in range(limit_per_folder)]
        paths.extend(images)
    return paths


def box_area_ratio(box: list[int], image_size: tuple[int, int]) -> float:
    width, height = image_size
    x1, y1, x2, y2 = box
    return max(0, x2 - x1) * max(0, y2 - y1) / max(1, width * height)


def draw_preview(rows: list[dict[str, Any]], output_path: Path) -> None:
    tile_w, tile_h = 150, 190
    cols = 6
    rows_count = (len(rows) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tile_w, max(1, rows_count) * tile_h), "white")

    for index, row in enumerate(rows):
        image = Image.open(row["path"]).convert("RGB")
        width, height = image.size
        image.thumbnail((tile_w, tile_h - 34), Image.Resampling.LANCZOS)
        tile = Image.new("RGB", (tile_w, tile_h), "white")
        tile.paste(image, ((tile_w - image.width) // 2, 28))

        draw = ImageDraw.Draw(tile)
        scale_x = image.width / width
        scale_y = image.height / height
        offset_x = (tile_w - image.width) // 2
        offset_y = 28
        x1, y1, x2, y2 = row["box"]
        draw.rectangle(
            (
                offset_x + x1 * scale_x,
                offset_y + y1 * scale_y,
                offset_x + x2 * scale_x,
                offset_y + y2 * scale_y,
            ),
            outline=(255, 0, 0),
            width=3,
        )
        draw.text(
            (3, 3),
            f"{row['expected']}->{row['class_name']} {row['method']}",
            fill=(0, 0, 0),
        )

        sheet.paste(tile, ((index % cols) * tile_w, (index // cols) * tile_h))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, "JPEG", quality=92)


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit YOLO product detection on ecommerce image folders.")
    parser.add_argument(
        "--root",
        default=str(Path.home() / "Desktop" / "mobile database" / "ecommerce products"),
        help="Root folder containing product category folders.",
    )
    parser.add_argument("--weights", default=str(PROJECT_DIR / "weights" / "best.pt"))
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--limit-per-folder", type=int, default=36)
    parser.add_argument("--output-json", default=str(BASE_DIR / "results" / "debug" / "yolo_product_audit.json"))
    parser.add_argument("--output-preview", default=str(BASE_DIR / "results" / "debug" / "yolo_product_audit.jpg"))
    args = parser.parse_args()

    root = Path(args.root)
    detector = YOLODetector(args.weights, device=args.device)
    paths = collect_images(root, args.limit_per_folder)
    rows: list[dict[str, Any]] = []

    for path in paths:
        expected = path.parent.name.lower()
        boxes = detector.get_bounding_boxes(detector.detect(str(path)))
        selected = detector.select_best_garment_box(boxes, str(path), expected)
        method = "yolo"
        if selected is None:
            selected = detector.foreground_fallback_box(str(path))
            method = "foreground" if selected else "full_image"

        image_size = Image.open(path).size
        if selected:
            box = selected["box"]
            class_name = selected["class_name"]
            confidence = float(selected.get("confidence", 0.0))
        else:
            box = [0, 0, image_size[0] - 1, image_size[1] - 1]
            class_name = "full_image"
            confidence = 0.0

        area = box_area_ratio(box, image_size)
        usable_box = 0.08 <= area <= 0.88
        rows.append(
            {
                "path": str(path),
                "file": path.name,
                "expected": expected,
                "method": method,
                "proposal_count": len(boxes),
                "class_name": str(class_name).lower(),
                "effective_class_name": str(selected.get("effective_class_name", class_name)).lower() if selected else "full_image",
                "category_prior": str(selected.get("category_prior", "")) if selected else "",
                "confidence": round(confidence, 4),
                "box": box,
                "box_area_ratio": round(area, 4),
                "usable_box": usable_box,
            }
        )

    by_expected: dict[str, dict[str, Any]] = {}
    for expected, group in defaultdict(list, ((key, [row for row in rows if row["expected"] == key]) for key in sorted({row["expected"] for row in rows}))).items():
        by_expected[expected] = {
            "count": len(group),
            "usable_box_rate": round(sum(row["usable_box"] for row in group) / max(1, len(group)), 4),
            "yolo_method_rate": round(sum(row["method"] == "yolo" for row in group) / max(1, len(group)), 4),
            "class_counts": dict(Counter(row["class_name"] for row in group)),
            "effective_class_counts": dict(Counter(row["effective_class_name"] for row in group)),
            "avg_box_area": round(sum(row["box_area_ratio"] for row in group) / max(1, len(group)), 4),
        }

    summary = {
        "root": str(root),
        "weights": args.weights,
        "count": len(rows),
        "usable_box_rate": round(sum(row["usable_box"] for row in rows) / max(1, len(rows)), 4),
        "yolo_method_rate": round(sum(row["method"] == "yolo" for row in rows) / max(1, len(rows)), 4),
        "method_counts": dict(Counter(row["method"] for row in rows)),
        "class_counts": dict(Counter(row["class_name"] for row in rows)),
        "effective_class_counts": dict(Counter(row["effective_class_name"] for row in rows)),
        "by_expected": by_expected,
    }

    output_json = Path(args.output_json)
    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps({"summary": summary, "rows": rows}, indent=2), encoding="utf-8")
    draw_preview(rows[:72], Path(args.output_preview))

    print(json.dumps(summary, indent=2))
    print(f"Saved: {output_json}")
    print(f"Preview: {args.output_preview}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
