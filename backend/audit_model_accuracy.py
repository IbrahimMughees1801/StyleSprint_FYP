from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image

from diagnose_tryon_run import grade_session


BASE_DIR = Path(__file__).resolve().parent
TEMP_DIR = BASE_DIR / "temp_uploads"
DEBUG_DIR = BASE_DIR / "results" / "debug"


def _mask(path: Path, size: tuple[int, int] | None = None) -> np.ndarray | None:
    if not path.exists():
        return None
    image = Image.open(path).convert("L")
    if size and image.size != size:
        image = image.resize(size, Image.Resampling.NEAREST)
    return np.array(image) >= 128


def _parse_target(session_id: str, size: tuple[int, int], sleeve_arm_ratio: float) -> np.ndarray | None:
    path = TEMP_DIR / "image-parse-v3" / f"{session_id}_person.png"
    if not path.exists():
        return None
    parse = np.array(Image.open(path).convert("L").resize(size, Image.Resampling.NEAREST))
    upper = parse == 5
    if not upper.any():
        return None
    arms = np.isin(parse, [14, 15])
    ys, _ = np.where(upper)
    y1, y2 = int(ys.min()), int(ys.max())
    height = y2 - y1 + 1
    yy = np.arange(size[1])[:, None]
    sleeve = arms & (yy >= y1) & (yy <= int(y1 + height * sleeve_arm_ratio))
    return upper | sleeve


def _bbox(binary: np.ndarray) -> list[int] | None:
    if binary is None or not binary.any():
        return None
    ys, xs = np.where(binary)
    return [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]


