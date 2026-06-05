from __future__ import annotations

import argparse
import random
import shutil
import sys
from pathlib import Path

from PIL import Image

BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from models.yolo import YOLODetector


IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
NAMES = ["sunglass", "hat", "jacket", "shirt", "pants", "shorts", "skirt", "dress", "bag", "shoe"]
CLASS_IDS = {name: index for index, name in enumerate(NAMES)}
CATEGORY_TO_CLASS = {
    "tshirt": "shirt",
    "t-shirt": "shirt",
    "tee": "shirt",
    "top": "shirt",
    "shirt": "shirt",
    "jeans": "pants",
    "jean": "pants",
    "pants": "pants",
    "trousers": "pants",
}


def collect_images(root: Path) -> list[tuple[Path, str]]:
    rows: list[tuple[Path, str]] = []
    for folder in sorted(path for path in root.iterdir() if path.is_dir()):
        class_name = CATEGORY_TO_CLASS.get(folder.name.lower())
        if not class_name:
            continue
        for image_path in sorted(folder.iterdir()):
            if image_path.suffix.lower() in IMAGE_EXTENSIONS:
                rows.append((image_path, class_name))
    return rows


def scale_box(box: list[int], scale: float) -> list[int]:
    if scale >= 0.999:
        return box
    x1, y1, x2, y2 = box
    cx = (x1 + x2) / 2
    cy = (y1 + y2) / 2
    width = max(1, x2 - x1) * scale
    height = max(1, y2 - y1) * scale
    return [
        int(round(cx - width / 2)),
        int(round(cy - height / 2)),
        int(round(cx + width / 2)),
        int(round(cy + height / 2)),
    ]


def yolo_label_line(class_name: str, box: list[int], image_size: tuple[int, int], box_scale: float) -> str:
    width, height = image_size
    box = scale_box(box, box_scale)
    x1, y1, x2, y2 = box
    x1 = max(0, min(width - 1, int(x1)))
    x2 = max(0, min(width - 1, int(x2)))
    y1 = max(0, min(height - 1, int(y1)))
    y2 = max(0, min(height - 1, int(y2)))
    if x2 <= x1:
        x2 = min(width - 1, x1 + 1)
    if y2 <= y1:
        y2 = min(height - 1, y1 + 1)
    box_width = x2 - x1
    box_height = y2 - y1
    cx = x1 + box_width / 2
    cy = y1 + box_height / 2
    return (
        f"{CLASS_IDS[class_name]} "
        f"{cx / width:.6f} {cy / height:.6f} "
        f"{box_width / width:.6f} {box_height / height:.6f}\n"
    )


def write_data_yaml(output: Path) -> None:
    names_text = "\n".join(f"  {index}: {name}" for index, name in enumerate(NAMES))
    text = (
        f"path: {output.as_posix()}\n"
        "train: images/train\n"
        "val: images/val\n"
        f"names:\n{names_text}\n"
    )
    (output / "data.yaml").write_text(text, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a pseudo-labeled YOLO product fine-tune dataset.")
    parser.add_argument(
        "--root",
        default=str(Path.home() / "Desktop" / "mobile database" / "ecommerce products"),
    )
    parser.add_argument("--weights", default=str(PROJECT_DIR / "weights" / "best.pt"))
    parser.add_argument("--output", default=str(BASE_DIR / "datasets" / "yolo_product_finetune"))
    parser.add_argument("--device", default="cpu")
    parser.add_argument("--val-ratio", type=float, default=0.18)
    parser.add_argument("--box-scale", type=float, default=1.0)
    parser.add_argument("--seed", type=int, default=23)
    args = parser.parse_args()

    root = Path(args.root)
    output = Path(args.output)
    if output.exists():
        shutil.rmtree(output)
    for split in ["train", "val"]:
        (output / "images" / split).mkdir(parents=True, exist_ok=True)
        (output / "labels" / split).mkdir(parents=True, exist_ok=True)

    rows = collect_images(root)
    random.Random(args.seed).shuffle(rows)
    val_count = max(1, int(len(rows) * args.val_ratio))
    detector = YOLODetector(args.weights, device=args.device)
    stats = {"train": 0, "val": 0, "fallback": 0, "yolo": 0, "skipped": 0}

    for index, (source_path, class_name) in enumerate(rows):
        split = "val" if index < val_count else "train"
        image = Image.open(source_path).convert("RGB")
        image_size = image.size
        boxes = detector.get_bounding_boxes(detector.detect(str(source_path)))
        selected = detector.select_best_garment_box(boxes, str(source_path), class_name)
        method = "yolo"
        if selected is None:
            selected = detector.foreground_fallback_box(str(source_path))
            method = "fallback"
        if selected is None:
            stats["skipped"] += 1
            continue

        stem = f"{source_path.parent.name}_{source_path.stem}_{index:04d}"
        dest_image = output / "images" / split / f"{stem}.jpg"
        dest_label = output / "labels" / split / f"{stem}.txt"
        image.save(dest_image, "JPEG", quality=95)
        dest_label.write_text(
            yolo_label_line(class_name, selected["box"], image_size, args.box_scale),
            encoding="utf-8",
        )
        stats[split] += 1
        stats[method] += 1

    write_data_yaml(output)
    print(
        {
            "output": str(output),
            "data_yaml": str(output / "data.yaml"),
            "source_count": len(rows),
            **stats,
        }
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
