from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


BASE_DIR = Path(__file__).resolve().parent
TEMP_DIR = BASE_DIR / "temp_uploads"
DEFAULT_OUTPUT = BASE_DIR / "datasets" / "pf_afn_finetune" / "self_recon_v1"

GRAPHONOMY_LABEL_COLORS = {
    (0, 0, 0): 0,
    (128, 0, 0): 1,
    (255, 0, 0): 2,
    (0, 85, 0): 3,
    (170, 0, 51): 4,
    (255, 85, 0): 5,
    (0, 0, 85): 6,
    (0, 119, 221): 7,
    (85, 85, 0): 8,
    (0, 85, 85): 9,
    (85, 51, 0): 10,
    (52, 86, 128): 11,
    (0, 128, 0): 12,
    (0, 0, 255): 13,
    (51, 170, 221): 14,
    (0, 255, 255): 15,
    (85, 255, 170): 16,
    (170, 255, 85): 17,
    (255, 255, 0): 18,
    (255, 170, 0): 19,
}


def _label_map(path: Path, size: tuple[int, int]) -> np.ndarray:
    image = Image.open(path)
    if image.mode == "L":
        labels = np.array(image.resize(size, Image.Resampling.NEAREST))
        return np.where(labels <= 19, labels, 0).astype(np.uint8)

    rgb = np.array(image.convert("RGB").resize(size, Image.Resampling.NEAREST))
    labels = np.zeros(rgb.shape[:2], dtype=np.uint8)
    for color, label in GRAPHONOMY_LABEL_COLORS.items():
        labels[(rgb == color).all(axis=-1)] = label
    return labels


def _largest_component(mask: np.ndarray) -> np.ndarray:
    try:
        import cv2

        count, labels, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)
        if count <= 1:
            return mask
        largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        cleaned = labels == largest
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
        cleaned = cv2.morphologyEx(cleaned.astype(np.uint8), cv2.MORPH_CLOSE, kernel) > 0
        return cleaned
    except Exception:
        return mask


def _clean_shirt_mask(mask: np.ndarray, person: Image.Image) -> np.ndarray:
    cleaned = _largest_component(mask)
    image = np.array(person.convert("RGB"))
    luminance = (
        image[:, :, 0].astype(np.float32) * 0.299
        + image[:, :, 1].astype(np.float32) * 0.587
        + image[:, :, 2].astype(np.float32) * 0.114
    )
    bbox = _bbox(cleaned)
    if bbox is None:
        return cleaned

    x1, y1, x2, y2 = bbox
    height = y2 - y1 + 1
    yy = np.arange(cleaned.shape[0])[:, None]
    top_region = yy <= y1 + int(height * 0.28)
    dark_top = cleaned & top_region & (luminance < 70)
    if dark_top.sum() > max(20, cleaned.sum() * 0.015):
        cleaned = cleaned & ~dark_top
        cleaned = _largest_component(cleaned)
    return cleaned


