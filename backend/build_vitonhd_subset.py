from __future__ import annotations

import argparse
import hashlib
import json
import random
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image, ImageDraw


BASE_DIR = Path(__file__).resolve().parent
DEFAULT_VITON_ROOT = Path(r"C:\Users\muhdi\Desktop\mobile database")
DEFAULT_OUTPUT = BASE_DIR / "datasets" / "viton_hd" / "test_subset"

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


def _json_default(value: Any) -> str:
    if isinstance(value, Path):
        return str(value)
    raise TypeError(f"Cannot serialize {type(value)!r}")


def _read_pairs(path: Path) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            parts = line.strip().split()
            if len(parts) >= 2:
                pairs.append((parts[0], parts[1]))
    return pairs


def _required_split_dirs(split_root: Path) -> dict[str, Path]:
    return {
        "image": split_root / "image",
        "cloth": split_root / "cloth",
        "cloth_mask": split_root / "cloth-mask",
        "parse": split_root / "image-parse-v3",
        "densepose": split_root / "image-densepose",
        "openpose_json": split_root / "openpose_json",
        "openpose_img": split_root / "openpose_img",
        "agnostic": split_root / "agnostic-v3.2",
        "parse_agnostic": split_root / "image-parse-agnostic-v3.2",
    }


def _file_count(path: Path) -> int:
    if not path.exists():
        return 0
    return sum(1 for candidate in path.iterdir() if candidate.is_file())


def _pair_record(split_root: Path, person_name: str, cloth_name: str) -> dict[str, Any]:
    dirs = _required_split_dirs(split_root)
    person_stem = Path(person_name).stem
    return {
        "id": f"{person_stem}__{Path(cloth_name).stem}",
        "person_name": person_name,
        "cloth_name": cloth_name,
        "person": dirs["image"] / person_name,
        "cloth": dirs["cloth"] / cloth_name,
        "cloth_mask": dirs["cloth_mask"] / cloth_name,
        "parse": dirs["parse"] / person_name.replace(".jpg", ".png"),
        "densepose": dirs["densepose"] / person_name,
        "openpose_json": dirs["openpose_json"] / person_name.replace(".jpg", "_keypoints.json"),
        "openpose_img": dirs["openpose_img"] / person_name.replace(".jpg", "_rendered.png"),
        "agnostic": dirs["agnostic"] / person_name,
        "parse_agnostic": dirs["parse_agnostic"] / person_name.replace(".jpg", ".png"),
        "product_category": "tshirt",
        "product_type": "top",
    }


def _existing_required(record: dict[str, Any], keys: list[str]) -> bool:
    return all(Path(record[key]).exists() for key in keys)


def _label_map(path: Path, size: tuple[int, int]) -> np.ndarray:
    image = Image.open(path)
    if image.mode in {"L", "P"}:
        labels = np.array(image.resize(size, Image.Resampling.NEAREST))
        return np.where(labels <= 19, labels, 0).astype(np.uint8)

    rgb = np.array(image.convert("RGB").resize(size, Image.Resampling.NEAREST))
    labels = np.zeros(rgb.shape[:2], dtype=np.uint8)
    for color, label in GRAPHONOMY_LABEL_COLORS.items():
        target = np.array(color, dtype=np.int16)
        close = np.abs(rgb.astype(np.int16) - target).max(axis=-1) <= 2
        labels[close] = label
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


def _bbox(mask: np.ndarray) -> list[int] | None:
    if not mask.any():
        return None
    ys, xs = np.where(mask)
    return [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]


def _target_cloth(person: Image.Image, mask: np.ndarray) -> Image.Image:
    person_array = np.array(person.convert("RGB"))
    background = np.full_like(person_array, 128)
    output = np.where(mask[:, :, None], person_array, background)
    return Image.fromarray(output.astype(np.uint8), mode="RGB")


def _sample_id(name: str) -> str:
    digest = hashlib.sha1(name.encode("utf-8")).hexdigest()[:8]
    return f"vitonhd_{Path(name).stem}_{digest}"


