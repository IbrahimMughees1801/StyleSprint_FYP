from __future__ import annotations

import argparse
import json
import random
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw


def _bbox_shape(record: dict[str, Any]) -> tuple[int, int, float]:
    x1, y1, x2, y2 = record["target_bbox"]
    width = int(x2 - x1 + 1)
    height = int(y2 - y1 + 1)
    return width, height, width / max(1, height)


def _load_records(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                records.append(json.loads(line))
    return records


def _write_jsonl(records: list[dict[str, Any]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record) + "\n")


def _image(path_value: str, size: tuple[int, int]) -> Image.Image:
    path = Path(path_value)
    if not path.is_absolute():
        path = Path.cwd() / path
    if not path.exists():
        return Image.new("RGB", size, (235, 235, 235))
    return Image.open(path).convert("RGB").resize(size, Image.Resampling.BICUBIC)


def _preview(records: list[dict[str, Any]], path: Path, rows: int) -> None:
    if not records:
        return
    tile = (160, 213)
    label_h = 18
    keys = ["person", "cloth", "edge", "target_edge", "target_cloth"]
    canvas = Image.new("RGB", (len(keys) * tile[0], min(rows, len(records)) * (tile[1] + label_h)), (235, 235, 235))
    draw = ImageDraw.Draw(canvas)
    for row, record in enumerate(records[:rows]):
        for col, key in enumerate(keys):
            x = col * tile[0]
            y = row * (tile[1] + label_h)
            canvas.paste(_image(record[key], tile), (x, y + label_h))
            draw.text((x + 4, y + 3), key, fill=(0, 0, 0))
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path, "JPEG", quality=92)


def main() -> int:
    parser = argparse.ArgumentParser(description="Curate VITON-HD self-reconstruction samples for upper-body warp tuning.")
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--min-coverage", type=float, default=0.06)
    parser.add_argument("--max-coverage", type=float, default=0.24)
    parser.add_argument("--min-height", type=int, default=45)
    parser.add_argument("--max-height", type=int, default=145)
    parser.add_argument("--min-aspect", type=float, default=0.55)
    parser.add_argument("--max-aspect", type=float, default=1.35)
    parser.add_argument("--max-samples", type=int, default=54)
    parser.add_argument("--seed", type=int, default=23)
    parser.add_argument("--preview-rows", type=int, default=12)
    args = parser.parse_args()

    records = _load_records(Path(args.manifest))
    kept = []
    rejected: dict[str, int] = {}
    for record in records:
        coverage = float(record.get("coverage", 0.0))
        width, height, aspect = _bbox_shape(record)
        reason = None
        if coverage < args.min_coverage or coverage > args.max_coverage:
            reason = "coverage"
        elif height < args.min_height or height > args.max_height:
            reason = "height"
        elif aspect < args.min_aspect or aspect > args.max_aspect:
            reason = "aspect"

        if reason:
            rejected[reason] = rejected.get(reason, 0) + 1
            continue

        kept.append({**record, "target_width": width, "target_height": height, "target_aspect": round(aspect, 4)})

    random.Random(args.seed).shuffle(kept)
    kept = kept[: args.max_samples]

    output_root = Path(args.output_root)
    manifest_path = output_root / "manifest.jsonl"
    summary_path = output_root / "summary.json"
    preview_path = output_root / "preview.jpg"
    _write_jsonl(kept, manifest_path)
    _preview(kept, preview_path, args.preview_rows)

    summary = {
        "source_manifest": args.manifest,
        "total": len(records),
        "kept": len(kept),
        "rejected": rejected,
        "manifest": str(manifest_path),
        "preview": str(preview_path),
        "filters": {
            "coverage": [args.min_coverage, args.max_coverage],
            "height": [args.min_height, args.max_height],
            "aspect": [args.min_aspect, args.max_aspect],
        },
    }
    summary_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return 0 if kept else 1


if __name__ == "__main__":
    raise SystemExit(main())
