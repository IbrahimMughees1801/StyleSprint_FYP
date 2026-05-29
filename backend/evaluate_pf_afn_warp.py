from __future__ import annotations

import argparse
import json
import os
import random
import sys
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image, ImageDraw
from torchvision import transforms


def _use_legacy_grid_sample_alignment() -> None:
    original_grid_sample = F.grid_sample

    def grid_sample_legacy(input, grid, mode="bilinear", padding_mode="zeros", align_corners=None):
        if align_corners is None:
            align_corners = True
        return original_grid_sample(
            input,
            grid,
            mode=mode,
            padding_mode=padding_mode,
            align_corners=align_corners,
        )

    F.grid_sample = grid_sample_legacy


def _resolve(path_value: str, manifest_path: Path) -> Path:
    path = Path(path_value)
    if path.is_absolute():
        return path
    manifest_relative = manifest_path.parent / path
    if manifest_relative.exists():
        return manifest_relative
    return Path.cwd() / path


def _load_records(manifest_path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    with manifest_path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                records.append(json.loads(line))
    if not records:
        raise ValueError(f"No records found in {manifest_path}")
    return records


def _load_rgb(path: Path, size: tuple[int, int]) -> torch.Tensor:
    image = Image.open(path).convert("RGB").resize(size, Image.BICUBIC)
    tensor = transforms.ToTensor()(image)
    return transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))(tensor).unsqueeze(0)


def _load_edge(path: Path, size: tuple[int, int]) -> torch.Tensor:
    image = Image.open(path).convert("L").resize(size, Image.NEAREST)
    return (transforms.ToTensor()(image) > 0.5).float().unsqueeze(0)


def _save_rgb(tensor: torch.Tensor, path: Path) -> None:
    array = tensor.squeeze(0).detach().cpu().clamp(-1, 1)
    array = ((array + 1) / 2).permute(1, 2, 0).numpy()
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((array * 255).astype(np.uint8)).save(path, "JPEG", quality=92)


def _save_mask(tensor: torch.Tensor, path: Path) -> None:
    array = tensor.squeeze(0).squeeze(0).detach().cpu().clamp(0, 1).numpy()
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((array * 255).astype(np.uint8), mode="L").save(path)


def _binary_bbox(mask: np.ndarray) -> list[int] | None:
    if not mask.any():
        return None
    ys, xs = np.where(mask)
    return [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]


def _center(bbox: list[int]) -> tuple[float, float]:
    return (bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2


def _parse_upper_target_mask(parse_path: Path, size: tuple[int, int]) -> np.ndarray | None:
    if not parse_path.exists():
        return None
    labels = np.array(Image.open(parse_path).convert("L").resize(size, Image.Resampling.NEAREST))
    upper = labels == 5
    if not upper.any():
        upper = np.isin(labels, [5, 6, 7])
    if not upper.any():
        return None
    arms = np.isin(labels, [14, 15])
    ys, _ = np.where(upper)
    y1, y2 = int(ys.min()), int(ys.max())
    height = y2 - y1 + 1
    yy = np.arange(size[1])[:, None]
    sleeve_band = arms & (yy >= y1) & (yy <= int(y1 + height * 0.62))
    return upper | sleeve_band


def _refit_to_parse(warped_cloth_path: Path, warped_mask_path: Path, parse_path: Path, size: tuple[int, int]) -> dict | None:
    target = _parse_upper_target_mask(parse_path, size)
    if target is None or not target.any():
        return None

    width, height = size
    mask_image = Image.open(warped_mask_path).convert("L").resize(size, Image.Resampling.NEAREST)
    cloth_image = Image.open(warped_cloth_path).convert("RGB").resize(size, Image.Resampling.BICUBIC)
    mask = np.array(mask_image) >= 128
    source_bbox = _binary_bbox(mask)
    target_bbox = _binary_bbox(target)
    if source_bbox is None or target_bbox is None:
        return None

    x1, y1, x2, y2 = source_bbox
    pad = 3
    x1 = max(0, x1 - pad)
    y1 = max(0, y1 - pad)
    x2 = min(width - 1, x2 + pad)
    y2 = min(height - 1, y2 + pad)
    source_bbox = [x1, y1, x2, y2]

    tx1, ty1, tx2, ty2 = target_bbox
    target_width = tx2 - tx1 + 1
    target_height = ty2 - ty1 + 1
    desired_width = max(1, int(target_width * 1.12))
    desired_height = max(1, int(target_height * 0.90))

    cloth_crop = cloth_image.crop((x1, y1, x2 + 1, y2 + 1))
    mask_crop = mask_image.crop((x1, y1, x2 + 1, y2 + 1))
    cloth_resized = cloth_crop.resize((desired_width, desired_height), Image.Resampling.BICUBIC)
    mask_resized = mask_crop.resize((desired_width, desired_height), Image.Resampling.NEAREST)

    target_cx = (tx1 + tx2) / 2
    target_cy = (ty1 + ty2) / 2
    paste_x = int(round(target_cx - desired_width / 2))
    paste_y = int(round(target_cy - desired_height / 2 + target_height * -0.05))
    paste_x = max(-desired_width + 1, min(width - 1, paste_x))
    paste_y = max(-desired_height + 1, min(height - 1, paste_y))

    canvas_cloth = Image.new("RGB", size, (128, 128, 128))
    canvas_mask = Image.new("L", size, 0)
    canvas_cloth.paste(cloth_resized, (paste_x, paste_y), mask_resized)
    canvas_mask.paste(mask_resized, (paste_x, paste_y))

    import cv2

    fit_mask = cv2.dilate(
        target.astype(np.uint8),
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)),
        iterations=1,
    ).astype(bool)
    refit_mask = np.array(canvas_mask) >= 128
    refit_mask &= fit_mask
    count, labels, stats, _ = cv2.connectedComponentsWithStats(refit_mask.astype(np.uint8), 8)
    if count > 1:
        largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        refit_mask = labels == largest

    refit_mask_image = Image.fromarray((refit_mask.astype(np.uint8) * 255), mode="L")
    clipped_cloth = Image.new("RGB", size, (128, 128, 128))
    clipped_cloth.paste(canvas_cloth, (0, 0), refit_mask_image)
    clipped_cloth.save(warped_cloth_path, "JPEG", quality=92)
    refit_mask_image.save(warped_mask_path)
    return {"source_bbox": source_bbox, "target_bbox": target_bbox, "paste": [paste_x, paste_y, desired_width, desired_height]}