def _save_self_recon_sample(
    record: dict[str, Any],
    output_root: Path,
    size: tuple[int, int],
    upper_labels: set[int],
) -> dict[str, Any] | None:
    person_path = Path(record["person"])
    same_cloth_path = Path(record["same_cloth"])
    same_mask_path = Path(record["same_cloth_mask"])
    parse_path = Path(record["parse"])
    if not all(path.exists() for path in [person_path, same_cloth_path, same_mask_path, parse_path]):
        return None

    person = Image.open(person_path).convert("RGB").resize(size, Image.Resampling.BICUBIC)
    cloth = Image.open(same_cloth_path).convert("RGB").resize(size, Image.Resampling.BICUBIC)
    edge = Image.open(same_mask_path).convert("L").resize(size, Image.Resampling.NEAREST)
    labels = _label_map(parse_path, size)
    target_edge = _largest_component(np.isin(labels, list(upper_labels)))
    coverage = float(target_edge.mean())
    bbox = _bbox(target_edge)
    if bbox is None or coverage < 0.04 or coverage > 0.45:
        return None

    sample_id = _sample_id(person_path.name)
    sample_dir = output_root / "samples" / sample_id
    sample_dir.mkdir(parents=True, exist_ok=True)
    paths = {
        "person": sample_dir / "person.jpg",
        "cloth": sample_dir / "cloth.jpg",
        "edge": sample_dir / "edge.png",
        "target_cloth": sample_dir / "target_cloth.jpg",
        "target_edge": sample_dir / "target_edge.png",
    }
    person.save(paths["person"], "JPEG", quality=95)
    cloth.save(paths["cloth"], "JPEG", quality=95)
    edge.save(paths["edge"])
    _target_cloth(person, target_edge).save(paths["target_cloth"], "JPEG", quality=95)
    Image.fromarray((target_edge.astype(np.uint8) * 255), mode="L").save(paths["target_edge"])

    return {
        "id": sample_id,
        "source_person": str(person_path),
        "source_cloth": str(same_cloth_path),
        "source_cloth_mask": str(same_mask_path),
        "source_parse": str(parse_path),
        "coverage": round(coverage, 4),
        "target_bbox": bbox,
        "product_category": "tshirt",
        "product_type": "top",
        **{key: str(path) for key, path in paths.items()},
    }


def _write_jsonl(records: list[dict[str, Any]], path: Path) -> None:
    with path.open("w", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record, default=_json_default) + "\n")


def _load_preview(path: Path, size: tuple[int, int]) -> Image.Image:
    if not path.exists():
        return Image.new("RGB", size, (230, 230, 230))
    return Image.open(path).convert("RGB").resize(size, Image.Resampling.BICUBIC)


def _make_tryon_preview(records: list[dict[str, Any]], output_path: Path, rows: int) -> None:
    if not records:
        return
    tile = (160, 213)
    label_h = 18
    keys = ["person", "cloth", "cloth_mask", "parse", "densepose", "openpose_img"]
    canvas = Image.new("RGB", (len(keys) * tile[0], min(rows, len(records)) * (tile[1] + label_h)), (235, 235, 235))
    draw = ImageDraw.Draw(canvas)
    for row, record in enumerate(records[:rows]):
        for col, key in enumerate(keys):
            image = _load_preview(Path(record[key]), tile)
            x = col * tile[0]
            y = row * (tile[1] + label_h)
            canvas.paste(image, (x, y + label_h))
            draw.text((x + 4, y + 3), key, fill=(0, 0, 0))
    canvas.save(output_path, "JPEG", quality=92)


def _make_self_recon_preview(records: list[dict[str, Any]], output_path: Path, rows: int) -> None:
    if not records:
        return
    tile = (160, 213)
    label_h = 18
    keys = ["person", "cloth", "edge", "target_edge", "target_cloth"]
    canvas = Image.new("RGB", (len(keys) * tile[0], min(rows, len(records)) * (tile[1] + label_h)), (235, 235, 235))
    draw = ImageDraw.Draw(canvas)
    for row, record in enumerate(records[:rows]):
        for col, key in enumerate(keys):
            image = _load_preview(Path(record[key]), tile)
            x = col * tile[0]
            y = row * (tile[1] + label_h)
            canvas.paste(image, (x, y + label_h))
            draw.text((x + 4, y + 3), key, fill=(0, 0, 0))
    canvas.save(output_path, "JPEG", quality=92)


