from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from PIL import Image

from build_pfafn_finetune_dataset import GRAPHONOMY_LABEL_COLORS
from models.ParseAgnostic import GraphonomyInference


BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent
TEMP_DIR = BASE_DIR / "temp_uploads"


CONFIG = {
    "graphonomy_repo": BASE_DIR / "third_party" / "Graphonomy",
    "graphonomy_weights": PROJECT_DIR / "weights" / "inference.pth",
    "python_torch112": Path(r"C:\Users\muhdi\miniconda3\envs\torch112\python.exe"),
}


def normalize_parse_label_map(src: Path, dst: Path) -> bool:
    if not src.exists():
        return False

    import numpy as np

    image = Image.open(src)
    if image.mode == "L":
        labels = np.array(image)
        if labels.max(initial=0) > 19:
            labels = np.where(labels <= 19, labels, 0)
        label_image = Image.fromarray(labels.astype(np.uint8), mode="L")
    else:
        rgb = np.array(image.convert("RGB"))
        labels = np.zeros(rgb.shape[:2], dtype=np.uint8)
        for color, label in GRAPHONOMY_LABEL_COLORS.items():
            labels[(rgb == color).all(axis=-1)] = label
        label_image = Image.fromarray(labels, mode="L")

    dst.parent.mkdir(parents=True, exist_ok=True)
    label_image.save(dst)
    return True


def parse_label_stats(path: Path) -> dict | None:
    if not path.exists():
        return None

    import numpy as np

    labels = np.array(Image.open(path).convert("L"))
    total = max(1, labels.size)

    def coverage(label_ids: list[int]) -> float:
        return round(float(np.isin(labels, label_ids).sum() / total), 4)

    return {
        "unique_labels": sorted(int(value) for value in np.unique(labels) if int(value) <= 19),
        "upper_coverage": coverage([5]),
        "arm_coverage": coverage([14, 15]),
        "head_coverage": coverage([1, 2, 4, 13]),
    }


def preprocess_person(image_path: Path, output_name: str, force: bool) -> dict:
    image_dir = TEMP_DIR / "image"
    parse_dir = TEMP_DIR / "image-parse-v3"
    image_dir.mkdir(parents=True, exist_ok=True)
    parse_dir.mkdir(parents=True, exist_ok=True)

    person_filename = f"{output_name}_person.jpg"
    saved_person = image_dir / person_filename
    parse_path = parse_dir / f"{output_name}_person.png"
    gray_parse_path = parse_dir / f"{output_name}_person_gray.png"

    if parse_path.exists() and saved_person.exists() and not force:
        return {
            "source": str(image_path),
            "person": str(saved_person),
            "parse": str(parse_path),
            "skipped": True,
            "stats": parse_label_stats(parse_path),
        }

    image = Image.open(image_path).convert("RGB")
    resized = image.resize((768, 1024), Image.Resampling.BILINEAR)
    saved_person.parent.mkdir(parents=True, exist_ok=True)
    resized.save(saved_person, "JPEG", quality=95)

    runner = GraphonomyInference(
        repo_dir=str(CONFIG["graphonomy_repo"]),
        requirements_path=str(CONFIG["graphonomy_repo"] / "requirements.txt"),
        python_executable=str(CONFIG["python_torch112"]),
    )
    runner.run_inference(
        str(CONFIG["graphonomy_weights"]),
        str(saved_person),
        str(parse_dir),
        f"{output_name}_person",
    )

    if gray_parse_path.exists():
        gray = Image.open(gray_parse_path).convert("L").resize(resized.size, Image.Resampling.NEAREST)
        gray.save(gray_parse_path)
        normalize_parse_label_map(gray_parse_path, parse_path)
    elif parse_path.exists():
        normalized = Image.open(parse_path).resize(resized.size, Image.Resampling.NEAREST)
        normalized.save(parse_path)

    return {
        "source": str(image_path),
        "person": str(saved_person),
        "parse": str(parse_path),
        "skipped": False,
        "stats": parse_label_stats(parse_path),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Preprocess person photos for PF-AFN self-reconstruction data.")
    parser.add_argument("--input-dir", required=True)
    parser.add_argument("--pattern", default="person*.jpg")
    parser.add_argument("--prefix", default="ft")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    input_dir = Path(args.input_dir)
    files = sorted(input_dir.glob(args.pattern))
    records = []
    for image_path in files:
        output_name = f"{args.prefix}_{image_path.stem}"
        print(json.dumps({"stage": "preprocess", "image": str(image_path), "output": output_name}), flush=True)
        records.append(preprocess_person(image_path, output_name, args.force))

    output = BASE_DIR / "results" / "debug" / f"{args.prefix}_people_preprocess.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(records, indent=2), encoding="utf-8")
    print(json.dumps({"processed": len(records), "report": str(output)}, indent=2))
    return 0 if records else 1


if __name__ == "__main__":
    os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"
    raise SystemExit(main())
