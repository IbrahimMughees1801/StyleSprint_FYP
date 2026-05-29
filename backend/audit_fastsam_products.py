from __future__ import annotations

import argparse
import json
import shutil
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any

import cv2
import numpy as np
from PIL import Image, ImageDraw

BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from api_server import clean_cloth_mask
from models.SegmentationSam2 import FastSAMInference
from models.yolo import YOLODetector


IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}


def collect_images(root: Path, limit_per_folder: int) -> list[Path]:
    folders = sorted(path for path in root.iterdir() if path.is_dir()) or [root]
    paths: list[Path] = []
    for folder in folders:
        images = sorted(path for path in folder.iterdir() if path.suffix.lower() in IMAGE_EXTENSIONS)
        if limit_per_folder > 0 and len(images) > limit_per_folder:
            step = len(images) / limit_per_folder
            images = [images[int(index * step)] for index in range(limit_per_folder)]
        paths.extend(images)
    return paths


def mask_stats(mask_path: Path, image_size: tuple[int, int], yolo_box: list[int]) -> dict[str, Any]:
    mask = np.array(Image.open(mask_path).convert("L")) >= 128
    height, width = mask.shape
    if not mask.any():
        return {
            "coverage": 0.0,
            "bbox": None,
            "bbox_fill": 0.0,
            "component_count": 0,
            "largest_component_ratio": 0.0,
            "box_iou": 0.0,
            "inside_yolo_box": 0.0,
            "touches_border": False,
        }

    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)
    component_areas = [int(stats[index, cv2.CC_STAT_AREA]) for index in range(1, count)]
    largest_area = max(component_areas) if component_areas else 0
    ys, xs = np.where(mask)
    bbox = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
    bbox_area = max(1, (bbox[2] - bbox[0] + 1) * (bbox[3] - bbox[1] + 1))
    mask_area = int(mask.sum())

    x1, y1, x2, y2 = yolo_box
    yolo = np.zeros((height, width), dtype=bool)
    x1 = max(0, min(width - 1, int(x1)))
    x2 = max(0, min(width - 1, int(x2)))
    y1 = max(0, min(height - 1, int(y1)))
    y2 = max(0, min(height - 1, int(y2)))
    yolo[y1 : y2 + 1, x1 : x2 + 1] = True
    intersection = int((mask & yolo).sum())
    union = int((mask | yolo).sum())

    return {
        "coverage": round(float(mask.mean()), 4),
        "bbox": bbox,
        "bbox_fill": round(float(mask_area / bbox_area), 4),
        "component_count": max(0, count - 1),
        "largest_component_ratio": round(float(largest_area / max(1, mask_area)), 4),
        "box_iou": round(float(intersection / max(1, union)), 4),
        "inside_yolo_box": round(float(intersection / max(1, mask_area)), 4),
        "touches_border": bool(bbox[0] <= 1 or bbox[1] <= 1 or bbox[2] >= width - 2 or bbox[3] >= height - 2),
    }


def quality_score(stats: dict[str, Any]) -> tuple[int, str]:
    score = 100
    notes = []
    coverage = stats["coverage"]
    if not 0.08 <= coverage <= 0.65:
        score -= 25
        notes.append("coverage_out_of_range")
    if stats["component_count"] > 1:
        score -= min(20, (stats["component_count"] - 1) * 6)
        notes.append("multiple_components")
    if stats["largest_component_ratio"] < 0.96:
        score -= 12
        notes.append("fragmented")
    if stats["bbox_fill"] < 0.35:
        score -= 10
        notes.append("sparse_bbox")
    if stats["inside_yolo_box"] < 0.88:
        score -= 12
        notes.append("outside_yolo_box")
    if stats["touches_border"]:
        score -= 8
        notes.append("touches_border")
    return max(0, score), ",".join(notes) or "clean"


