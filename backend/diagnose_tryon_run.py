from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image


BASE_DIR = Path(__file__).resolve().parent
TEMP_DIR = BASE_DIR / "temp_uploads"
FINAL_DIR = BASE_DIR / "FINAL" / "result"
DEBUG_DIR = BASE_DIR / "results" / "debug"


def status(ok: bool, warn: bool = False) -> str:
    if ok:
        return "pass"
    if warn:
        return "warn"
    return "fail"


def latest_session_id() -> str:
    candidates = sorted(DEBUG_DIR.glob("*_debug_sheet.jpg"), key=lambda p: p.stat().st_mtime, reverse=True)
    if candidates:
        return candidates[0].name.removesuffix("_debug_sheet.jpg")

    result_candidates = sorted(FINAL_DIR.glob("*_result.*"), key=lambda p: p.stat().st_mtime, reverse=True)
    if result_candidates:
        return result_candidates[0].stem.removesuffix("_result")

    raise SystemExit("No debug sheets or final results found.")


def image_stats(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    image = Image.open(path)
    rgb = np.array(image.convert("RGB"))
    return {
        "path": str(path),
        "mode": image.mode,
        "size": list(image.size),
        "mean_rgb": [round(float(v), 3) for v in rgb.mean(axis=(0, 1))],
        "std_rgb": [round(float(v), 3) for v in rgb.std(axis=(0, 1))],
    }


def mask_stats(path: Path, threshold: int = 128) -> dict[str, Any] | None:
    if not path.exists():
        return None
    image = Image.open(path).convert("L")
    array = np.array(image)
    binary = array >= threshold
    coverage = float(binary.mean())
    data: dict[str, Any] = {
        "path": str(path),
        "size": list(image.size),
        "coverage": round(coverage, 4),
        "unique_values": int(len(np.unique(array))),
    }
    if binary.any():
        ys, xs = np.where(binary)
        bbox = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
        count, labels, component_stats, _ = __import__("cv2").connectedComponentsWithStats(
            binary.astype(np.uint8),
            8,
        )
        component_areas = [int(component_stats[index, __import__("cv2").CC_STAT_AREA]) for index in range(1, count)]
        largest_area = max(component_areas) if component_areas else 0
        bbox_area = max(1, (bbox[2] - bbox[0] + 1) * (bbox[3] - bbox[1] + 1))
        mask_area = int(binary.sum())
        data["bbox"] = bbox
        data["bbox_aspect"] = round((bbox[2] - bbox[0] + 1) / max(1, bbox[3] - bbox[1] + 1), 4)
        data["bbox_fill"] = round(float(mask_area / bbox_area), 4)
        data["component_count"] = max(0, int(count - 1))
        data["largest_component_ratio"] = round(float(largest_area / max(1, mask_area)), 4)
        data["touches_border"] = bool(
            bbox[0] <= 1
            or bbox[1] <= 1
            or bbox[2] >= image.size[0] - 2
            or bbox[3] >= image.size[1] - 2
        )
    else:
        data["bbox"] = None
        data["bbox_aspect"] = 0.0
        data["bbox_fill"] = 0.0
        data["component_count"] = 0
        data["largest_component_ratio"] = 0.0
        data["touches_border"] = False
    return data


def parse_stats(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    image = Image.open(path).convert("L")
    labels = np.array(image)
    total = max(1, labels.size)
    unique = sorted(int(value) for value in np.unique(labels) if int(value) <= 19)

    def coverage(label_ids: list[int]) -> float:
        return float(np.isin(labels, label_ids).sum() / total)

    upper_mask = np.isin(labels, [5, 6, 7])
    arm_mask = np.isin(labels, [14, 15])
    head_mask = np.isin(labels, [1, 2, 4, 13])

    def component_quality(mask: np.ndarray) -> dict[str, Any]:
        if not mask.any():
            return {"components": 0, "largest_ratio": 0.0, "bbox_fill": 0.0, "bbox": None}
        cv2 = __import__("cv2")
        count, _, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)
        areas = [int(stats[index, cv2.CC_STAT_AREA]) for index in range(1, count)]
        largest = max(areas) if areas else 0
        ys, xs = np.where(mask)
        bbox = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
        bbox_area = max(1, (bbox[2] - bbox[0] + 1) * (bbox[3] - bbox[1] + 1))
        return {
            "components": max(0, int(count - 1)),
            "largest_ratio": round(float(largest / max(1, int(mask.sum()))), 4),
            "bbox_fill": round(float(mask.sum() / bbox_area), 4),
            "bbox": bbox,
        }

    upper_quality = component_quality(upper_mask)
    arm_quality = component_quality(arm_mask)
    head_quality = component_quality(head_mask)

    return {
        "path": str(path),
        "size": list(image.size),
        "unique_labels": unique,
        "upper_coverage": round(coverage([5, 6, 7]), 4),
        "head_coverage": round(coverage([1, 2, 4, 13]), 4),
        "arm_coverage": round(coverage([14, 15]), 4),
        "lower_coverage": round(coverage([9, 12, 16, 17, 18, 19]), 4),
        "upper_components": upper_quality["components"],
        "upper_largest_ratio": upper_quality["largest_ratio"],
        "upper_bbox_fill": upper_quality["bbox_fill"],
        "upper_bbox": upper_quality["bbox"],
        "arm_components": arm_quality["components"],
        "arm_largest_ratio": arm_quality["largest_ratio"],
        "head_components": head_quality["components"],
        "head_largest_ratio": head_quality["largest_ratio"],
    }


def openpose_stats(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as f:
        payload = json.load(f)
    people = payload.get("people", [])
    if not people:
        return {"path": str(path), "people": 0, "confident_keypoints": 0, "mean_confidence": 0.0}

    keypoints = np.array(people[0].get("pose_keypoints_2d", []), dtype=np.float32).reshape((-1, 3))
    confidence = keypoints[:, 2] if len(keypoints) else np.array([], dtype=np.float32)
    return {
        "path": str(path),
        "people": len(people),
        "keypoints": int(len(keypoints)),
        "confident_keypoints": int((confidence > 0.05).sum()),
        "mean_confidence": round(float(confidence.mean()), 4) if len(confidence) else 0.0,
        "missing_core": [
            name
            for index, name in [
                (1, "neck"),
                (2, "right_shoulder"),
                (5, "left_shoulder"),
                (9, "right_hip"),
                (12, "left_hip"),
            ]
            if index >= len(keypoints) or keypoints[index, 2] <= 0.05
        ],
    }


def densepose_stats(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    image = Image.open(path).convert("RGB")
    rgb = np.array(image)
    maxc = rgb.max(axis=2).astype(np.int16)
    minc = rgb.min(axis=2).astype(np.int16)
    colored = (maxc - minc) > 45
    data: dict[str, Any] = {
        "path": str(path),
        "size": list(image.size),
        "colored_coverage": round(float(colored.mean()), 4),
    }
    if not colored.any():
        return {
            **data,
            "component_count": 0,
            "largest_component_ratio": 0.0,
            "bbox": None,
            "bbox_fill": 0.0,
            "bbox_aspect": 0.0,
            "touches_border": False,
        }

    cv2 = __import__("cv2")
    count, _, stats, _ = cv2.connectedComponentsWithStats(colored.astype(np.uint8), 8)
    areas = [int(stats[index, cv2.CC_STAT_AREA]) for index in range(1, count)]
    largest_area = max(areas) if areas else 0
    ys, xs = np.where(colored)
    bbox = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
    bbox_area = max(1, (bbox[2] - bbox[0] + 1) * (bbox[3] - bbox[1] + 1))
    colored_area = int(colored.sum())
    return {
        **data,
        "component_count": max(0, int(count - 1)),
        "largest_component_ratio": round(float(largest_area / max(1, colored_area)), 4),
        "bbox": bbox,
        "bbox_fill": round(float(colored_area / bbox_area), 4),
        "bbox_aspect": round(float((bbox[2] - bbox[0] + 1) / max(1, bbox[3] - bbox[1] + 1)), 4),
        "touches_border": bool(
            bbox[0] <= 1
            or bbox[1] <= 1
            or bbox[2] >= image.size[0] - 2
            or bbox[3] >= image.size[1] - 2
        ),
    }


def yolo_stats(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    with path.open("r", encoding="utf-8") as f:
        payload = json.load(f)
    final_box = payload.get("final_box")
    area_ratio = None
    if final_box:
        x1, y1, x2, y2 = final_box
        area_ratio = round(float(max(0, x2 - x1) * max(0, y2 - y1) / (768 * 1024)), 4)
    selected = payload.get("selected") or {}
    return {
        "path": str(path),
        "proposal_count": int(payload.get("proposal_count", 0)),
        "used_full_image_fallback": bool(payload.get("used_full_image_fallback", False)),
        "product_category": payload.get("product_category"),
        "product_type": payload.get("product_type"),
        "category_hint": payload.get("category_hint"),
        "category_prior": selected.get("category_prior"),
        "class_name": selected.get("class_name"),
        "effective_class_name": selected.get("effective_class_name") or selected.get("class_name"),
        "confidence": round(float(selected.get("confidence", 0.0)), 4) if selected else 0.0,
        "final_box": final_box,
        "box_area_ratio": area_ratio,
    }


def final_image_quality(path: Path) -> dict[str, Any] | None:
    stats = image_stats(path)
    if not stats:
        return None
    mean = stats["mean_rgb"]
    std = stats["std_rgb"]
    green_dominance = mean[1] - max(mean[0], mean[2])
    low_detail = max(std) < 12
    return {
        **stats,
        "green_dominance": round(float(green_dominance), 3),
        "low_detail": bool(low_detail),
    }


def grade_session(session_id: str) -> dict[str, Any]:
    person_name = f"{session_id}_person.jpg"
    cloth_name = f"{session_id}_cloth.jpg"
    person_png = f"{session_id}_person.png"
    cloth_png = f"{session_id}_cloth.png"

    raw_parse = parse_stats(TEMP_DIR / "image-parse-v3" / f"{session_id}_person_gray.png")
    parsed = parse_stats(TEMP_DIR / "image-parse-v3" / person_png)
    cloth_mask = mask_stats(TEMP_DIR / "cloth" / "cloth-mask" / cloth_png)
    yolo = yolo_stats(DEBUG_DIR / f"{session_id}_yolo_detection.json")
    warp_mask = mask_stats(TEMP_DIR / "test" / "unpaired-cloth-warp-mask" / person_name)
    final_png = FINAL_DIR / f"{session_id}_result.png"
    final_jpg = FINAL_DIR / f"{session_id}_result.jpg"
    final_path = final_png if final_png.exists() else final_jpg

    checks = []

    checks.append({
        "stage": "Graphonomy raw parse",
        "status": status(bool(raw_parse and len(raw_parse["unique_labels"]) >= 4)),
        "message": f"labels={raw_parse['unique_labels'] if raw_parse else 'missing'}",
    })
    checks.append({
        "stage": "Active human parse",
        "status": status(bool(parsed and len(parsed["unique_labels"]) >= 4 and parsed["upper_coverage"] >= 0.02)),
        "message": f"labels={parsed['unique_labels'] if parsed else 'missing'} upper={parsed['upper_coverage'] if parsed else 'missing'}",
    })
    checks.append({
        "stage": "YOLO product proposal",
        "status": status(
            bool(
                yolo
                and not yolo["used_full_image_fallback"]
                and yolo["final_box"]
                and yolo["box_area_ratio"] is not None
                and 0.08 <= yolo["box_area_ratio"] <= 0.85
            ),
            warn=bool(yolo and yolo["final_box"]),
        ),
        "message": (
            f"class={yolo['class_name'] if yolo else 'missing'} "
            f"effective={yolo['effective_class_name'] if yolo else 'missing'} "
            f"conf={yolo['confidence'] if yolo else 'missing'} "
            f"area={yolo['box_area_ratio'] if yolo else 'missing'} "
            f"full_fallback={yolo['used_full_image_fallback'] if yolo else 'missing'}"
        ),
    })
    checks.append({
        "stage": "Cloth mask",
        "status": status(bool(cloth_mask and 0.03 <= cloth_mask["coverage"] <= 0.75)),
        "message": f"coverage={cloth_mask['coverage'] if cloth_mask else 'missing'}",
    })
    pose = openpose_stats(TEMP_DIR / "openpose_json" / f"{session_id}_person_keypoints.json")
    checks.append({
        "stage": "OpenPose",
        "status": status(
            bool(
                pose
                and pose["confident_keypoints"] >= 8
                and "neck" not in pose["missing_core"]
                and "right_shoulder" not in pose["missing_core"]
                and "left_shoulder" not in pose["missing_core"]
            ),
            warn=bool(pose and pose["confident_keypoints"] >= 8),
        ),
        "message": (
            f"confident={pose['confident_keypoints'] if pose else 'missing'} "
            f"missing_core={pose['missing_core'] if pose else 'missing'}"
        ),
    })
    densepose_path = TEMP_DIR / "image-densepose" / f"{session_id}_person.0001.jpg"
    dense = densepose_stats(densepose_path)
    checks.append({
        "stage": "DensePose",
        "status": status(bool(dense and dense["colored_coverage"] >= 0.08)),
        "message": f"colored_coverage={dense['colored_coverage'] if dense else 'missing'}",
    })
    checks.append({
        "stage": "PF-AFN warp mask",
        "status": status(bool(warp_mask and 0.06 <= warp_mask["coverage"] <= 0.60)),
        "message": f"coverage={warp_mask['coverage'] if warp_mask else 'missing'} aspect={warp_mask['bbox_aspect'] if warp_mask else 'missing'}",
    })
    final = final_image_quality(final_path)
    final_ok = bool(final and not final["low_detail"] and final["green_dominance"] < 45)
    checks.append({
        "stage": "DCI final image",
        "status": status(final_ok, warn=bool(final)),
        "message": (
            f"green_dominance={final['green_dominance'] if final else 'missing'} "
            f"low_detail={final['low_detail'] if final else 'missing'}"
        ),
    })

    return {
        "session_id": session_id,
        "artifacts": {
            "person": image_stats(TEMP_DIR / "image" / person_name),
            "cloth": image_stats(TEMP_DIR / "cloth" / cloth_name),
            "yolo": yolo,
            "raw_parse": raw_parse,
            "parse": parsed,
            "cloth_mask": cloth_mask,
            "openpose": pose,
            "densepose": dense,
            "warp_mask": warp_mask,
            "final": final,
            "debug_sheet": str(DEBUG_DIR / f"{session_id}_debug_sheet.jpg"),
        },
        "checks": checks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Diagnose saved virtual try-on artifacts for one session.")
    parser.add_argument("session_id", nargs="?", help="Session id, e.g. v2parse_56cb4de6. Defaults to latest debug sheet.")
    parser.add_argument("--json", action="store_true", help="Print full JSON report.")
    args = parser.parse_args()

    session_id = args.session_id or latest_session_id()
    report = grade_session(session_id)

    DEBUG_DIR.mkdir(parents=True, exist_ok=True)
    report_path = DEBUG_DIR / f"{session_id}_diagnostics.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")

    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print(f"Session: {session_id}")
        for check in report["checks"]:
            print(f"[{check['status']}] {check['stage']}: {check['message']}")
        print(f"\nSaved: {report_path}")
        print(f"Debug sheet: {report['artifacts']['debug_sheet']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