def _metrics(prediction: torch.Tensor, target: torch.Tensor) -> dict[str, Any]:
    pred = prediction.squeeze().detach().cpu().numpy() > 0.5
    truth = target.squeeze().detach().cpu().numpy() > 0.5
    intersection = int((pred & truth).sum())
    union = int((pred | truth).sum())
    pred_area = int(pred.sum())
    target_area = int(truth.sum())
    pred_bbox = _binary_bbox(pred)
    target_bbox = _binary_bbox(truth)
    center_delta = None
    if pred_bbox and target_bbox:
        px, py = _center(pred_bbox)
        tx, ty = _center(target_bbox)
        center_delta = [round(px - tx, 2), round(py - ty, 2)]

    return {
        "iou": round(float(intersection / max(1, union)), 4),
        "inside": round(float(intersection / max(1, pred_area)), 4),
        "target_covered": round(float(intersection / max(1, target_area)), 4),
        "coverage": round(float(pred_area / pred.size), 4),
        "center_delta_px": center_delta,
        "pred_bbox": pred_bbox,
        "target_bbox": target_bbox,
    }


def _load_model(repo_dir: Path, checkpoint_path: Path, device: torch.device):
    sys.path = [
        str(repo_dir),
        *[path for path in sys.path if path and Path(path).resolve() != Path(__file__).resolve().parent],
    ]
    sys.modules.pop("models", None)
    from models.afwm import AFWM

    model = AFWM(SimpleNamespace(), 3)
    checkpoint = torch.load(checkpoint_path, map_location="cpu")
    model_state = model.state_dict()
    for parameter_name in model_state:
        model_state[parameter_name] = checkpoint[parameter_name]
    model.load_state_dict(model_state)
    model.to(device)
    model.eval()
    return model


def _run_model(model, person: torch.Tensor, cloth: torch.Tensor, edge: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
    with torch.no_grad():
        warped_cloth, last_flow = model(person, cloth * edge)
        warped_edge = F.grid_sample(
            edge,
            last_flow.permute(0, 2, 3, 1),
            mode="bilinear",
            padding_mode="zeros",
            align_corners=True,
        ).clamp(0, 1)
    return warped_cloth, warped_edge


def _preview(rows: list[dict[str, Any]], output_dir: Path, output_path: Path, max_rows: int) -> None:
    if not rows:
        return
    tile = (160, 213)
    label_h = 18
    keys = ["person", "cloth", "target_edge", "old_mask", "new_mask", "old_warp", "new_warp"]
    canvas = Image.new("RGB", (len(keys) * tile[0], min(max_rows, len(rows)) * (tile[1] + label_h)), (235, 235, 235))
    draw = ImageDraw.Draw(canvas)
    for row_index, row in enumerate(rows[:max_rows]):
        for col_index, key in enumerate(keys):
            path = Path(row[key])
            if not path.exists() and not path.is_absolute():
                path = output_dir / path
            image = Image.open(path).convert("RGB").resize(tile, Image.Resampling.BICUBIC)
            x = col_index * tile[0]
            y = row_index * (tile[1] + label_h)
            canvas.paste(image, (x, y + label_h))
            draw.text((x + 4, y + 3), key, fill=(0, 0, 0))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output_path, "JPEG", quality=92)


