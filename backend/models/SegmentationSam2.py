from __future__ import annotations

import os
import json
from pathlib import Path

import cv2
import numpy as np


class FastSAMInference:
    def __init__(self, model_path: str, image_path: str) -> None:
        self.model_path = Path(model_path)
        self.image_path = Path(image_path)

    @staticmethod
    def _bbox_from_mask(mask: np.ndarray):
        ys, xs = np.where(mask > 0)
        if len(xs) == 0:
            return None
        return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())

    @staticmethod
    def _box_center(box):
        x1, y1, x2, y2 = box
        return (x1 + x2) / 2, (y1 + y2) / 2

    def run_inference(self, bbox):
        image = cv2.imread(str(self.image_path))
        if image is None:
            raise FileNotFoundError(f"Unable to read image: {self.image_path}")

        import torch

        device = "cuda" if torch.cuda.is_available() else "cpu"
        from ultralytics import YOLO

        model = YOLO(str(self.model_path))
        imgsz = int(os.getenv("API_FASTSAM_IMGSZ", "1024"))
        conf = float(os.getenv("API_FASTSAM_CONF", "0.25"))
        results = model.predict(source=image, device=device, imgsz=imgsz, conf=conf, iou=0.9, verbose=False)

        annotations = []
        metadata = {
            "image": str(self.image_path),
            "bbox": [int(value) for value in bbox],
            "device": device,
            "imgsz": imgsz,
            "conf": conf,
            "mask_count": 0,
            "selected_index": None,
            "selected_score": None,
            "candidates": [],
        }
        if results and results[0].masks is not None:
            masks = results[0].masks.data.detach().cpu().numpy()
            metadata["mask_count"] = int(len(masks))
            x1, y1, x2, y2 = bbox
            h, w = masks.shape[1:]
            target_height, target_width = image.shape[:2]
            if h != target_height or w != target_width:
                x1 = int(x1 * w / target_width)
                y1 = int(y1 * h / target_height)
                x2 = int(x2 * w / target_width)
                y2 = int(y2 * h / target_height)
            x1 = max(0, min(w, int(x1)))
            y1 = max(0, min(h, int(y1)))
            x2 = max(0, min(w, int(x2)))
            y2 = max(0, min(h, int(y2)))
            best_index = 0
            best_score = -1.0
            bbox_area = max(1, (y2 - y1) * (x2 - x1))
            bbox_center = self._box_center((x1, y1, x2, y2))
            image_area = max(1, h * w)
            for index, mask in enumerate(masks):
                mask_area = float(mask.sum())
                if mask_area <= 0:
                    continue
                overlap = float(mask[y1:y2, x1:x2].sum())
                union = bbox_area + mask_area - overlap
                mask_bbox = self._bbox_from_mask(mask)
                if mask_bbox:
                    mask_center = self._box_center(mask_bbox)
                    center_distance = (
                        abs(mask_center[0] - bbox_center[0]) / max(1, w)
                        + abs(mask_center[1] - bbox_center[1]) / max(1, h)
                    )
                    bbox_fill = mask_area / max(
                        1,
                        (mask_bbox[2] - mask_bbox[0] + 1) * (mask_bbox[3] - mask_bbox[1] + 1),
                    )
                else:
                    center_distance = 1.0
                    bbox_fill = 0.0

                iou = overlap / union if union else 0.0
                inside_ratio = overlap / mask_area
                coverage_ratio = overlap / bbox_area
                area_ratio = mask_area / image_area
                area_penalty = max(0.0, area_ratio - 0.72) * 0.5
                small_area_penalty = max(0.0, 0.035 - area_ratio) * 3.0
                score = (
                    iou * 0.42
                    + inside_ratio * 0.12
                    + min(coverage_ratio, 1.0) * 0.30
                    + min(bbox_fill, 1.0) * 0.10
                    - center_distance * 0.18
                    - area_penalty
                    - small_area_penalty
                )
                metadata["candidates"].append(
                    {
                        "index": int(index),
                        "score": round(float(score), 5),
                        "iou": round(float(iou), 5),
                        "inside_ratio": round(float(inside_ratio), 5),
                        "coverage_ratio": round(float(coverage_ratio), 5),
                        "area_ratio": round(float(area_ratio), 5),
                        "bbox_fill": round(float(bbox_fill), 5),
                        "center_distance": round(float(center_distance), 5),
                        "small_area_penalty": round(float(small_area_penalty), 5),
                        "bbox": list(mask_bbox) if mask_bbox else None,
                    }
                )
                if score > best_score:
                    best_score = score
                    best_index = index
            metadata["selected_index"] = int(best_index)
            metadata["selected_score"] = round(float(best_score), 5)
            annotations = masks[best_index:best_index + 1]

        cloth_mask_dir = self.image_path.parent / "cloth-mask"
        cloth_mask_dir.mkdir(parents=True, exist_ok=True)
        mask_name = self.image_path.name
        if mask_name.lower().endswith(".jpg"):
            mask_name = mask_name[:-4] + ".png"
        mask_path = cloth_mask_dir / mask_name

        if len(annotations) == 0:
            mask = np.ones(image.shape[:2], dtype=np.uint8) * 255
        else:
            mask_array = annotations
            if mask_array.ndim == 3:
                mask_array = np.any(mask_array, axis=0)
            mask = (mask_array.astype(np.uint8) * 255)

        cv2.imwrite(str(mask_path), mask)
        metadata_path = mask_path.with_suffix(".fastsam.json")
        metadata_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
        return str(mask_path)
