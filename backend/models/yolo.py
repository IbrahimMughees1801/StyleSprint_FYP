from __future__ import annotations

import os
from pathlib import Path

from PIL import Image
from ultralytics import YOLO


class YOLODetector:
    GARMENT_CLASSES = {"shirt", "jacket", "pants", "shorts", "skirt", "dress"}
    CATEGORY_ALIASES = {
        "tshirt": "shirt",
        "t-shirt": "shirt",
        "tee": "shirt",
        "top": "shirt",
        "tops": "shirt",
        "shirt": "shirt",
        "shirts": "shirt",
        "hoodie": "shirt",
        "sweatshirt": "shirt",
        "jean": "pants",
        "jeans": "pants",
        "denim": "pants",
        "pant": "pants",
        "pants": "pants",
        "trouser": "pants",
        "trousers": "pants",
        "short": "shorts",
        "shorts": "shorts",
        "skirt": "skirt",
        "skirts": "skirt",
        "dress": "dress",
        "dresses": "dress",
        "jacket": "jacket",
        "jackets": "jacket",
    }

    def __init__(self, weights_path: str, device: str = "cpu") -> None:
        self.weights_path = Path(weights_path)
        self.device = device
        self.model = YOLO(str(self.weights_path))

    def detect(self, image_path: str):
        conf = float(os.getenv("API_YOLO_CONF", "0.01"))
        imgsz = int(os.getenv("API_YOLO_IMGSZ", "640"))
        return self.model.predict(source=image_path, conf=conf, imgsz=imgsz, device=self.device, verbose=False)

    def get_bounding_boxes(self, results):
        boxes = []
        if not results:
            return boxes

        result = results[0]
        if result.boxes is None:
            return boxes

        names = result.names if hasattr(result, "names") else self.model.names
        for box in result.boxes:
            cls_id = int(box.cls[0])
            name = names.get(cls_id, str(cls_id)) if isinstance(names, dict) else str(names[cls_id])
            confidence = float(box.conf[0])
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            boxes.append(
                {
                    "class_id": cls_id,
                    "class_name": name,
                    "confidence": confidence,
                    "box": [int(x1), int(y1), int(x2), int(y2)],
                }
            )
        return boxes

    def normalize_category(self, category_hint: str | None):
        if not category_hint:
            return None
        normalized = str(category_hint).strip().lower().replace("_", "-").replace(" ", "-")
        return self.CATEGORY_ALIASES.get(normalized)

    def select_best_garment_box(self, boxes, image_path: str, category_hint: str | None = None):
        if not boxes:
            return None

        image_width, image_height = Image.open(image_path).size
        image_area = max(1, image_width * image_height)
        image_center_x = image_width / 2
        image_center_y = image_height / 2
        expected_class = self.normalize_category(category_hint)
        candidates = []
        min_area = float(os.getenv("API_YOLO_MIN_BOX_AREA", "0.03"))
        max_area = float(os.getenv("API_YOLO_MAX_BOX_AREA", "0.92"))

        for box in boxes:
            class_name = str(box.get("class_name", "")).lower()
            if class_name not in self.GARMENT_CLASSES:
                continue

            x1, y1, x2, y2 = box["box"]
            width = max(1, x2 - x1)
            height = max(1, y2 - y1)
            area_ratio = (width * height) / image_area
            if not min_area <= area_ratio <= max_area:
                continue

            box_center_x = (x1 + x2) / 2
            box_center_y = (y1 + y2) / 2
            center_distance = (
                abs(box_center_x - image_center_x) / max(1, image_width)
                + abs(box_center_y - image_center_y) / max(1, image_height)
            )
            aspect = width / max(1, height)
            target_aspect = 0.42 if expected_class in {"pants", "shorts"} else 0.75
            aspect_penalty = abs(aspect - target_aspect)
            class_score = 0.0
            if expected_class:
                if class_name == expected_class:
                    class_score += 0.35
                elif expected_class == "shirt" and class_name in {"dress", "jacket", "skirt"}:
                    class_score += 0.08
                elif expected_class == "pants" and class_name in {"skirt", "shorts"}:
                    class_score += 0.08
                else:
                    class_score -= 0.08
            score = (
                area_ratio * 2.0
                + float(box.get("confidence", 0.0))
                + class_score
                - center_distance
                - aspect_penalty * 0.08
            )
            candidates.append((score, box))

        if not candidates:
            return None
        candidates.sort(key=lambda item: item[0], reverse=True)
        selected = dict(candidates[0][1])
        selected["box"] = self.pad_box(selected["box"], image_width, image_height)
        if expected_class:
            selected["category_prior"] = expected_class
            selected["effective_class_name"] = expected_class
        return selected

    def pad_box(self, box, image_width: int, image_height: int):
        x1, y1, x2, y2 = [int(value) for value in box]
        width = max(1, x2 - x1)
        height = max(1, y2 - y1)
        pad_ratio = float(os.getenv("API_YOLO_BOX_PAD", "0.12"))
        pad_x = int(width * pad_ratio)
        pad_y = int(height * pad_ratio)
        return [
            max(0, x1 - pad_x),
            max(0, y1 - pad_y),
            min(image_width - 1, x2 + pad_x),
            min(image_height - 1, y2 + pad_y),
        ]

    def foreground_fallback_box(self, image_path: str):
        import cv2
        import numpy as np

        image = np.array(Image.open(image_path).convert("RGB"))
        height, width = image.shape[:2]
        border = max(4, min(height, width) // 32)
        border_pixels = np.concatenate(
            [
                image[:border, :, :].reshape(-1, 3),
                image[-border:, :, :].reshape(-1, 3),
                image[:, :border, :].reshape(-1, 3),
                image[:, -border:, :].reshape(-1, 3),
            ],
            axis=0,
        )
        background = np.median(border_pixels, axis=0)
        distance = np.linalg.norm(image.astype(np.float32) - background.astype(np.float32), axis=2)
        saturation = cv2.cvtColor(image, cv2.COLOR_RGB2HSV)[:, :, 1]
        foreground = (distance > 24) | (saturation > 24)
        foreground[:border, :] = False
        foreground[-border:, :] = False
        foreground[:, :border] = False
        foreground[:, -border:] = False
        foreground = cv2.morphologyEx(
            foreground.astype(np.uint8),
            cv2.MORPH_CLOSE,
            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (17, 17)),
            iterations=1,
        )
        foreground = cv2.morphologyEx(
            foreground,
            cv2.MORPH_OPEN,
            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)),
            iterations=1,
        )
        count, labels, stats, _ = cv2.connectedComponentsWithStats(foreground, 8)
        if count <= 1:
            return None

        largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        area = int(stats[largest, cv2.CC_STAT_AREA])
        if area < int(width * height * 0.02):
            return None

        x = int(stats[largest, cv2.CC_STAT_LEFT])
        y = int(stats[largest, cv2.CC_STAT_TOP])
        w = int(stats[largest, cv2.CC_STAT_WIDTH])
        h = int(stats[largest, cv2.CC_STAT_HEIGHT])
        pad_x = int(w * 0.08)
        pad_y = int(h * 0.08)
        return {
            "class_id": -1,
            "class_name": "foreground_fallback",
            "confidence": 0.0,
            "box": [
                max(0, x - pad_x),
                max(0, y - pad_y),
                min(width - 1, x + w + pad_x),
                min(height - 1, y + h + pad_y),
            ],
        }
