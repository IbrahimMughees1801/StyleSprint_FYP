from __future__ import annotations

from pathlib import Path

from ultralytics import YOLO


class YOLODetector:
    def __init__(self, weights_path: str, device: str = "cpu") -> None:
        self.weights_path = Path(weights_path)
        self.device = device
        self.model = YOLO(str(self.weights_path))

    def detect(self, image_path: str):
        return self.model.predict(source=image_path, conf=0.10, imgsz=640, device=self.device, verbose=False)

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