def draw_preview(rows: list[dict[str, Any]], output_path: Path) -> None:
    tile_w, tile_h = 180, 220
    cols = 5
    sheet = Image.new("RGB", (cols * tile_w, ((len(rows) + cols - 1) // cols) * tile_h), "white")
    for index, row in enumerate(rows):
        image = Image.open(row["work_image"]).convert("RGB")
        mask = Image.open(row["mask_path"]).convert("L")
        overlay = image.copy()
        red = Image.new("RGB", image.size, (255, 0, 0))
        overlay.paste(red, (0, 0), mask.point(lambda value: 95 if value >= 128 else 0))
        draw = ImageDraw.Draw(overlay)
        draw.rectangle(row["yolo_box"], outline=(0, 255, 0), width=5)
        overlay.thumbnail((tile_w, tile_h - 30), Image.Resampling.LANCZOS)
        tile = Image.new("RGB", (tile_w, tile_h), "white")
        tile.paste(overlay, ((tile_w - overlay.width) // 2, 26))
        ImageDraw.Draw(tile).text((4, 4), f"{row['file']} {row['score']}", fill=(0, 0, 0))
        sheet.paste(tile, ((index % cols) * tile_w, (index // cols) * tile_h))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, "JPEG", quality=92)


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit FastSAM cloth masks on ecommerce product folders.")
    parser.add_argument("--root", default=str(Path.home() / "Desktop" / "mobile database" / "ecommerce products"))
    parser.add_argument("--limit-per-folder", type=int, default=12)
    parser.add_argument("--yolo-weights", default=str(PROJECT_DIR / "weights" / "best.pt"))
    parser.add_argument("--fastsam-weights", default=str(PROJECT_DIR / "weights" / "FastSAM-s.pt"))
    parser.add_argument("--work-dir", default=str(BASE_DIR / "results" / "fastsam_audit"))
    parser.add_argument("--output-json", default=str(BASE_DIR / "results" / "debug" / "fastsam_product_audit.json"))
    parser.add_argument("--output-preview", default=str(BASE_DIR / "results" / "debug" / "fastsam_product_audit.jpg"))
    args = parser.parse_args()

    work_dir = Path(args.work_dir)
    work_dir.mkdir(parents=True, exist_ok=True)
    yolo = YOLODetector(args.yolo_weights, device="cpu")
    rows: list[dict[str, Any]] = []

    for source_path in collect_images(Path(args.root), args.limit_per_folder):
        expected = source_path.parent.name.lower()
        work_image = work_dir / f"{expected}_{source_path.stem}.jpg"
        Image.open(source_path).convert("RGB").resize((768, 1024), Image.Resampling.BILINEAR).save(work_image, "JPEG")

        boxes = yolo.get_bounding_boxes(yolo.detect(str(work_image)))
        selected = yolo.select_best_garment_box(boxes, str(work_image), expected)
        if selected is None:
            selected = yolo.foreground_fallback_box(str(work_image))
        yolo_box = selected["box"] if selected else [0, 0, 767, 1023]

        mask_path = Path(FastSAMInference(args.fastsam_weights, str(work_image)).run_inference(yolo_box))
        clean_cloth_mask(str(mask_path), str(work_image))
        stats = mask_stats(mask_path, (768, 1024), yolo_box)
        score, notes = quality_score(stats)
        rows.append(
            {
                "path": str(source_path),
                "work_image": str(work_image),
                "file": source_path.name,
                "expected": expected,
                "yolo_class": selected.get("class_name") if selected else None,
                "effective_class": selected.get("effective_class_name") if selected else None,
                "yolo_box": yolo_box,
                "mask_path": str(mask_path),
                "score": score,
                "notes": notes,
                **stats,
            }
        )

    by_expected = {}
    for expected in sorted({row["expected"] for row in rows}):
        group = [row for row in rows if row["expected"] == expected]
        by_expected[expected] = {
            "count": len(group),
            "avg_score": round(sum(row["score"] for row in group) / max(1, len(group)), 2),
            "avg_coverage": round(sum(row["coverage"] for row in group) / max(1, len(group)), 4),
            "clean_rate": round(sum(row["score"] >= 80 for row in group) / max(1, len(group)), 4),
        }

    summary = {
        "count": len(rows),
        "avg_score": round(sum(row["score"] for row in rows) / max(1, len(rows)), 2),
        "clean_rate": round(sum(row["score"] >= 80 for row in rows) / max(1, len(rows)), 4),
        "by_expected": by_expected,
    }
    output_json = Path(args.output_json)
    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps({"summary": summary, "rows": rows}, indent=2), encoding="utf-8")
    draw_preview(rows, Path(args.output_preview))

    print(json.dumps(summary, indent=2))
    print(f"Saved: {output_json}")
    print(f"Preview: {args.output_preview}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