def _bbox(mask: np.ndarray) -> tuple[int, int, int, int] | None:
    if not mask.any():
        return None
    ys, xs = np.where(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def _save_mask(mask: np.ndarray, path: Path) -> None:
    Image.fromarray((mask.astype(np.uint8) * 255), mode="L").save(path)


def _paste_centered_product(
    person: Image.Image,
    mask: np.ndarray,
    bbox: tuple[int, int, int, int],
    size: tuple[int, int],
) -> tuple[Image.Image, Image.Image, dict]:
    x1, y1, x2, y2 = bbox
    crop = person.crop((x1, y1, x2 + 1, y2 + 1))
    crop_mask = Image.fromarray((mask[y1 : y2 + 1, x1 : x2 + 1].astype(np.uint8) * 255), mode="L")

    canvas_w, canvas_h = size
    target_w = int(canvas_w * 0.78)
    target_h = int(canvas_h * 0.76)
    crop_w, crop_h = crop.size
    scale = min(target_w / max(1, crop_w), target_h / max(1, crop_h))
    resized = (max(1, int(crop_w * scale)), max(1, int(crop_h * scale)))

    crop = crop.resize(resized, Image.Resampling.BICUBIC)
    crop_mask = crop_mask.resize(resized, Image.Resampling.NEAREST)
    paste_x = (canvas_w - resized[0]) // 2
    paste_y = max(0, int(canvas_h * 0.10) + (target_h - resized[1]) // 2)

    cloth = Image.new("RGB", size, (255, 255, 255))
    edge = Image.new("L", size, 0)
    cloth.paste(crop, (paste_x, paste_y), crop_mask)
    edge.paste(crop_mask, (paste_x, paste_y))

    return cloth, edge, {"paste": [paste_x, paste_y, resized[0], resized[1]]}


def _target_cloth(person: Image.Image, mask: np.ndarray) -> Image.Image:
    person_array = np.array(person.convert("RGB"))
    background = np.full_like(person_array, 128)
    output = np.where(mask[:, :, None], person_array, background)
    return Image.fromarray(output.astype(np.uint8), mode="RGB")


def _overlay(person: Image.Image, mask: np.ndarray) -> Image.Image:
    image = person.convert("RGB")
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    color = Image.new("RGBA", image.size, (0, 220, 255, 100))
    alpha = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    overlay.paste(color, (0, 0), alpha)
    return Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")


def _sample_id(person_path: Path) -> str:
    digest = hashlib.sha1(str(person_path).encode("utf-8")).hexdigest()[:8]
    return f"{person_path.stem}_{digest}"


def _make_preview(records: list[dict], output_path: Path, max_rows: int = 8) -> None:
    if not records:
        return
    tile_w, tile_h = 192, 256
    labels_h = 18
    cols = 5
    rows = min(len(records), max_rows)
    preview = Image.new("RGB", (cols * tile_w, rows * (tile_h + labels_h)), (235, 235, 235))
    draw = ImageDraw.Draw(preview)
    keys = ["person", "cloth", "edge", "target_cloth", "overlay"]
    for row_index, record in enumerate(records[:rows]):
        for col_index, key in enumerate(keys):
            path = Path(record[key])
            image = Image.open(path).convert("RGB").resize((tile_w, tile_h), Image.Resampling.BICUBIC)
            x = col_index * tile_w
            y = row_index * (tile_h + labels_h)
            preview.paste(image, (x, y + labels_h))
            draw.text((x + 4, y + 3), key, fill=(0, 0, 0))
    preview.save(output_path, "JPEG", quality=92)


def _dedupe_key(person: Image.Image, mask: np.ndarray) -> str:
    person_small = person.resize((48, 64), Image.Resampling.BICUBIC)
    mask_small = Image.fromarray((mask.astype(np.uint8) * 255), mode="L").resize(
        (48, 64),
        Image.Resampling.NEAREST,
    )
    digest = hashlib.sha1()
    digest.update(person_small.tobytes())
    digest.update(mask_small.tobytes())
    return digest.hexdigest()


def build_dataset(
    output_root: Path,
    size: tuple[int, int],
    max_samples: int | None,
    dedupe: bool,
    include_prefix: str | None,
    include_stems: set[str] | None,
    preview_rows: int,
) -> list[dict]:
    image_dir = TEMP_DIR / "image"
    parse_dir = TEMP_DIR / "image-parse-v3"
    output_root.mkdir(parents=True, exist_ok=True)

    records: list[dict] = []
    seen: set[str] = set()
    for person_path in sorted(image_dir.glob("*_person.jpg")):
        if include_prefix and not person_path.stem.startswith(include_prefix):
            continue
        if include_stems is not None and person_path.stem not in include_stems:
            continue
        if max_samples is not None and len(records) >= max_samples:
            break

        parse_path = parse_dir / person_path.name.replace(".jpg", ".png")
        gray_parse_path = parse_dir / person_path.name.replace(".jpg", "_gray.png")
        if not parse_path.exists() and gray_parse_path.exists():
            parse_path = gray_parse_path
        if not parse_path.exists():
            continue

        person = Image.open(person_path).convert("RGB").resize(size, Image.Resampling.BICUBIC)
        labels = _label_map(parse_path, size)
        shirt_mask = _clean_shirt_mask(labels == 5, person)
        coverage = float(shirt_mask.mean())
        bbox = _bbox(shirt_mask)
        if bbox is None or coverage < 0.04 or coverage > 0.45:
            continue
        key = _dedupe_key(person, shirt_mask)
        if dedupe and key in seen:
            continue
        seen.add(key)

        sample_id = _sample_id(person_path)
        sample_dir = output_root / "samples" / sample_id
        sample_dir.mkdir(parents=True, exist_ok=True)

        cloth, edge, product_stats = _paste_centered_product(person, shirt_mask, bbox, size)
        target = _target_cloth(person, shirt_mask)
        overlay = _overlay(person, shirt_mask)

        paths = {
            "person": sample_dir / "person.jpg",
            "cloth": sample_dir / "cloth.jpg",
            "edge": sample_dir / "edge.png",
            "target_cloth": sample_dir / "target_cloth.jpg",
            "target_edge": sample_dir / "target_edge.png",
            "overlay": sample_dir / "overlay.jpg",
        }
        person.save(paths["person"], "JPEG", quality=95)
        cloth.save(paths["cloth"], "JPEG", quality=95)
        edge.save(paths["edge"])
        target.save(paths["target_cloth"], "JPEG", quality=95)
        _save_mask(shirt_mask, paths["target_edge"])
        overlay.save(paths["overlay"], "JPEG", quality=92)

        record = {
            "id": sample_id,
            "source_person": str(person_path),
            "source_parse": str(parse_path),
            "coverage": round(coverage, 4),
            "target_bbox": list(bbox),
            **product_stats,
            **{key: str(path) for key, path in paths.items()},
        }
        records.append(record)

    manifest_path = output_root / "manifest.jsonl"
    with manifest_path.open("w", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record) + "\n")

    summary = {
        "sample_count": len(records),
        "size": list(size),
        "manifest": str(manifest_path),
        "coverage_min": min((record["coverage"] for record in records), default=None),
        "coverage_max": max((record["coverage"] for record in records), default=None),
    }
    (output_root / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    _make_preview(records, output_root / "preview.jpg", preview_rows)
    return records


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a small PF-AFN self-reconstruction fine-tune dataset.")
    parser.add_argument("--output-root", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--width", type=int, default=192)
    parser.add_argument("--height", type=int, default=256)
    parser.add_argument("--max-samples", type=int, default=None)
    parser.add_argument("--no-dedupe", action="store_true")
    parser.add_argument("--include-prefix", default=None)
    parser.add_argument(
        "--include-stems",
        default=None,
        help="Comma-separated processed person stems, for example ft_person_images_person2_person.",
    )
    parser.add_argument("--preview-rows", type=int, default=8)
    args = parser.parse_args()

    output_root = Path(args.output_root)
    include_stems = None
    if args.include_stems:
        include_stems = {stem.strip() for stem in args.include_stems.split(",") if stem.strip()}
    records = build_dataset(
        output_root,
        (args.width, args.height),
        args.max_samples,
        not args.no_dedupe,
        args.include_prefix,
        include_stems,
        args.preview_rows,
    )
    print(json.dumps({"output_root": str(output_root), "sample_count": len(records)}, indent=2))
    if not records:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
