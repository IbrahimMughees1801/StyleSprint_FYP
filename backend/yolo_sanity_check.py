"""
YOLO sanity check for StyleSprint.

Use this to verify whether weights/best.pt is actually detecting clothing on your
own images before wiring it into the full pipeline.

Example:
    python yolo_sanity_check.py --image ..\sample.jpg
    python yolo_sanity_check.py --image ..\sample.jpg --weights ..\weights\best.pt --conf 0.10
"""

from __future__ import annotations

import argparse
from pathlib import Path

from ultralytics import YOLO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Sanity-check a YOLO clothing detector")
    parser.add_argument(
        "--weights",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "weights" / "best.pt",
        help="Path to YOLO weights file",
    )
    parser.add_argument(
        "--image",
        type=Path,
        required=True,
        help="Path to a test image",
    )
    parser.add_argument(
        "--conf",
        type=float,
        default=0.10,
        help="Confidence threshold for detection",
    )
    parser.add_argument(
        "--imgsz",
        type=int,
        default=640,
        help="Inference image size",
    )
    parser.add_argument(
        "--device",
        default="cpu",
        help="Device to use, e.g. cpu or cuda",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent / "yolo_sanity_output.jpg",
        help="Annotated output image path",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if not args.weights.exists():
        print(f"Weights not found: {args.weights}")
        return 1

    if not args.image.exists():
        print(f"Image not found: {args.image}")
        return 1

    print(f"Loading weights: {args.weights}")
    model = YOLO(str(args.weights))
    print(f"Classes: {model.names}")

    print(f"Running inference on: {args.image}")
    results = model.predict(
        source=str(args.image),
        conf=args.conf,
        imgsz=args.imgsz,
        device=args.device,
        verbose=False,
    )

    result = results[0]
    boxes = result.boxes

    if boxes is None or len(boxes) == 0:
        print(f"No detections at conf={args.conf}. Try lowering --conf to 0.05 or 0.01.")
    else:
        print(f"Detections: {len(boxes)}")
        for i, box in enumerate(boxes, start=1):
            cls_id = int(box.cls[0])
            name = model.names.get(cls_id, str(cls_id))
            conf = float(box.conf[0])
            x1, y1, x2, y2 = box.xyxy[0].tolist()
            print(f"{i}. {name} | conf={conf:.2%} | bbox=({x1:.0f}, {y1:.0f}, {x2:.0f}, {y2:.0f})")

    annotated = result.plot()
    import cv2

    args.output.parent.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(args.output), annotated)
    print(f"Annotated result saved to: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