def build_subset(
    viton_root: Path,
    split: str,
    output_root: Path,
    max_samples: int,
    seed: int,
    size: tuple[int, int],
    preview_rows: int,
    upper_labels: set[int],
) -> dict[str, Any]:
    split_root = viton_root / split
    pairs_path = viton_root / f"{split}_pairs.txt"
    if not split_root.exists():
        raise FileNotFoundError(f"Missing VITON-HD split folder: {split_root}")
    if not pairs_path.exists():
        raise FileNotFoundError(f"Missing VITON-HD pairs file: {pairs_path}")

    output_root.mkdir(parents=True, exist_ok=True)
    dirs = _required_split_dirs(split_root)
    pairs = _read_pairs(pairs_path)
    pair_records = [_pair_record(split_root, person_name, cloth_name) for person_name, cloth_name in pairs]

    required_tryon = ["person", "cloth", "cloth_mask", "parse", "densepose", "openpose_json", "openpose_img"]
    complete_tryon = [record for record in pair_records if _existing_required(record, required_tryon)]

    rng = random.Random(seed)
    rng.shuffle(complete_tryon)
    tryon_subset = complete_tryon[:max_samples]

    self_recon_candidates: list[dict[str, Any]] = []
    for record in complete_tryon:
        same_name = record["person_name"]
        candidate = dict(record)
        candidate["same_cloth"] = dirs["cloth"] / same_name
        candidate["same_cloth_mask"] = dirs["cloth_mask"] / same_name
        if Path(candidate["same_cloth"]).exists() and Path(candidate["same_cloth_mask"]).exists():
            self_recon_candidates.append(candidate)

    rng.shuffle(self_recon_candidates)
    self_recon_records: list[dict[str, Any]] = []
    for candidate in self_recon_candidates:
        if len(self_recon_records) >= max_samples:
            break
        sample = _save_self_recon_sample(candidate, output_root, size, upper_labels)
        if sample is not None:
            self_recon_records.append(sample)

    tryon_manifest = output_root / "tryon_manifest.jsonl"
    self_recon_manifest = output_root / "self_recon_manifest.jsonl"
    _write_jsonl(tryon_subset, tryon_manifest)
    _write_jsonl(self_recon_records, self_recon_manifest)
    _make_tryon_preview(tryon_subset, output_root / "tryon_preview.jpg", preview_rows)
    _make_self_recon_preview(self_recon_records, output_root / "self_recon_preview.jpg", preview_rows)

    missing_counts: dict[str, int] = {}
    for key in required_tryon:
        missing_counts[key] = sum(1 for record in pair_records if not Path(record[key]).exists())

    summary = {
        "viton_root": str(viton_root),
        "split": split,
        "split_root": str(split_root),
        "pairs_file": str(pairs_path),
        "pair_count": len(pairs),
        "complete_tryon_pairs": len(complete_tryon),
        "tryon_subset_count": len(tryon_subset),
        "self_recon_candidate_count": len(self_recon_candidates),
        "self_recon_subset_count": len(self_recon_records),
        "size": list(size),
        "seed": seed,
        "folder_counts": {key: _file_count(path) for key, path in dirs.items()},
        "missing_required_counts": missing_counts,
        "tryon_manifest": str(tryon_manifest),
        "self_recon_manifest": str(self_recon_manifest),
        "tryon_preview": str(output_root / "tryon_preview.jpg"),
        "self_recon_preview": str(output_root / "self_recon_preview.jpg"),
    }
    (output_root / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build compact manifests from an extracted VITON-HD split."
    )
    parser.add_argument("--viton-root", default=str(DEFAULT_VITON_ROOT))
    parser.add_argument("--split", default="test", choices=("train", "test"))
    parser.add_argument("--output-root", default=str(DEFAULT_OUTPUT))
    parser.add_argument("--max-samples", type=int, default=80)
    parser.add_argument("--seed", type=int, default=23)
    parser.add_argument("--width", type=int, default=192)
    parser.add_argument("--height", type=int, default=256)
    parser.add_argument(
        "--upper-labels",
        default="5,6,7",
        help="Comma-separated parse labels treated as upper clothing.",
    )
    parser.add_argument("--preview-rows", type=int, default=12)
    args = parser.parse_args()

    upper_labels = {int(value.strip()) for value in args.upper_labels.split(",") if value.strip()}
    summary = build_subset(
        Path(args.viton_root),
        args.split,
        Path(args.output_root),
        args.max_samples,
        args.seed,
        (args.width, args.height),
        args.preview_rows,
        upper_labels,
    )
    print(json.dumps(summary, indent=2))
    return 0 if summary["tryon_subset_count"] and summary["self_recon_subset_count"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
