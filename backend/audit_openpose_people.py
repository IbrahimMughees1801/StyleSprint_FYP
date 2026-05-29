from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageDraw

BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from api_server import CONFIG
from models.OpenPose import OpenPoseRunner
from models.helper import sanitize_openpose_json


IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
CORE = [(1, "neck"), (2, "right_shoulder"), (5, "left_shoulder"), (9, "right_hip"), (12, "left_hip")]
ARMS = [(3, "right_elbow"), (4, "right_wrist"), (6, "left_elbow"), (7, "left_wrist")]


def collect_images(root: Path, limit: int) -> list[Path]:
    images = sorted(path for path in root.iterdir() if path.suffix.lower() in IMAGE_EXTENSIONS)
    if limit > 0 and len(images) > limit:
        step = len(images) / limit
        images = [images[int(index * step)] for index in range(limit)]
    return images


def pose_stats(json_path: Path, image_size: tuple[int, int]) -> dict[str, Any]:
    if not json_path.exists():
        return {"available": False, "score": 0, "notes": "missing_json"}

    payload = json.loads(json_path.read_text(encoding="utf-8"))
    people = payload.get("people", [])
    if not people:
        return {"available": False, "score": 0, "notes": "no_people", "people": 0}

    points = np.array(people[0].get("pose_keypoints_2d", []), dtype=np.float32).reshape((-1, 3))
    confidence = points[:, 2] if len(points) else np.array([], dtype=np.float32)
    confident = confidence > 0.05
    missing_core = [name for index, name in CORE if index >= len(points) or points[index, 2] <= 0.05]
    missing_arms = [name for index, name in ARMS if index >= len(points) or points[index, 2] <= 0.05]

    if confident.any():
        visible = points[confident]
        x1, y1 = visible[:, 0].min(), visible[:, 1].min()
        x2, y2 = visible[:, 0].max(), visible[:, 1].max()
        bbox = [round(float(x1), 2), round(float(y1), 2), round(float(x2), 2), round(float(y2), 2)]
        area_ratio = float((x2 - x1) * (y2 - y1) / max(1, image_size[0] * image_size[1]))
    else:
        bbox = None
        area_ratio = 0.0

    score = 100
    notes = []
    confident_count = int(confident.sum())
    if confident_count < 10:
        score -= 20
        notes.append("few_keypoints")
    elif confident_count < 12:
        score -= 8
        notes.append("moderate_keypoints")
    if missing_core:
        score -= len(missing_core) * 10
        notes.append("missing_core")
    if len(missing_arms) >= 3:
        score -= 5
        notes.append("weak_arms")
    if not 0.04 <= area_ratio <= 0.75:
        score -= 10
        notes.append("odd_pose_area")

    return {
        "available": True,
        "people": len(people),
        "score": max(0, score),
        "notes": ",".join(notes) or "clean",
        "confident_keypoints": confident_count,
        "mean_confidence": round(float(confidence.mean()), 4) if len(confidence) else 0.0,
        "missing_core": missing_core,
        "missing_arms": missing_arms,
        "bbox": bbox,
        "area_ratio": round(area_ratio, 4),
    }


def draw_preview(rows: list[dict[str, Any]], output_path: Path) -> None:
    tile_w, tile_h = 180, 240
    cols = 5
    sheet = Image.new("RGB", (cols * tile_w, ((len(rows) + cols - 1) // cols) * tile_h), "white")
    for index, row in enumerate(rows):
        rendered = Path(row["rendered_path"])
        source = rendered if rendered.exists() else Path(row["image_path"])
        image = Image.open(source).convert("RGB")
        image.thumbnail((tile_w, tile_h - 30), Image.Resampling.LANCZOS)
        tile = Image.new("RGB", (tile_w, tile_h), "white")
        tile.paste(image, ((tile_w - image.width) // 2, 28))
        draw = ImageDraw.Draw(tile)
        draw.text((4, 4), f"{row['file']} {row['score']}", fill=(0, 0, 0))
        sheet.paste(tile, ((index % cols) * tile_w, (index // cols) * tile_h))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, "JPEG", quality=92)


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit OpenPose on local person images.")
    parser.add_argument("--root", default=str(Path.home() / "Desktop" / "mobile database" / "Person Images"))
    parser.add_argument("--limit", type=int, default=12)
    parser.add_argument("--work-dir", default=str(BASE_DIR / "results" / "openpose_audit"))
    parser.add_argument("--output-json", default=str(BASE_DIR / "results" / "debug" / "openpose_people_audit.json"))
    parser.add_argument("--output-preview", default=str(BASE_DIR / "results" / "debug" / "openpose_people_audit.jpg"))
    args = parser.parse_args()

    root = Path(args.root)
    work_dir = Path(args.work_dir)
    image_dir = work_dir / "image"
    render_dir = work_dir / "openpose_img"
    json_dir = work_dir / "openpose_json"
    image_dir.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, Any]] = []

    for source in collect_images(root, args.limit):
        image_path = image_dir / source.name
        Image.open(source).convert("RGB").resize((768, 1024), Image.Resampling.BILINEAR).save(image_path, "JPEG")
        OpenPoseRunner(CONFIG["openpose_root"], str(image_path), str(render_dir), str(json_dir)).run()
        json_path = json_dir / f"{image_path.stem}_keypoints.json"
        sanitized = sanitize_openpose_json(json_path, (768, 1024))
        stats = pose_stats(json_path, (768, 1024))
        rendered_path = render_dir / f"{image_path.stem}_rendered.png"
        rows.append(
            {
                "file": source.name,
                "image_path": str(image_path),
                "json_path": str(json_path),
                "rendered_path": str(rendered_path),
                "sanitized": sanitized,
                **stats,
            }
        )

    summary = {
        "count": len(rows),
        "avg_score": round(sum(row["score"] for row in rows) / max(1, len(rows)), 2),
        "strong_rate": round(sum(row["score"] >= 85 for row in rows) / max(1, len(rows)), 4),
        "avg_confident_keypoints": round(sum(row.get("confident_keypoints", 0) for row in rows) / max(1, len(rows)), 2),
        "sanitized_count": sum(1 for row in rows if row["sanitized"]),
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
