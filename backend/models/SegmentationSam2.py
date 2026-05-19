from __future__ import annotations

import os
from pathlib import Path

import cv2
import numpy as np
import torch

from ultralytics import YOLO


class FastSAMInference:
    def __init__(self, model_path: str, image_path: str) -> None:
        self.model_path = Path(model_path)
        self.image_path = Path(image_path)

    def run_inference(self, bbox):
        image = cv2.imread(str(self.image_path))
        if image is None:
            raise FileNotFoundError(f"Unable to read image: {self.image_path}")

        device = "cuda" if torch.cuda.is_available() else "cpu"
        model = YOLO(str(self.model_path))
        results = model.predict(source=image, device=device, imgsz=1024, conf=0.4, iou=0.9, verbose=False)

        annotations = []
        if results and results[0].masks is not None:
            masks = results[0].masks.data.detach().cpu().numpy()
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
            for index, mask in enumerate(masks):
                bbox_area = max(1, (y2 - y1) * (x2 - x1))
                mask_area = float(mask.sum())
                overlap = float(mask[y1:y2, x1:x2].sum())
                union = bbox_area + mask_area - overlap
                score = overlap / union if union else 0.0
                if score > best_score:
                    best_score = score
                    best_index = index
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
        return str(mask_path)