def _mean(rows: list[dict[str, Any]], checkpoint_key: str, metric_key: str) -> float:
    values = [float(row[checkpoint_key][metric_key]) for row in rows]
    return round(float(sum(values) / max(1, len(values))), 4)


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare two PF-AFN warp checkpoints on a manifest.")
    parser.add_argument("--repo-dir", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--old-checkpoint", required=True)
    parser.add_argument("--new-checkpoint", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--samples", type=int, default=24)
    parser.add_argument("--preview-rows", type=int, default=12)
    parser.add_argument("--width", type=int, default=192)
    parser.add_argument("--height", type=int, default=256)
    parser.add_argument("--gpu-id", default="0")
    parser.add_argument("--seed", type=int, default=23)
    parser.add_argument(
        "--api-refit",
        action="store_true",
        help="Run the API parse-guided warp refit on each exported old/new warp before scoring.",
    )
    args = parser.parse_args()

    env_root = Path(sys.executable).resolve().parent
    env_bin = env_root / "bin"
    if env_bin.exists():
        os.environ["PATH"] = str(env_bin) + os.pathsep + os.environ.get("PATH", "")
        if hasattr(os, "add_dll_directory"):
            os.add_dll_directory(str(env_bin))

    _use_legacy_grid_sample_alignment()
    has_cuda = torch.cuda.is_available() and torch.cuda.device_count() > 0
    device = torch.device("cuda:0" if has_cuda and args.gpu_id != "-1" else "cpu")
    size = (args.width, args.height)
    manifest_path = Path(args.manifest).resolve()
    records = _load_records(manifest_path)
    random.Random(args.seed).shuffle(records)
    records = records[: args.samples]

    repo_dir = Path(args.repo_dir).resolve()
    old_model = _load_model(repo_dir, Path(args.old_checkpoint), device)
    new_model = _load_model(repo_dir, Path(args.new_checkpoint), device)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    rows: list[dict[str, Any]] = []
    for index, record in enumerate(records, start=1):
        sample_dir = output_dir / f"sample_{index:03d}_{record.get('id', 'sample')}"
        person = _load_rgb(_resolve(record["person"], manifest_path), size).to(device)
        cloth = _load_rgb(_resolve(record["cloth"], manifest_path), size).to(device)
        edge = _load_edge(_resolve(record["edge"], manifest_path), size).to(device)
        target_edge = _load_edge(_resolve(record["target_edge"], manifest_path), size).to(device)

        old_warp, old_mask = _run_model(old_model, person, cloth, edge)
        new_warp, new_mask = _run_model(new_model, person, cloth, edge)

        person_out = sample_dir / "person.jpg"
        cloth_out = sample_dir / "cloth.jpg"
        target_out = sample_dir / "target_edge.png"
        old_warp_out = sample_dir / "old_warp.jpg"
        old_mask_out = sample_dir / "old_mask.png"
        new_warp_out = sample_dir / "new_warp.jpg"
        new_mask_out = sample_dir / "new_mask.png"
        _save_rgb(person, person_out)
        _save_rgb(cloth, cloth_out)
        _save_mask(target_edge, target_out)
        _save_rgb(old_warp, old_warp_out)
        _save_mask(old_mask, old_mask_out)
        _save_rgb(new_warp, new_warp_out)
        _save_mask(new_mask, new_mask_out)

        refit = {}
        if args.api_refit:
            parse_value = record.get("source_parse") or record.get("parse")
            if parse_value:
                parse_path = _resolve(str(parse_value), manifest_path)
                refit["old"] = _refit_to_parse(old_warp_out, old_mask_out, parse_path, size)
                refit["new"] = _refit_to_parse(new_warp_out, new_mask_out, parse_path, size)

        old_score_mask = _load_edge(old_mask_out, size) if args.api_refit else old_mask
        new_score_mask = _load_edge(new_mask_out, size) if args.api_refit else new_mask

        rows.append(
            {
                "index": index,
                "id": record.get("id"),
                "old": _metrics(old_score_mask, target_edge),
                "new": _metrics(new_score_mask, target_edge),
                "person": str(person_out),
                "cloth": str(cloth_out),
                "target_edge": str(target_out),
                "old_warp": str(old_warp_out),
                "old_mask": str(old_mask_out),
                "new_warp": str(new_warp_out),
                "new_mask": str(new_mask_out),
                "refit": refit,
            }
        )

    summary = {
        "samples": len(rows),
        "old": {
            "iou": _mean(rows, "old", "iou"),
            "inside": _mean(rows, "old", "inside"),
            "target_covered": _mean(rows, "old", "target_covered"),
        },
        "new": {
            "iou": _mean(rows, "new", "iou"),
            "inside": _mean(rows, "new", "inside"),
            "target_covered": _mean(rows, "new", "target_covered"),
        },
    }
    payload = {
        "manifest": str(manifest_path),
        "old_checkpoint": args.old_checkpoint,
        "new_checkpoint": args.new_checkpoint,
        "summary": summary,
        "rows": rows,
    }
    metrics_path = output_dir / "metrics.json"
    preview_path = output_dir / "preview.jpg"
    metrics_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    _preview(rows, output_dir, preview_path, args.preview_rows)

    print(json.dumps(summary, indent=2))
    print(f"saved_metrics={metrics_path}")
    print(f"saved_preview={preview_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