def _center(bbox: list[int]) -> tuple[float, float]:
    return (bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2


def pf_afn_fit_metrics(session_id: str, sleeve_arm_ratio: float | None = None) -> dict[str, Any]:
    size = (192, 256)
    if sleeve_arm_ratio is None:
        sleeve_arm_ratio = float(os.getenv("API_WARP_SLEEVE_ARM_RATIO", "0.62"))
    warp = _mask(TEMP_DIR / "test" / "unpaired-cloth-warp-mask" / f"{session_id}_person.jpg", size)
    target = _parse_target(session_id, size, sleeve_arm_ratio)
    if warp is None or target is None:
        return {"available": False, "sleeve_arm_ratio": round(float(sleeve_arm_ratio), 4)}

    inter = int((warp & target).sum())
    union = int((warp | target).sum())
    warp_area = int(warp.sum())
    target_area = int(target.sum())
    warp_bbox = _bbox(warp)
    target_bbox = _bbox(target)
    bbox_area = 0
    center_delta = None
    if warp_bbox and target_bbox:
        bbox_area = (warp_bbox[2] - warp_bbox[0] + 1) * (warp_bbox[3] - warp_bbox[1] + 1)
        wc = _center(warp_bbox)
        tc = _center(target_bbox)
        center_delta = [round(wc[0] - tc[0], 2), round(wc[1] - tc[1], 2)]

    return {
        "available": True,
        "sleeve_arm_ratio": round(float(sleeve_arm_ratio), 4),
        "target_area_ratio": round(float(target_area / target.size), 4),
        "warp_area_ratio": round(float(warp_area / warp.size), 4),
        "warp_target_iou": round(float(inter / max(1, union)), 4),
        "warp_inside_target": round(float(inter / max(1, warp_area)), 4),
        "target_covered_by_warp": round(float(inter / max(1, target_area)), 4),
        "warp_bbox": warp_bbox,
        "target_bbox": target_bbox,
        "center_delta_px": center_delta,
        "warp_solidity_bbox": round(float(warp_area / max(1, bbox_area)), 4),
    }


def verdicts(report: dict[str, Any], fit: dict[str, Any]) -> list[dict[str, str]]:
    artifacts = report["artifacts"]
    rows: list[dict[str, str]] = []

    def add(model: str, score: str, verdict: str, note: str) -> None:
        rows.append({"model": model, "score": score, "verdict": verdict, "note": note})

    cloth_mask = artifacts.get("cloth_mask") or {}
    openpose = artifacts.get("openpose") or {}
    densepose = artifacts.get("densepose") or {}
    parse = artifacts.get("parse") or {}
    warp_mask = artifacts.get("warp_mask") or {}
    final = artifacts.get("final") or {}

    yolo = artifacts.get("yolo") or {}
    yolo_area = yolo.get("box_area_ratio")
    if yolo and not yolo.get("used_full_image_fallback") and yolo_area and 0.08 <= yolo_area <= 0.85:
        score = "80/100" if yolo.get("category_prior") else "70/100"
        add(
            "YOLO product detector",
            score,
            "usable",
            (
                f"proposal class={yolo.get('class_name')}, effective={yolo.get('effective_class_name')}, "
                f"hint={yolo.get('category_hint')}, conf={yolo.get('confidence')}, "
                f"box_area={yolo_area}; low label confidence but crop is usable"
            ),
        )
    else:
        add(
            "YOLO product detector",
            "40/100",
            "weak",
            "missed usable product box; pipeline used full product image fallback",
        )

    mask_cov = cloth_mask.get("coverage")
    mask_clean = bool(
        mask_cov
        and 0.08 <= mask_cov <= 0.65
        and cloth_mask.get("component_count", 99) <= 1
        and cloth_mask.get("largest_component_ratio", 0) >= 0.96
        and cloth_mask.get("bbox_fill", 0) >= 0.35
        and not cloth_mask.get("touches_border", False)
    )
    add(
        "FastSAM + mask cleanup",
        "92/100" if mask_clean else "75/100" if mask_cov and 0.08 <= mask_cov <= 0.65 else "55/100",
        "strong" if mask_clean else "usable",
        (
            f"mask coverage={mask_cov}, components={cloth_mask.get('component_count')}, "
            f"largest={cloth_mask.get('largest_component_ratio')}, fill={cloth_mask.get('bbox_fill')}"
        ),
    )

    dense_cov = densepose.get("colored_coverage", 0)
    dense_strong = bool(
        0.12 <= dense_cov <= 0.38
        and densepose.get("component_count", 99) <= 2
        and densepose.get("largest_component_ratio", 0) >= 0.92
        and densepose.get("bbox_fill", 0) >= 0.35
        and not densepose.get("touches_border", False)
    )
    add(
        "DensePose",
        "88/100" if dense_strong else "75/100" if dense_cov >= 0.12 else "60/100",
        "strong" if dense_strong else "good",
        (
            f"body coverage={dense_cov}, components={densepose.get('component_count')}, "
            f"largest={densepose.get('largest_component_ratio')}, fill={densepose.get('bbox_fill')}"
        ),
    )

    openpose_strong = bool(openpose.get("confident_keypoints", 0) >= 12 and not openpose.get("missing_core"))
    openpose_usable = bool(openpose.get("confident_keypoints", 0) >= 10 and not openpose.get("missing_core"))
    add(
        "OpenPose",
        "90/100" if openpose_strong else "78/100" if openpose_usable else "60/100",
        "strong" if openpose_strong else "usable" if openpose_usable else "weak",
        (
            f"confident keypoints={openpose.get('confident_keypoints')}, "
            f"missing_core={openpose.get('missing_core')}"
        ),
    )

    parse_strong = bool(
        parse.get("upper_coverage", 0) >= 0.12
        and parse.get("head_coverage", 0) >= 0.02
        and parse.get("arm_coverage", 0) >= 0.03
        and len(parse.get("unique_labels") or []) >= 4
        and parse.get("upper_components", 99) <= 2
        and parse.get("upper_largest_ratio", 0) >= 0.92
        and parse.get("upper_bbox_fill", 0) >= 0.45
    )
    add(
        "Graphonomy human parsing",
        "86/100" if parse_strong else "78/100" if parse.get("upper_coverage", 0) >= 0.12 else "55/100",
        "strong" if parse_strong else "usable",
        (
            f"labels={parse.get('unique_labels')}, upper={parse.get('upper_coverage')}, "
            f"head={parse.get('head_coverage')}, arms={parse.get('arm_coverage')}, "
            f"upper_components={parse.get('upper_components')}, fill={parse.get('upper_bbox_fill')}"
        ),
    )

    if fit.get("available"):
        iou = fit["warp_target_iou"]
        covered = fit["target_covered_by_warp"]
        inside = fit.get("warp_inside_target", 0)
        center_delta = fit.get("center_delta_px") or [99, 99]
        max_center_delta = max(abs(float(center_delta[0])), abs(float(center_delta[1])))
        if iou >= 0.80 and covered >= 0.90 and inside >= 0.84 and max_center_delta <= 12:
            pf_score = "88/100"
            pf_verdict = "strong"
        elif iou >= 0.72 and covered >= 0.82 and inside >= 0.82 and max_center_delta <= 18:
            pf_score = "78/100"
            pf_verdict = "good"
        elif iou >= 0.62 and covered >= 0.74 and inside >= 0.78:
            pf_score = "65/100"
            pf_verdict = "usable"
        elif iou >= 0.50 and covered >= 0.65:
            pf_score = "50/100"
            pf_verdict = "weak"
        else:
            pf_score = "35/100"
            pf_verdict = "retrain candidate"
        add(
            "PF-AFN warp",
            pf_score,
            pf_verdict,
            (
                f"IoU={iou}, target_covered={covered}, center_delta={fit['center_delta_px']}, "
                f"inside={inside}, coverage={warp_mask.get('coverage')}, "
                f"sleeve_ratio={fit.get('sleeve_arm_ratio')}"
            ),
        )
    else:
        add("PF-AFN warp", "unknown", "missing", "fit metrics unavailable")

    final_available = bool(final)
    final_ok = bool(final_available and not final.get("low_detail") and final.get("green_dominance", 99) < 45)
    if not final_available:
        dci_score = "unknown"
        dci_verdict = "missing"
        dci_note = "final image unavailable"
    elif not final_ok:
        dci_score = "40/100"
        dci_verdict = "weak"
        dci_note = (
            f"final low_detail={final.get('low_detail')}, "
            f"green_dominance={final.get('green_dominance')}; output quality check failed"
        )
    elif fit.get("available") and fit["warp_target_iou"] >= 0.86 and fit["target_covered_by_warp"] >= 0.94:
        dci_score = "78/100"
        dci_verdict = "good"
        dci_note = (
            f"final low_detail={final.get('low_detail')}, green_dominance={final.get('green_dominance')}; "
            "conditioning is usable but residual sleeve/edge artifacts still need cleanup"
        )
    elif fit.get("available") and fit["warp_target_iou"] >= 0.78 and fit["target_covered_by_warp"] >= 0.86:
        dci_score = "70/100"
        dci_verdict = "usable"
        dci_note = (
            f"final low_detail={final.get('low_detail')}, green_dominance={final.get('green_dominance')}; "
            "final follows a usable but imperfect warp"
        )
    else:
        dci_score = "55/100"
        dci_verdict = "blocked by warp"
        dci_note = (
            f"final low_detail={final.get('low_detail')}, green_dominance={final.get('green_dominance')}; "
            "visible failure likely follows weak warped garment shape"
        )
    add("DCI-VTON diffusion", dci_score, dci_verdict, dci_note)
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Single-session model quality audit.")
    parser.add_argument("session_id")
    parser.add_argument(
        "--sleeve-arm-ratio",
        type=float,
        default=None,
        help="Arm depth included in the PF-AFN target mask. Defaults to API_WARP_SLEEVE_ARM_RATIO or 0.62.",
    )
    args = parser.parse_args()

    report = grade_session(args.session_id)
    fit = pf_afn_fit_metrics(args.session_id, args.sleeve_arm_ratio)
    rows = verdicts(report, fit)
    payload = {"session_id": args.session_id, "fit_metrics": fit, "models": rows}

    DEBUG_DIR.mkdir(parents=True, exist_ok=True)
    output = DEBUG_DIR / f"{args.session_id}_model_audit.json"
    output.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    for row in rows:
        print(f"{row['model']}: {row['score']} - {row['verdict']} - {row['note']}")
    print(f"Saved: {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
