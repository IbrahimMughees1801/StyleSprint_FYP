from __future__ import annotations

from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import shutil
from pathlib import Path
import os
import json
import uuid
from typing import Optional
from pydantic import BaseModel
import base64
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont

# Import simplified try-on (works without ML models)
from simple_tryon import advanced_overlay_tryon

# Import ML models only when explicitly enabled.
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent

PROCESSING_MODE = os.getenv("API_PROCESSING_MODE", "simplified").strip().lower()
if PROCESSING_MODE not in {"simplified", "ml", "auto"}:
    print(f"Unknown API_PROCESSING_MODE={PROCESSING_MODE!r}; using simplified mode")
    PROCESSING_MODE = "simplified"

FALLBACK_TO_SIMPLE = os.getenv("API_FALLBACK_TO_SIMPLE", "true").strip().lower() not in {
    "0",
    "false",
    "no",
}
PREFLIGHT_STRICT = os.getenv("API_PREFLIGHT_STRICT", "true").strip().lower() not in {
    "0",
    "false",
    "no",
}
ALLOW_POSE_FALLBACK_PARSE = os.getenv("API_ALLOW_POSE_FALLBACK_PARSE", "false").strip().lower() in {
    "1",
    "true",
    "yes",
}

ML_IMPORT_ERROR = None
ML_MODELS_AVAILABLE = False

if PROCESSING_MODE in {"ml", "auto"}:
    try:
        from models.yolo import YOLODetector
        from models.SegmentationSam2 import FastSAMInference
        from models.DensePose import DensePoseRunner
        from models.OpenPose import OpenPoseRunner
        from models.ParseAgnostic import GraphonomyInference
        from models.helper import (
            create_pose_fallback_parse,
            get_im_parse_agnostic,
            parse_is_collapsed,
            process_image,
            refine_human_parse,
            sanitize_openpose_json,
        )
        ML_MODELS_AVAILABLE = True
        print("ML model wrappers loaded successfully")
    except ImportError as e:
        ML_IMPORT_ERROR = str(e)
        ML_MODELS_AVAILABLE = False
        print(f"ML model wrappers not available: {e}")
        print("Using simplified overlay mode")

else:
    print("Using simplified overlay mode")

app = FastAPI(title="Virtual Try-On API", version="1.0.0")

# CORS middleware to allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration - Update these paths to your actual model paths
DEFAULT_WARP_CHECKPOINT = BASE_DIR / "third_party" / "PF-AFN" / "PF-AFN_test" / "checkpoints" / "PFAFN" / "warp_model_final.pth"
VITONHD_WARP_CHECKPOINT = BASE_DIR / "results" / "pf_afn_finetune" / "warp_vitonhd_tops_curated300_continue_180step.pth"
LEGACY_TUNED_WARP_CHECKPOINT = BASE_DIR / "results" / "pf_afn_finetune" / "warp_selfrecon_v3_curated_60step.pth"
TUNED_WARP_CHECKPOINT = VITONHD_WARP_CHECKPOINT if VITONHD_WARP_CHECKPOINT.exists() else LEGACY_TUNED_WARP_CHECKPOINT

CONFIG = {
    # Stage 1: Preprocessing models
    "yolo_weights": str(PROJECT_DIR / "weights" / "best.pt"),
    "fastsam_model": str(PROJECT_DIR / "weights" / "FastSAM-s.pt"),
    "densepose_cfg": str(BASE_DIR / "third_party" / "detectron2" / "projects" / "DensePose" / "configs" / "densepose_rcnn_R_50_FPN_s1x.yaml"),
    "densepose_weights": str(PROJECT_DIR / "weights" / "model_final_162be9.pkl"),
    "openpose_root": str(BASE_DIR / "third_party" / "openpose" / "openpose"),
    "graphonomy_repo": str(BASE_DIR / "third_party" / "Graphonomy"),
    "graphonomy_weights": str(PROJECT_DIR / "weights" / "inference.pth"),
    "graphonomy_scales": os.getenv("API_GRAPHONOMY_SCALES", "1.0"),
    
    # Stage 2: Warping (PF-AFN)
    "warping_script": str(BASE_DIR / "pf_afn_warp_export.py"),
    "pf_afn_repo": str(BASE_DIR / "third_party" / "PF-AFN" / "PF-AFN_test"),
    "warp_checkpoint": os.getenv(
        "API_WARP_CHECKPOINT",
        str(TUNED_WARP_CHECKPOINT if TUNED_WARP_CHECKPOINT.exists() else DEFAULT_WARP_CHECKPOINT),
    ),
    
    # Stage 3: Diffusion (DCI-VTON)
    "diffusion_script": str(BASE_DIR / "third_party" / "DCI-VTON-Virtual-Try-On" / "test.py"),
    "diffusion_checkpoint": str(BASE_DIR / "third_party" / "DCI-VTON-Virtual-Try-On" / "checkpoints" / "viton512_v2.ckpt"),
    "diffusion_config": str(BASE_DIR / "third_party" / "DCI-VTON-Virtual-Try-On" / "configs" / "viton512_v2.yaml"),
    "diffusion_workdir": str(BASE_DIR / "third_party" / "DCI-VTON-Virtual-Try-On"),
    "diffusion_steps": os.getenv("API_DIFFUSION_STEPS", "12"),
    "diffusion_precision": os.getenv("API_DIFFUSION_PRECISION", "full"),
    "warp_width": os.getenv("API_WARP_WIDTH", "192"),
    "warp_height": os.getenv("API_WARP_HEIGHT", "256"),
    "warp_mode": os.getenv("API_WARP_MODE", "pf_afn").strip().lower(),
    "pf_afn_input_dir": str(BASE_DIR / "temp_uploads" / "pf_afn"),
    
    # Python environments
    "python_torch112": r"C:\Users\muhdi\miniconda3\envs\torch112\python.exe",
    "python_dci_vton": r"C:\Users\muhdi\miniconda3\envs\dci-vton\python.exe",
    "python_pfafen": r"C:\Users\muhdi\miniconda3\envs\pfafen-gpu-clean\python.exe",
    
    # Directories
    "temp_dir": str(BASE_DIR / "temp_uploads"),
    "output_dir": str(BASE_DIR / "results"),
    "final_output_dir": str(BASE_DIR / "FINAL"),
    "debug_dir": str(BASE_DIR / "results" / "debug")
}

# Create necessary directories
for dir_path in [CONFIG["temp_dir"], CONFIG["output_dir"], CONFIG["final_output_dir"]]:
    os.makedirs(dir_path, exist_ok=True)
    os.makedirs(os.path.join(dir_path, "image"), exist_ok=True)
    os.makedirs(os.path.join(dir_path, "cloth"), exist_ok=True)
    os.makedirs(os.path.join(dir_path, "openpose_json"), exist_ok=True)
    os.makedirs(os.path.join(dir_path, "openpose_img"), exist_ok=True)
    os.makedirs(os.path.join(dir_path, "image-densepose"), exist_ok=True)
    os.makedirs(os.path.join(dir_path, "image-parse-v3"), exist_ok=True)
    os.makedirs(os.path.join(dir_path, "agnostic-v3.2"), exist_ok=True)
    os.makedirs(os.path.join(dir_path, "image-parse-agnostic-v3.2"), exist_ok=True)

# Create warping output directories
os.makedirs(os.path.join(CONFIG["temp_dir"], "unpaired-cloth-warp"), exist_ok=True)
os.makedirs(os.path.join(CONFIG["temp_dir"], "unpaired-cloth-warp-mask"), exist_ok=True)
os.makedirs(os.path.join(CONFIG["output_dir"], "cloth-warp"), exist_ok=True)
os.makedirs(os.path.join(CONFIG["output_dir"], "cloth-warp-mask"), exist_ok=True)
os.makedirs(os.path.join(CONFIG["final_output_dir"], "result"), exist_ok=True)
os.makedirs(CONFIG["debug_dir"], exist_ok=True)

DCI_SUBDIRS = [
    "image",
    "cloth",
    "cloth-mask",
    "openpose_json",
    "openpose_img",
    "image-parse-v3",
    "agnostic-v3.2",
    "image-parse-agnostic-v3.2",
    "unpaired-cloth-warp",
    "unpaired-cloth-warp-mask",
]

GRAPHONOMY_LABEL_COLORS = {
    (0, 0, 0): 0,
    (128, 0, 0): 1,
    (255, 0, 0): 2,
    (0, 85, 0): 3,
    (170, 0, 51): 4,
    (255, 85, 0): 5,
    (0, 0, 85): 6,
    (0, 119, 221): 7,
    (85, 85, 0): 8,
    (0, 85, 85): 9,
    (85, 51, 0): 10,
    (52, 86, 128): 11,
    (0, 128, 0): 12,
    (0, 0, 255): 13,
    (51, 170, 221): 14,
    (0, 255, 255): 15,
    (85, 255, 170): 16,
    (170, 255, 85): 17,
    (255, 255, 0): 18,
    (255, 170, 0): 19,
}
DEBUG_LABEL_COLORS = [
    (0, 0, 0),
    (128, 0, 0),
    (255, 0, 0),
    (0, 85, 0),
    (170, 0, 51),
    (255, 85, 0),
    (0, 0, 85),
    (0, 119, 221),
    (85, 85, 0),
    (0, 85, 85),
    (85, 51, 0),
    (52, 86, 128),
    (0, 128, 0),
    (0, 0, 255),
    (51, 170, 221),
    (0, 255, 255),
    (85, 255, 170),
    (170, 255, 85),
    (255, 255, 0),
    (255, 170, 0),
]


class TryOnRequest(BaseModel):
    session_id: str
    person_image_base64: Optional[str] = None
    cloth_image_base64: Optional[str] = None
    product_category: Optional[str] = None
    product_type: Optional[str] = None


class TryOnResponse(BaseModel):
    success: bool
    message: str
    session_id: str
    result_image_url: Optional[str] = None
    processing_time: Optional[float] = None


def save_base64_image(base64_str: str, output_path: str):
    """Convert base64 string to image and save it"""
    try:
        # Remove data URL prefix if present
        if "," in base64_str:
            base64_str = base64_str.split(",")[1]
        
        image_data = base64.b64decode(base64_str)
        image = Image.open(BytesIO(image_data))
        
        # Convert to RGB if needed
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # Resize to 768x1024
        image_resized = image.resize((768, 1024), Image.Resampling.BILINEAR)
        image_resized.save(output_path, "JPEG")
        
        return True
    except Exception as e:
        print(f"Error saving base64 image: {e}")
        return False


def subprocess_env_for_python(python_executable: str) -> dict:
    env = os.environ.copy()
    env_root = Path(python_executable).resolve().parent
    cache_root = BASE_DIR / ".cache"
    torch_cache = cache_root / "torch"
    cache_root.mkdir(parents=True, exist_ok=True)
    torch_cache.mkdir(parents=True, exist_ok=True)
    path_parts = [
        str(env_root),
        str(env_root / "Library" / "bin"),
        str(env_root / "DLLs"),
        str(env_root / "Scripts"),
        str(env_root / "bin"),
    ]
    env["PATH"] = os.pathsep.join(path_parts + [env.get("PATH", "")])
    cuda_devices = os.getenv("API_CUDA_VISIBLE_DEVICES", "0").strip()
    env["CUDA_VISIBLE_DEVICES"] = cuda_devices if cuda_devices else "0"
    env.setdefault("TORCH_HOME", str(torch_cache))
    env.setdefault("XDG_CACHE_HOME", str(cache_root))
    env.setdefault("HF_HOME", str(cache_root / "huggingface"))
    env["PYTHONPATH"] = os.pathsep.join(
        [str(BASE_DIR)] + ([env["PYTHONPATH"]] if env.get("PYTHONPATH") else [])
    )
    return env


def _copy_if_exists(src: str, dst: str) -> bool:
    if not os.path.exists(src):
        return False
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    return True


def release_ml_memory() -> None:
    import gc

    gc.collect()
    try:
        import torch

        if torch.cuda.is_available():
            torch.cuda.empty_cache()
    except Exception:
        pass


def normalize_parse_label_map(src: str, dst: str) -> bool:
    if not os.path.exists(src):
        return False

    image = Image.open(src)
    if image.mode == "L":
        import numpy as np

        labels = np.array(image)
        if labels.max(initial=0) > 19:
            labels = np.where(labels <= 19, labels, 0)
        label_image = Image.fromarray(labels.astype(np.uint8), mode="L")
    else:
        import numpy as np

        rgb = np.array(image.convert("RGB"))
        labels = np.zeros(rgb.shape[:2], dtype=np.uint8)
        for color, label in GRAPHONOMY_LABEL_COLORS.items():
            labels[(rgb == color).all(axis=-1)] = label
        label_image = Image.fromarray(labels, mode="L")

    os.makedirs(os.path.dirname(dst), exist_ok=True)
    label_image.save(dst)
    return True


def resize_label_map(path: str, size: tuple[int, int]) -> None:
    if not os.path.exists(path):
        return
    image = Image.open(path).convert("L")
    if image.size != size:
        image = image.resize(size, Image.Resampling.NEAREST)
        image.save(path)


def draw_bbox_debug(image_path: str, bbox: list[int], output_path: str) -> None:
    image = Image.open(image_path).convert("RGB")
    draw = ImageDraw.Draw(image)
    x1, y1, x2, y2 = [int(v) for v in bbox]
    draw.rectangle((x1, y1, x2, y2), outline=(255, 0, 0), width=6)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    image.save(output_path, "JPEG", quality=92)


def _first_existing(paths: list[str]) -> Optional[str]:
    for path in paths:
        if path and os.path.exists(path):
            return path
    return None


def parse_label_stats(path: str) -> Optional[dict]:
    if not os.path.exists(path):
        return None

    import numpy as np

    labels = np.array(Image.open(path).convert("L"))
    total = max(1, labels.size)
    unique = sorted(int(value) for value in np.unique(labels) if int(value) <= 19)

    def coverage(label_ids: list[int]) -> float:
        return float(np.isin(labels, label_ids).sum() / total)

    return {
        "unique_labels": unique,
        "upper_coverage": coverage([5, 6, 7]),
        "head_coverage": coverage([1, 2, 4, 13]),
        "arm_coverage": coverage([14, 15]),
        "lower_coverage": coverage([9, 12, 16, 17, 18, 19]),
    }


def binary_mask_stats(path: str, threshold: int = 128) -> Optional[dict]:
    if not os.path.exists(path):
        return None

    import numpy as np

    mask = np.array(Image.open(path).convert("L"))
    binary = mask >= threshold
    coverage = float(binary.mean())
    if not binary.any():
        return {
            "coverage": coverage,
            "bbox": None,
            "bbox_width": 0,
            "bbox_height": 0,
            "bbox_aspect": 0.0,
        }

    ys, xs = np.where(binary)
    x_min, x_max = int(xs.min()), int(xs.max())
    y_min, y_max = int(ys.min()), int(ys.max())
    bbox_width = x_max - x_min + 1
    bbox_height = y_max - y_min + 1
    return {
        "coverage": coverage,
        "bbox": [x_min, y_min, x_max, y_max],
        "bbox_width": bbox_width,
        "bbox_height": bbox_height,
        "bbox_aspect": bbox_width / max(1, bbox_height),
    }


def _binary_bbox(binary) -> Optional[list[int]]:
    import numpy as np

    if binary is None or not binary.any():
        return None
    ys, xs = np.where(binary)
    return [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]


def _bbox_center(bbox: list[int]) -> tuple[float, float]:
    return (bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2


def parse_upper_target_mask(parse_path: str, size: tuple[int, int]) -> Optional[object]:
    if not os.path.exists(parse_path):
        return None

    import numpy as np

    parse = Image.open(parse_path).convert("L").resize(size, Image.Resampling.NEAREST)
    parse_array = np.array(parse)
    upper = parse_array == 5
    if not upper.any():
        upper = np.isin(parse_array, [5, 6, 7])
    if not upper.any():
        return None

    arms = np.isin(parse_array, [14, 15])
    ys, _ = np.where(upper)
    y1, y2 = int(ys.min()), int(ys.max())
    height = y2 - y1 + 1
    yy = np.arange(size[1])[:, None]
    sleeve_ratio = float(os.getenv("API_WARP_SLEEVE_ARM_RATIO", "0.62"))
    sleeve_band = arms & (yy >= y1) & (yy <= int(y1 + height * sleeve_ratio))
    return upper | sleeve_band


def warp_parse_fit_metrics(warp_mask_path: str, parse_path: str) -> Optional[dict]:
    if not os.path.exists(warp_mask_path) or not os.path.exists(parse_path):
        return None

    import numpy as np

    width = int(CONFIG["warp_width"])
    height = int(CONFIG["warp_height"])
    size = (width, height)
    warp = np.array(Image.open(warp_mask_path).convert("L").resize(size, Image.Resampling.NEAREST)) >= 128
    target = parse_upper_target_mask(parse_path, size)
    if target is None or not warp.any():
        return None

    intersection = int((warp & target).sum())
    union = int((warp | target).sum())
    warp_area = int(warp.sum())
    target_area = int(target.sum())
    warp_bbox = _binary_bbox(warp)
    target_bbox = _binary_bbox(target)
    center_delta = None
    if warp_bbox and target_bbox:
        warp_center = _bbox_center(warp_bbox)
        target_center = _bbox_center(target_bbox)
        center_delta = [
            round(warp_center[0] - target_center[0], 2),
            round(warp_center[1] - target_center[1], 2),
        ]

    return {
        "target_area_ratio": round(float(target_area / target.size), 4),
        "warp_area_ratio": round(float(warp_area / warp.size), 4),
        "warp_target_iou": round(float(intersection / max(1, union)), 4),
        "target_covered_by_warp": round(float(intersection / max(1, target_area)), 4),
        "warp_inside_target": round(float(intersection / max(1, warp_area)), 4),
        "warp_bbox": warp_bbox,
        "target_bbox": target_bbox,
        "center_delta_px": center_delta,
    }


def refit_pf_afn_warp_to_parse(
    warped_cloth_path: str,
    warped_mask_path: str,
    parse_path: str,
    source_cloth_path: Optional[str] = None,
    source_mask_path: Optional[str] = None,
) -> Optional[dict]:
    if os.getenv("API_PFAFN_REFIT_TO_PARSE", "true").strip().lower() in {"0", "false", "no"}:
        return None
    if not all(os.path.exists(path) for path in [warped_cloth_path, warped_mask_path, parse_path]):
        return None

    import numpy as np

    width = int(CONFIG["warp_width"])
    height = int(CONFIG["warp_height"])
    size = (width, height)
    target = parse_upper_target_mask(parse_path, size)
    if target is None or not target.any():
        return None

    before = warp_parse_fit_metrics(warped_mask_path, parse_path)
    if before:
        min_target_coverage = float(os.getenv("API_PFAFN_REFIT_MIN_TARGET_COVERAGE", "0.78"))
        max_center_delta = float(os.getenv("API_PFAFN_REFIT_MAX_CENTER_DELTA", "18"))
        center_delta = before.get("center_delta_px") or [0, 0]
        already_ok = (
            before["target_covered_by_warp"] >= min_target_coverage
            and before["warp_inside_target"] >= 0.82
            and max(abs(float(center_delta[0])), abs(float(center_delta[1]))) <= max_center_delta
        )
        if already_ok:
            return {"applied": False, "reason": "already_fit", "before": before}

    mask_image = Image.open(warped_mask_path).convert("L").resize(size, Image.Resampling.NEAREST)
    cloth_image = Image.open(warped_cloth_path).convert("RGB").resize(size, Image.Resampling.BICUBIC)
    source_kind = "pf_afn"
    source_mask_image = mask_image
    source_cloth_image = cloth_image
    use_cloth_source = os.getenv("API_PFAFN_REFIT_SOURCE", "pf_afn").strip().lower() in {
        "cloth",
        "original",
        "product",
    }
    if (
        use_cloth_source
        and source_cloth_path
        and source_mask_path
        and os.path.exists(source_cloth_path)
        and os.path.exists(source_mask_path)
    ):
        source_kind = "cloth"
        source_cloth_image = Image.open(source_cloth_path).convert("RGB")
        source_mask_image = Image.open(source_mask_path).convert("L")
        if source_mask_image.size != source_cloth_image.size:
            source_mask_image = source_mask_image.resize(source_cloth_image.size, Image.Resampling.NEAREST)

    mask = np.array(source_mask_image) >= 128
    source_bbox = _binary_bbox(mask)
    target_bbox = _binary_bbox(target)
    if source_bbox is None or target_bbox is None:
        return None

    x1, y1, x2, y2 = source_bbox
    pad = int(os.getenv("API_PFAFN_REFIT_SOURCE_PAD", "3"))
    x1 = max(0, x1 - pad)
    y1 = max(0, y1 - pad)
    source_width, source_height = source_mask_image.size
    x2 = min(source_width - 1, x2 + pad)
    y2 = min(source_height - 1, y2 + pad)
    source_bbox = [x1, y1, x2, y2]

    tx1, ty1, tx2, ty2 = target_bbox
    target_width = tx2 - tx1 + 1
    target_height = ty2 - ty1 + 1
    width_scale = float(os.getenv("API_PFAFN_REFIT_WIDTH_SCALE", "1.12"))
    height_scale = float(os.getenv("API_PFAFN_REFIT_HEIGHT_SCALE", "1.20"))
    y_shift = float(os.getenv("API_PFAFN_REFIT_Y_SHIFT", "0.05"))
    desired_width = max(1, int(target_width * width_scale))
    desired_height = max(1, int(target_height * height_scale))

    cloth_crop = source_cloth_image.crop((x1, y1, x2 + 1, y2 + 1))
    mask_crop = source_mask_image.crop((x1, y1, x2 + 1, y2 + 1))
    cloth_resized = cloth_crop.resize((desired_width, desired_height), Image.Resampling.BICUBIC)
    mask_resized = mask_crop.resize((desired_width, desired_height), Image.Resampling.NEAREST)

    target_cx = (tx1 + tx2) / 2
    target_cy = (ty1 + ty2) / 2
    paste_x = int(round(target_cx - desired_width / 2))
    paste_y = int(round(target_cy - desired_height / 2 + target_height * y_shift))
    paste_x = max(-desired_width + 1, min(width - 1, paste_x))
    paste_y = max(-desired_height + 1, min(height - 1, paste_y))

    canvas_cloth = Image.new("RGB", size, (128, 128, 128))
    canvas_mask = Image.new("L", size, 0)
    canvas_cloth.paste(cloth_resized, (paste_x, paste_y), mask_resized)
    canvas_mask.paste(mask_resized, (paste_x, paste_y))

    if os.getenv("API_PFAFN_REFIT_CLIP_TO_PARSE", "true").strip().lower() in {"1", "true", "yes"}:
        import cv2

        fit_mask = cv2.dilate(
            target.astype(np.uint8),
            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)),
            iterations=1,
        ).astype(bool)
        refit_mask = np.array(canvas_mask) >= 128
        refit_mask &= fit_mask
        if os.getenv("API_PFAFN_REFIT_KEEP_LARGEST", "true").strip().lower() in {"1", "true", "yes"}:
            count, labels, stats, _ = cv2.connectedComponentsWithStats(refit_mask.astype(np.uint8), 8)
            if count > 1:
                largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
                refit_mask = labels == largest
        refit_mask_image = Image.fromarray((refit_mask.astype(np.uint8) * 255), mode="L")
        clipped_cloth = Image.new("RGB", size, (128, 128, 128))
        clipped_cloth.paste(canvas_cloth, (0, 0), refit_mask_image)
        canvas_cloth = clipped_cloth
        canvas_mask = refit_mask_image

    cloth_image.save(warped_cloth_path.replace(".jpg", "_pfafn_raw.jpg"), "JPEG", quality=95)
    mask_image.save(warped_mask_path.replace(".jpg", "_pfafn_raw.png"))
    canvas_cloth.save(warped_cloth_path, "JPEG", quality=95)
    canvas_mask.save(warped_mask_path)

    after = warp_parse_fit_metrics(warped_mask_path, parse_path)
    return {
        "applied": True,
        "source_kind": source_kind,
        "source_bbox": source_bbox,
        "target_bbox": target_bbox,
        "paste": [paste_x, paste_y, desired_width, desired_height],
        "before": before,
        "after": after,
    }


def clean_cloth_mask(mask_path: str, image_path: Optional[str] = None) -> Optional[dict]:
    if not os.path.exists(mask_path):
        return None

    import cv2
    import numpy as np

    mask = np.array(Image.open(mask_path).convert("L"))
    binary = (mask >= 128).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(binary, 8)
    if count <= 1:
        return binary_mask_stats(mask_path)

    largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    cleaned = (labels == largest).astype(np.uint8)

    row_counts = cleaned.sum(axis=1)
    max_width = int(row_counts.max(initial=0))
    if max_width:
        broad_rows = np.where(row_counts >= max(12, int(max_width * 0.28)))[0]
        if len(broad_rows):
            first_broad = int(broad_rows[0])
            cleaned[:first_broad, :] = 0

    close_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_CLOSE, close_kernel)
    shape_cleaned = cleaned.copy()
    shape_area = int(shape_cleaned.sum())

    if image_path and os.path.exists(image_path):
        image = np.array(Image.open(image_path).convert("RGB"))
        if image.shape[:2] != cleaned.shape:
            image = cv2.resize(image, (cleaned.shape[1], cleaned.shape[0]), interpolation=cv2.INTER_LINEAR)

        border = max(4, min(image.shape[:2]) // 40)
        border_pixels = np.concatenate(
            [
                image[:border, :, :].reshape(-1, 3),
                image[-border:, :, :].reshape(-1, 3),
                image[:, :border, :].reshape(-1, 3),
                image[:, -border:, :].reshape(-1, 3),
            ],
            axis=0,
        )
        bg_color = np.median(border_pixels, axis=0)
        used_color_foreground = False
        color_distance = np.linalg.norm(image.astype(np.float32) - bg_color.astype(np.float32), axis=2)
        near_white = (image[:, :, 0] > 225) & (image[:, :, 1] > 225) & (image[:, :, 2] > 225)
        bg_is_light = bool(bg_color.min() > 185)
        if bg_is_light:
            color_foreground = ((color_distance > 34) & ~near_white).astype(np.uint8)
            color_foreground = cv2.morphologyEx(
                color_foreground,
                cv2.MORPH_CLOSE,
                cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)),
            )
            color_foreground = cv2.morphologyEx(
                color_foreground,
                cv2.MORPH_OPEN,
                cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3)),
            )
            count, fg_labels, fg_stats, _ = cv2.connectedComponentsWithStats(color_foreground, 8)
            if count > 1:
                areas = fg_stats[1:, cv2.CC_STAT_AREA]
                largest_area = int(areas.max(initial=0))
                min_component_area = max(24, int(largest_area * 0.003))
                filtered = np.zeros_like(color_foreground)
                for component in range(1, count):
                    area = int(fg_stats[component, cv2.CC_STAT_AREA])
                    if area >= min_component_area:
                        filtered[fg_labels == component] = 1
                color_foreground = filtered

            foreground_area = int(color_foreground.sum())
            foreground_coverage = foreground_area / max(1, color_foreground.size)
            sam_coverage = int(cleaned.sum()) / max(1, cleaned.size)
            if 0.05 <= foreground_coverage <= 0.70:
                cleaned = color_foreground
                shape_cleaned = cleaned.copy()
                shape_area = int(shape_cleaned.sum())
                used_color_foreground = True

        near_background = ((color_distance < 38) | near_white) & (cleaned > 0)

        ys, xs = np.where(cleaned > 0)
        if len(xs):
            mask_area = max(1, int(cleaned.sum()))
            x_min, x_max = int(xs.min()), int(xs.max())
            y_min, y_max = int(ys.min()), int(ys.max())
            count, bg_labels, bg_stats, _ = cv2.connectedComponentsWithStats(near_background.astype(np.uint8), 8)
            for component in range(1, count):
                x = int(bg_stats[component, cv2.CC_STAT_LEFT])
                y = int(bg_stats[component, cv2.CC_STAT_TOP])
                w = int(bg_stats[component, cv2.CC_STAT_WIDTH])
                h = int(bg_stats[component, cv2.CC_STAT_HEIGHT])
                area = int(bg_stats[component, cv2.CC_STAT_AREA])
                touches_edge = (
                    x <= x_min + 2
                    or y <= y_min + 2
                    or x + w >= x_max - 2
                    or y + h >= y_max - 2
                )
                if (touches_edge and area > mask_area * 0.008) or area > mask_area * 0.045:
                    cleaned[bg_labels == component] = 0

        color_area = int(cleaned.sum())
        if shape_area and color_area < max(int(shape_area * 0.45), int(cleaned.size * 0.08)):
            cleaned = shape_cleaned

        foreground_pixels = image[shape_cleaned > 0]
        white_on_light = False
        if len(foreground_pixels):
            foreground_color = np.median(foreground_pixels, axis=0)
            white_on_light = bool(
                foreground_color.min() > 185
                and bg_color.min() > 205
                and np.linalg.norm(foreground_color.astype(np.float32) - bg_color.astype(np.float32)) < 95
            )

        if white_on_light:
            if shape_area:
                image_bgr = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)
                rect_x = max(1, int(image.shape[1] * 0.08))
                rect_y = max(1, int(image.shape[0] * 0.08))
                rect_w = min(image.shape[1] - rect_x - 2, int(image.shape[1] * 0.84))
                rect_h = min(image.shape[0] - rect_y - 2, int(image.shape[0] * 0.78))
                if rect_w > 8 and rect_h > 8:
                    grabcut_mask = np.zeros(cleaned.shape, dtype=np.uint8)
                    bgd_model = np.zeros((1, 65), np.float64)
                    fgd_model = np.zeros((1, 65), np.float64)
                    cv2.grabCut(
                        image_bgr,
                        grabcut_mask,
                        (rect_x, rect_y, rect_w, rect_h),
                        bgd_model,
                        fgd_model,
                        6,
                        cv2.GC_INIT_WITH_RECT,
                    )
                    grabcut_cleaned = np.where(
                        (grabcut_mask == cv2.GC_FGD) | (grabcut_mask == cv2.GC_PR_FGD),
                        1,
                        0,
                    ).astype(np.uint8)
                    grabcut_cleaned = cv2.morphologyEx(
                        grabcut_cleaned,
                        cv2.MORPH_CLOSE,
                        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (17, 17)),
                    )
                    grabcut_cleaned = cv2.morphologyEx(
                        grabcut_cleaned,
                        cv2.MORPH_OPEN,
                        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)),
                    )
                    grabcut_area = int(grabcut_cleaned.sum())
                    coverage = grabcut_area / max(1, grabcut_cleaned.size)
                    if 0.08 <= coverage <= 0.65 and grabcut_area > int(max(cleaned.sum(), shape_area) * 0.85):
                        cleaned = grabcut_cleaned

        ys, xs = np.where(cleaned > 0)
        if len(xs):
            y_min, y_max = int(ys.min()), int(ys.max())
            garment_height = y_max - y_min + 1
            luminance = (
                image[:, :, 0].astype(np.float32) * 0.299
                + image[:, :, 1].astype(np.float32) * 0.587
                + image[:, :, 2].astype(np.float32) * 0.114
            )
            yy = np.arange(cleaned.shape[0])[:, None]
            if not used_color_foreground:
                top_dark = (cleaned > 0) & (luminance < 75) & (yy <= y_min + int(garment_height * 0.28))
                top_dark = cv2.dilate(
                    top_dark.astype(np.uint8),
                    cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)),
                    iterations=1,
                )
                cleaned[top_dark > 0] = 0

            count, final_labels, final_stats, _ = cv2.connectedComponentsWithStats(cleaned.astype(np.uint8), 8)
            if count > 1:
                largest = 1 + int(np.argmax(final_stats[1:, cv2.CC_STAT_AREA]))
                cleaned = (final_labels == largest).astype(np.uint8)

            row_counts = cleaned.sum(axis=1)
            max_width = int(row_counts.max(initial=0))
            if max_width:
                broad_rows = np.where(row_counts >= max(12, int(max_width * 0.30)))[0]
                if len(broad_rows):
                    first_broad = int(broad_rows[0])
                    cleaned[:first_broad, :] = 0

    output = (cleaned * 255).astype(np.uint8)
    Image.fromarray(output, mode="L").save(mask_path)
    return binary_mask_stats(mask_path)


def create_geometric_cloth_warp(
    session_id: str,
    person_filename: str,
    cloth_filename: str,
) -> Optional[dict]:
    try:
        import numpy as np

        temp_dir = CONFIG["temp_dir"]
        width = int(CONFIG["warp_width"])
        height = int(CONFIG["warp_height"])
        dci_test_dir = os.path.join(temp_dir, "test")

        cloth_path = os.path.join(dci_test_dir, "cloth", cloth_filename)
        cloth_mask_path = os.path.join(dci_test_dir, "cloth-mask", cloth_filename)
        parse_path = os.path.join(dci_test_dir, "image-parse-v3", person_filename.replace(".jpg", ".png"))
        output_cloth_path = os.path.join(dci_test_dir, "unpaired-cloth-warp", person_filename)
        output_mask_path = os.path.join(dci_test_dir, "unpaired-cloth-warp-mask", person_filename)

        cloth = Image.open(cloth_path).convert("RGB").resize((width, height), Image.Resampling.BICUBIC)
        cloth_mask = Image.open(cloth_mask_path).convert("L").resize((width, height), Image.Resampling.NEAREST)
        parse = Image.open(parse_path).convert("L").resize((width, height), Image.Resampling.NEAREST)

        mask_array = np.array(cloth_mask) >= 128
        parse_array = np.array(parse)
        upper_array = parse_array == 5
        arm_array = np.isin(parse_array, [14, 15])
        target_array = upper_array if upper_array.any() else np.isin(parse_array, [5, 14, 15])
        if not mask_array.any() or not target_array.any():
            return None

        mask_y, mask_x = np.where(mask_array)
        cloth_bbox = (
            int(mask_x.min()),
            int(mask_y.min()),
            int(mask_x.max()),
            int(mask_y.max()),
        )

        target_y, target_x = np.where(target_array)
        x1, y1, x2, y2 = (
            int(target_x.min()),
            int(target_y.min()),
            int(target_x.max()),
            int(target_y.max()),
        )
        target_width = x2 - x1 + 1
        target_height = y2 - y1 + 1

        yy = np.arange(height)[:, None]
        sleeve_arm_ratio = float(os.getenv("API_WARP_SLEEVE_ARM_RATIO", "0.62"))
        shoulder_band = arm_array & (yy >= y1) & (yy <= int(y1 + target_height * sleeve_arm_ratio))
        if shoulder_band.any():
            shoulder_y, shoulder_x = np.where(shoulder_band)
            max_shoulder_pad = int(target_width * 0.22)
            x1 = max(x1 - max_shoulder_pad, min(x1, int(shoulder_x.min())))
            x2 = min(x2 + max_shoulder_pad, max(x2, int(shoulder_x.max())))

        target_width = x2 - x1 + 1
        target_height = y2 - y1 + 1
        x1 = max(0, int(x1 - target_width * 0.08))
        x2 = min(width - 1, int(x2 + target_width * 0.08))
        y1 = max(0, int(y1 - target_height * 0.02))
        y2 = min(height - 1, int(y2 + target_height * 0.04))
        target_bbox = (x1, y1, x2, y2)

        cloth_crop = cloth.crop(cloth_bbox)
        mask_crop = cloth_mask.crop(cloth_bbox)
        target_width = target_bbox[2] - target_bbox[0] + 1
        target_height = target_bbox[3] - target_bbox[1] + 1
        crop_width, crop_height = cloth_crop.size
        width_scale = target_width / crop_width
        height_scale = (target_height * 0.92) / crop_height
        max_width_scale = (target_width * 1.45) / crop_width
        scale = min(max(width_scale, height_scale), max_width_scale)
        resized_size = (
            max(1, int(crop_width * scale)),
            max(1, int(crop_height * scale)),
        )
        cloth_resized = cloth_crop.resize(resized_size, Image.Resampling.BICUBIC)
        mask_resized = mask_crop.resize(resized_size, Image.Resampling.NEAREST)

        paste_x = target_bbox[0] + (target_width - resized_size[0]) // 2
        paste_y = target_bbox[1] + max(0, int((target_height - resized_size[1]) * 0.05))
        warped_cloth = Image.new("RGB", (width, height), (128, 128, 128))
        warped_mask = Image.new("L", (width, height), 0)
        warped_cloth.paste(cloth_resized, (paste_x, paste_y), mask_resized)
        warped_mask.paste(mask_resized, (paste_x, paste_y))

        if os.getenv("API_WARP_CLIP_TO_PARSE", "true").strip().lower() not in {"0", "false", "no"}:
            import cv2

            fit_seed = target_array | shoulder_band
            fit_mask = fit_seed.astype(np.uint8)
            fit_mask = cv2.morphologyEx(
                fit_mask,
                cv2.MORPH_CLOSE,
                cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7)),
                iterations=1,
            )
            fit_mask = cv2.dilate(
                fit_mask,
                cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)),
                iterations=1,
            )
            pasted_mask = np.array(warped_mask.convert("L")) >= 128
            fit_mask = (fit_mask > 0) & pasted_mask
            fit_mask_image = Image.fromarray((fit_mask.astype(np.uint8) * 255), mode="L")
            clipped_cloth = Image.new("RGB", (width, height), (128, 128, 128))
            clipped_cloth.paste(warped_cloth, (0, 0), fit_mask_image)
            warped_cloth = clipped_cloth
            warped_mask = fit_mask_image

        os.makedirs(os.path.dirname(output_cloth_path), exist_ok=True)
        os.makedirs(os.path.dirname(output_mask_path), exist_ok=True)
        warped_cloth.save(output_cloth_path, "JPEG", quality=95)
        warped_mask.save(output_mask_path)

        return {
            "mode": "geometric",
            "cloth_bbox": cloth_bbox,
            "target_bbox": target_bbox,
            "paste": [paste_x, paste_y, resized_size[0], resized_size[1]],
            "warp_mask_stats": binary_mask_stats(output_mask_path),
        }
    except Exception as exc:
        print(f"Could not create geometric cloth warp: {exc}")
        return None


def _debug_tile(label: str, path: Optional[str], size: tuple[int, int]) -> Image.Image:
    tile_width, tile_height = size
    label_height = 28
    tile = Image.new("RGB", size, (245, 245, 245))
    draw = ImageDraw.Draw(tile)
    font = ImageFont.load_default()
    draw.rectangle((0, 0, tile_width - 1, tile_height - 1), outline=(190, 190, 190))
    draw.text((8, 8), label, fill=(20, 20, 20), font=font)

    if not path or not os.path.exists(path):
        draw.text((8, label_height + 12), "missing", fill=(150, 0, 0), font=font)
        return tile

    try:
        original = Image.open(path)
        if "parse" in label and original.mode == "L":
            image = colorize_label_map(original)
        else:
            image = original.convert("RGB")
        image.thumbnail((tile_width - 16, tile_height - label_height - 16), Image.Resampling.LANCZOS)
        x = (tile_width - image.width) // 2
        y = label_height + (tile_height - label_height - image.height) // 2
        tile.paste(image, (x, y))
    except Exception as exc:
        draw.text((8, label_height + 12), f"load error: {exc}", fill=(150, 0, 0), font=font)

    return tile


def colorize_label_map(image: Image.Image) -> Image.Image:
    import numpy as np

    labels = np.array(image.convert("L"))
    rgb = np.zeros((labels.shape[0], labels.shape[1], 3), dtype=np.uint8)
    for index, color in enumerate(DEBUG_LABEL_COLORS):
        rgb[labels == index] = color
    unknown = labels >= len(DEBUG_LABEL_COLORS)
    rgb[unknown] = (255, 255, 255)
    return Image.fromarray(rgb, mode="RGB")


def create_debug_contact_sheet(
    session_id: str,
    person_filename: str,
    cloth_filename: str,
    final_result_path: Optional[str] = None,
) -> Optional[str]:
    try:
        temp_dir = CONFIG["temp_dir"]
        debug_dir = CONFIG["debug_dir"]
        person_png = person_filename.replace(".jpg", ".png")
        cloth_png = cloth_filename.replace(".jpg", ".png")
        person_stem = person_filename.replace(".jpg", "")

        items = [
            ("person", os.path.join(temp_dir, "image", person_filename)),
            ("product", os.path.join(temp_dir, "cloth", cloth_filename)),
            ("yolo box", os.path.join(debug_dir, f"{session_id}_cloth_bbox.jpg")),
            ("cloth mask", os.path.join(temp_dir, "cloth", "cloth-mask", cloth_png)),
            ("densepose", _first_existing([
                os.path.join(temp_dir, "image-densepose", person_filename.replace(".jpg", ".0001.jpg")),
                os.path.join(temp_dir, "image-densepose", person_filename),
            ])),
            ("openpose", os.path.join(temp_dir, "openpose_img", f"{person_stem}_rendered.png")),
            ("raw parse", os.path.join(temp_dir, "image-parse-v3", f"{person_stem}_gray.png")),
            ("parse labels", os.path.join(temp_dir, "image-parse-v3", person_png)),
            ("agnostic image", os.path.join(temp_dir, "agnostic-v3.2", person_png)),
            ("parse agnostic", os.path.join(temp_dir, "image-parse-agnostic-v3.2", person_png)),
            ("pf cloth", os.path.join(temp_dir, "pf_afn", session_id, "cloth.jpg")),
            ("pf edge", os.path.join(temp_dir, "pf_afn", session_id, "edge.png")),
            ("warped cloth", os.path.join(temp_dir, "test", "unpaired-cloth-warp", person_filename)),
            ("warp mask", os.path.join(temp_dir, "test", "unpaired-cloth-warp-mask", person_filename)),
            ("final", final_result_path),
        ]

        tile_size = (220, 280)
        columns = 4
        rows = (len(items) + columns - 1) // columns
        sheet = Image.new("RGB", (columns * tile_size[0], rows * tile_size[1]), (230, 230, 230))
        for index, (label, path) in enumerate(items):
            x = (index % columns) * tile_size[0]
            y = (index // columns) * tile_size[1]
            sheet.paste(_debug_tile(label, path, tile_size), (x, y))

        output_path = os.path.join(debug_dir, f"{session_id}_debug_sheet.jpg")
        sheet.save(output_path, "JPEG", quality=92)
        print(f"Debug contact sheet saved: {output_path}")
        return output_path
    except Exception as exc:
        print(f"Could not create debug contact sheet: {exc}")
        return None


def validate_pre_dci_inputs(session_id: str, person_filename: str, cloth_filename: str) -> dict:
    import numpy as np

    temp_dir = CONFIG["temp_dir"]
    errors = []
    warnings = []

    cloth_mask = os.path.join(
        temp_dir,
        "cloth",
        "cloth-mask",
        cloth_filename.replace(".jpg", ".png"),
    )
    if os.path.exists(cloth_mask):
        mask = np.array(Image.open(cloth_mask).convert("L"))
        coverage = float((mask >= 128).mean())
        if coverage < 0.01:
            errors.append(f"Cloth mask is nearly empty ({coverage:.1%} coverage)")
        elif coverage > 0.95:
            warnings.append(f"Cloth mask covers almost the whole image ({coverage:.1%})")
    else:
        errors.append(f"Missing cloth mask: {cloth_mask}")

    parse_path = os.path.join(
        temp_dir,
        "image-parse-v3",
        person_filename.replace(".jpg", ".png"),
    )
    raw_parse_path = os.path.join(
        temp_dir,
        "image-parse-v3",
        person_filename.replace(".jpg", "_gray.png"),
    )
    raw_parse_stats = parse_label_stats(raw_parse_path)
    parse_stats = parse_label_stats(parse_path)
    densepose_guidance_path = _first_existing([
        os.path.join(temp_dir, "image-densepose", person_filename.replace(".jpg", ".0001.jpg")),
        os.path.join(temp_dir, "image-densepose", person_filename),
    ])
    fallback_parse_looks_usable = bool(
        parse_stats
        and len(parse_stats["unique_labels"]) >= 4
        and parse_stats["upper_coverage"] >= 0.02
        and parse_stats["head_coverage"] >= 0.01
        and os.path.exists(densepose_guidance_path or "")
    )
    if raw_parse_stats and len(raw_parse_stats["unique_labels"]) < 4:
        message = (
            "Graphonomy human parse collapsed before fallback "
            f"(labels={raw_parse_stats['unique_labels']})"
        )
        if ALLOW_POSE_FALLBACK_PARSE or fallback_parse_looks_usable:
            warnings.append(message)
        else:
            errors.append(message)

    if os.path.exists(parse_path):
        parse = np.array(Image.open(parse_path).convert("L"))
        unique_labels = sorted(int(v) for v in np.unique(parse) if int(v) <= 19)
        if len(unique_labels) < 3:
            errors.append(f"Human parse collapsed to {len(unique_labels)} label(s): {unique_labels}")
        if parse_stats:
            if parse_stats["upper_coverage"] < 0.02:
                errors.append(
                    f"Human parse has almost no upper-clothes area "
                    f"({parse_stats['upper_coverage']:.1%})"
                )
            if parse_stats["head_coverage"] < 0.005:
                warnings.append(
                    f"Human parse has very little head/face area "
                    f"({parse_stats['head_coverage']:.1%})"
                )
            if parse_stats["arm_coverage"] < 0.005:
                warnings.append(
                    f"Human parse has very little arm area "
                    f"({parse_stats['arm_coverage']:.1%})"
                )
    else:
        errors.append(f"Missing human parse: {parse_path}")

    pose_path = os.path.join(
        temp_dir,
        "openpose_json",
        person_filename.replace(".jpg", "_keypoints.json"),
    )
    if os.path.exists(pose_path):
        with open(pose_path, "r", encoding="utf-8") as f:
            pose_label = json.load(f)
        people = pose_label.get("people", [])
        if not people:
            errors.append("OpenPose found no person")
        else:
            keypoints = people[0].get("pose_keypoints_2d", [])
            confident = sum(
                1
                for index in range(2, len(keypoints), 3)
                if float(keypoints[index]) > 0.05
            )
            if confident < 8:
                errors.append(f"OpenPose has too few confident body keypoints ({confident})")
    else:
        errors.append(f"Missing OpenPose JSON: {pose_path}")

    return {
        "strict": PREFLIGHT_STRICT,
        "errors": errors,
        "warnings": warnings,
        "parse_stats": parse_stats,
        "raw_parse_stats": raw_parse_stats,
    }


def validate_post_warp_inputs(session_id: str, person_filename: str) -> dict:
    temp_dir = CONFIG["temp_dir"]
    errors = []
    warnings = []

    warped_cloth_path = os.path.join(temp_dir, "test", "unpaired-cloth-warp", person_filename)
    warped_mask_path = os.path.join(temp_dir, "test", "unpaired-cloth-warp-mask", person_filename)

    if not os.path.exists(warped_cloth_path):
        errors.append(f"Missing warped cloth: {warped_cloth_path}")
    if not os.path.exists(warped_mask_path):
        errors.append(f"Missing warped cloth mask: {warped_mask_path}")

    warp_mask_stats = binary_mask_stats(warped_mask_path)
    if warp_mask_stats:
        coverage = warp_mask_stats["coverage"]
        if coverage < 0.06:
            errors.append(f"Warp mask is too small ({coverage:.1%} coverage)")
        elif coverage > 0.60:
            errors.append(f"Warp mask is too large ({coverage:.1%} coverage)")

        bbox_aspect = warp_mask_stats["bbox_aspect"]
        if bbox_aspect and not 0.25 <= bbox_aspect <= 1.25:
            warnings.append(f"Warp mask shape looks unusual (aspect={bbox_aspect:.2f})")

    return {
        "strict": PREFLIGHT_STRICT,
        "errors": errors,
        "warnings": warnings,
        "warp_mask_stats": warp_mask_stats,
    }


def prepare_dci_dataset(session_id: str, person_filename: str, cloth_filename: str):
    temp_dir = CONFIG["temp_dir"]
    dci_test_dir = os.path.join(temp_dir, "test")

    for subdir in DCI_SUBDIRS:
        os.makedirs(os.path.join(dci_test_dir, subdir), exist_ok=True)

    person_parse = person_filename.replace(".jpg", ".png")
    cloth_mask = cloth_filename.replace(".jpg", ".png")
    parse_stem = person_filename.replace(".jpg", "")
    parse_source_dir = os.path.join(temp_dir, "image-parse-v3")
    parse_src = os.path.join(parse_source_dir, person_parse)
    gray_parse_src = os.path.join(parse_source_dir, f"{parse_stem}_gray.png")
    if not os.path.exists(parse_src):
        parse_src = gray_parse_src
    parse_agnostic_src = os.path.join(temp_dir, "image-parse-agnostic-v3.2", person_parse)

    copies = {
        os.path.join(temp_dir, "image", person_filename): os.path.join(dci_test_dir, "image", person_filename),
        os.path.join(temp_dir, "cloth", cloth_filename): os.path.join(dci_test_dir, "cloth", cloth_filename),
        os.path.join(temp_dir, "cloth", "cloth-mask", cloth_mask): os.path.join(dci_test_dir, "cloth-mask", cloth_filename),
        os.path.join(temp_dir, "openpose_json", person_filename.replace(".jpg", "_keypoints.json")): os.path.join(dci_test_dir, "openpose_json", person_filename.replace(".jpg", "_keypoints.json")),
    }

    missing = [src for src, dst in copies.items() if not _copy_if_exists(src, dst)]
    if not normalize_parse_label_map(parse_src, os.path.join(dci_test_dir, "image-parse-v3", person_parse)):
        missing.append(parse_src)
    if not normalize_parse_label_map(parse_agnostic_src, os.path.join(dci_test_dir, "image-parse-agnostic-v3.2", person_parse)):
        missing.append(parse_agnostic_src)
    if missing:
        return {
            "success": False,
            "error": "Missing DCI-VTON inputs: " + ", ".join(missing),
        }

    pair_path = os.path.join(temp_dir, "test_pairs.txt")
    with open(pair_path, "w", encoding="utf-8") as f:
        f.write(f"{person_filename} {cloth_filename}\n")

    return {"success": True}


def prepare_pf_afn_inputs(
    session_id: str,
    person_path: str,
    cloth_path: str,
    cloth_mask_path: str,
) -> Optional[dict]:
    try:
        width = int(CONFIG["warp_width"])
        height = int(CONFIG["warp_height"])
        output_dir = os.path.join(CONFIG["pf_afn_input_dir"], session_id)
        os.makedirs(output_dir, exist_ok=True)

        pf_person_path = os.path.join(output_dir, "person.jpg")
        pf_cloth_path = os.path.join(output_dir, "cloth.jpg")
        pf_edge_path = os.path.join(output_dir, "edge.png")

        person = Image.open(person_path).convert("RGB").resize((width, height), Image.Resampling.BICUBIC)
        cloth = Image.open(cloth_path).convert("RGB")
        mask = Image.open(cloth_mask_path).convert("L")
        if cloth.size != mask.size:
            mask = mask.resize(cloth.size, Image.Resampling.NEAREST)

        import numpy as np

        mask_array = np.array(mask) >= 128
        if not mask_array.any():
            return None

        ys, xs = np.where(mask_array)
        x_min, x_max = int(xs.min()), int(xs.max())
        y_min, y_max = int(ys.min()), int(ys.max())
        cloth_crop = cloth.crop((x_min, y_min, x_max + 1, y_max + 1))
        mask_crop = mask.crop((x_min, y_min, x_max + 1, y_max + 1))

        crop_width, crop_height = cloth_crop.size
        target_width = int(width * float(os.getenv("API_PFAFN_CLOTH_WIDTH_RATIO", "0.78")))
        target_height = int(height * float(os.getenv("API_PFAFN_CLOTH_HEIGHT_RATIO", "0.76")))
        scale = min(target_width / max(1, crop_width), target_height / max(1, crop_height))
        resized_size = (
            max(1, int(crop_width * scale)),
            max(1, int(crop_height * scale)),
        )
        cloth_resized = cloth_crop.resize(resized_size, Image.Resampling.BICUBIC)
        mask_resized = mask_crop.resize(resized_size, Image.Resampling.NEAREST)

        paste_x = (width - resized_size[0]) // 2
        paste_y = max(0, int(height * 0.10) + (target_height - resized_size[1]) // 2)

        normalized_cloth = Image.new("RGB", (width, height), (255, 255, 255))
        normalized_mask = Image.new("L", (width, height), 0)
        normalized_cloth.paste(cloth_resized, (paste_x, paste_y), mask_resized)
        normalized_mask.paste(mask_resized, (paste_x, paste_y))

        person.save(pf_person_path, "JPEG", quality=95)
        normalized_cloth.save(pf_cloth_path, "JPEG", quality=95)
        normalized_mask.save(pf_edge_path)

        return {
            "person": pf_person_path,
            "cloth": pf_cloth_path,
            "edge": pf_edge_path,
            "cloth_bbox": [x_min, y_min, x_max, y_max],
            "paste": [paste_x, paste_y, resized_size[0], resized_size[1]],
            "edge_stats": binary_mask_stats(pf_edge_path),
        }
    except Exception as exc:
        print(f"Could not prepare PF-AFN inputs: {exc}")
        return None


def run_cloth_warping(session_id: str, person_filename: str, cloth_filename: str):
    """
    Stage 2: Run PF-AFN cloth warping
    """
    try:
        import subprocess
        
        temp_dir = CONFIG["temp_dir"]
        dci_test_dir = os.path.join(temp_dir, "test")
        person_path = os.path.join(temp_dir, "image", person_filename)
        cloth_path = os.path.join(temp_dir, "cloth", cloth_filename)
        cloth_mask_path = os.path.join(
            temp_dir,
            "cloth",
            "cloth-mask",
            cloth_filename.replace(".jpg", ".png")
        )
        warped_cloth_path = os.path.join(dci_test_dir, "unpaired-cloth-warp", person_filename)
        warped_mask_path = os.path.join(dci_test_dir, "unpaired-cloth-warp-mask", person_filename)

        if CONFIG["warp_mode"] == "geometric":
            print("   Running geometric cloth warp...")
            geometric_result = create_geometric_cloth_warp(session_id, person_filename, cloth_filename)
            if not geometric_result:
                return {
                    "success": False,
                    "error": "Geometric cloth warping failed"
                }
            print("   Cloth warping complete")
            return {
                "success": True,
                "warp_mode": "geometric",
                "pf_afn_warp_stats": None,
                "pf_afn_fit_metrics": None,
                "warp_auto_reasons": ["forced_geometric"],
                "pf_afn_inputs": None,
                "geometric_warp": geometric_result,
            }

        pf_inputs = prepare_pf_afn_inputs(session_id, person_path, cloth_path, cloth_mask_path)
        pf_person_path = pf_inputs["person"] if pf_inputs else person_path
        pf_cloth_path = pf_inputs["cloth"] if pf_inputs else cloth_path
        pf_edge_path = pf_inputs["edge"] if pf_inputs else cloth_mask_path
        
        print("   Running PF-AFN warping module...")
        
        warp_command = [
            CONFIG["python_pfafen"],
            CONFIG["warping_script"],
            "--repo-dir", CONFIG["pf_afn_repo"],
            "--checkpoint", CONFIG["warp_checkpoint"],
            "--person", pf_person_path,
            "--cloth", pf_cloth_path,
            "--edge", pf_edge_path,
            "--output-cloth", warped_cloth_path,
            "--output-mask", warped_mask_path,
            "--width", CONFIG["warp_width"],
            "--height", CONFIG["warp_height"],
            "--gpu-id", "0",
        ]
        
        result = subprocess.run(
            warp_command,
            capture_output=True,
            text=True,
            env=subprocess_env_for_python(CONFIG["python_pfafen"])
        )
        
        if result.returncode != 0:
            details = "\n".join(part for part in [result.stdout, result.stderr] if part)
            print(f"Warping error: {details}")
            return {
                "success": False,
                "error": f"Cloth warping failed: {details}"
            }
        
        if not os.path.exists(warped_cloth_path) or not os.path.exists(warped_mask_path):
            return {
                "success": False,
                "error": "PF-AFN completed but did not produce warped cloth/mask outputs"
            }

        parse_path = os.path.join(dci_test_dir, "image-parse-v3", person_filename.replace(".jpg", ".png"))
        refit_result = refit_pf_afn_warp_to_parse(
            warped_cloth_path,
            warped_mask_path,
            parse_path,
            cloth_path,
            cloth_mask_path,
        )
        if refit_result and refit_result.get("applied"):
            after = refit_result.get("after") or {}
            print(
                "   Refit PF-AFN warp to parse "
                f"IoU={after.get('warp_target_iou')}, "
                f"target_covered={after.get('target_covered_by_warp')}"
            )

        warp_stats = binary_mask_stats(warped_mask_path)
        cloth_mask_stats = binary_mask_stats(cloth_mask_path)
        fit_metrics = warp_parse_fit_metrics(warped_mask_path, parse_path)
        use_geometric = CONFIG["warp_mode"] == "geometric"
        auto_reasons = []
        if CONFIG["warp_mode"] == "auto" and warp_stats and cloth_mask_stats:
            if warp_stats["coverage"] < max(0.12, cloth_mask_stats["coverage"] * 0.50):
                auto_reasons.append("pf_afn_mask_too_small")
            if fit_metrics:
                min_iou = float(os.getenv("API_WARP_AUTO_MIN_IOU", "0.62"))
                min_target_coverage = float(os.getenv("API_WARP_AUTO_MIN_TARGET_COVERAGE", "0.72"))
                min_inside = float(os.getenv("API_WARP_AUTO_MIN_INSIDE_TARGET", "0.86"))
                center_limit = float(os.getenv("API_WARP_AUTO_MAX_CENTER_DELTA", "28"))
                center_delta = fit_metrics.get("center_delta_px") or [0, 0]
                if fit_metrics["warp_target_iou"] < min_iou:
                    auto_reasons.append("pf_afn_low_parse_iou")
                if fit_metrics["target_covered_by_warp"] < min_target_coverage:
                    auto_reasons.append("pf_afn_under_covers_torso")
                if fit_metrics["warp_inside_target"] < min_inside:
                    auto_reasons.append("pf_afn_leaks_outside_torso")
                if max(abs(float(center_delta[0])), abs(float(center_delta[1]))) > center_limit:
                    auto_reasons.append("pf_afn_off_center")
            use_geometric = bool(auto_reasons)

        warp_mode = "pf_afn"
        geometric_result = None
        if use_geometric:
            geometric_result = create_geometric_cloth_warp(session_id, person_filename, cloth_filename)
            if geometric_result:
                warp_mode = "geometric"
                print(f"   PF-AFN warp looked weak; using geometric cloth warp fallback ({', '.join(auto_reasons) or 'forced'})")

        print("   Cloth warping complete")
        return {
            "success": True,
            "warp_mode": warp_mode,
            "pf_afn_warp_stats": warp_stats,
            "pf_afn_fit_metrics": fit_metrics,
            "warp_auto_reasons": auto_reasons,
            "pf_afn_inputs": pf_inputs,
            "pf_afn_refit": refit_result,
            "geometric_warp": geometric_result,
        }
        
    except Exception as e:
        print(f"Error in cloth warping: {e}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "error": str(e)
        }


def run_diffusion_model(session_id: str, person_filename: str):
    """
    Stage 3: Run DCI-VTON diffusion model for final result
    """
    try:
        import subprocess
        import glob
        
        temp_dir = CONFIG["temp_dir"]
        final_output_dir = CONFIG["final_output_dir"]
        result_dir = os.path.join(final_output_dir, "result")
        expected_result = os.path.join(result_dir, person_filename.replace(".jpg", ".png"))
        
        print("   Running DCI-VTON diffusion model...")
        if os.path.exists(expected_result):
            os.remove(expected_result)
        
        diffusion_command = [
            CONFIG["python_dci_vton"],
            CONFIG["diffusion_script"],
            "--plms",
            "--gpu_id", "0",
            "--ddim_steps", CONFIG["diffusion_steps"],
            "--num_workers", "0",
            "--outdir", final_output_dir,
            "--config", CONFIG["diffusion_config"],
            "--ckpt", CONFIG["diffusion_checkpoint"],
            "--dataroot", temp_dir,
            "--seed", "23",
            "--scale", "1",
            "--H", "512",
            "--W", "512",
            "--precision", CONFIG["diffusion_precision"],
            "--unpaired"
        ]
        
        result = subprocess.run(
            diffusion_command,
            cwd=CONFIG["diffusion_workdir"],
            capture_output=True,
            text=True,
            env=subprocess_env_for_python(CONFIG["python_dci_vton"])
        )
        
        if result.returncode != 0:
            print(f"Diffusion error: {result.stderr}")
            return {
                "success": False,
                "error": f"Diffusion model failed: {result.stderr}",
            }
        
        if not os.path.exists(expected_result):
            result_files = glob.glob(os.path.join(result_dir, "*.png"))
            latest_result = max(result_files, key=os.path.getmtime) if result_files else None
            return {
                "success": False,
                "error": (
                    f"No session result generated at {expected_result}. "
                    f"Latest result was {latest_result or 'none'}"
                )
            }
        
        # Copy to a session-specific name
        final_result_path = os.path.join(result_dir, f"{session_id}_result.png")
        shutil.copy(expected_result, final_result_path)
        
        print(f"   Final result saved: {final_result_path}")
        
        return {
            "success": True,
            "result_path": final_result_path
        }
        
    except Exception as e:
        print(f"Error in diffusion model: {e}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "error": str(e)
        }


def save_base64_image(base64_str: str, output_path: str):
    """Convert base64 string to image and save it"""
    try:
        # Remove data URL prefix if present
        if "," in base64_str:
            base64_str = base64_str.split(",")[1]
        
        image_data = base64.b64decode(base64_str)
        image = Image.open(BytesIO(image_data))
        
        # Convert to RGB if needed
        if image.mode != 'RGB':
            image = image.convert('RGB')
        
        # Resize to 768x1024
        image_resized = image.resize((768, 1024), Image.Resampling.BILINEAR)
        image_resized.save(output_path, "JPEG")
        
        return True
    except Exception as e:
        print(f"Error saving base64 image: {e}")
        return False


def process_virtual_tryon(
    person_image_path: str,
    cloth_image_path: str,
    session_id: str,
    product_category: Optional[str] = None,
    product_type: Optional[str] = None,
):
    """
    Main processing pipeline for virtual try-on
    """
    try:
        import numpy as np

        temp_dir = CONFIG["temp_dir"]
        original_person_image_path = person_image_path
        detector = results = segmentor = runner = openpose_runner = inference_runner = None
        person_img = person_img_resized = cloth_img = cloth_img_resized = None
        im_parse = agnostic = None
        output_dir_person = os.path.join(temp_dir, "image")
        output_dir_cloth = os.path.join(temp_dir, "cloth")
        
        # Generate unique filenames
        person_filename = f"{session_id}_person.jpg"
        cloth_filename = f"{session_id}_cloth.jpg"
        
        person_save_path = os.path.join(output_dir_person, person_filename)
        cloth_save_path = os.path.join(output_dir_cloth, cloth_filename)
        
        # Copy/resize images
        person_img = Image.open(person_image_path).convert("RGB")
        person_img_resized = person_img.resize((768, 1024), Image.Resampling.BILINEAR)
        person_img_resized.save(person_save_path, "JPEG")
        
        cloth_img = Image.open(cloth_image_path).convert("RGB")
        cloth_img_resized = cloth_img.resize((768, 1024), Image.Resampling.BILINEAR)
        cloth_img_resized.save(cloth_save_path, "JPEG")
        
        # Update paths
        person_image_path = person_save_path
        cloth_image_path = cloth_save_path
        
        print(f"[1/6] YOLO Detection...")
        # 1. YOLO Detection
        detector = YOLODetector(weights_path=CONFIG["yolo_weights"], device='cpu')
        category_hint = product_type or product_category
        results = detector.detect(cloth_image_path)
        boxes = detector.get_bounding_boxes(results)
        selected_box = detector.select_best_garment_box(boxes, cloth_image_path, category_hint)
        if selected_box is None:
            selected_box = detector.foreground_fallback_box(cloth_image_path)
        
        if selected_box:
            x1, y1, x2, y2 = selected_box['box']
            print(
                "   Selected clothing box "
                f"{selected_box['class_name']} {selected_box['confidence']:.3f}: "
                f"({x1}, {y1}, {x2}, {y2})"
            )
        else:
            cloth_width, cloth_height = cloth_img_resized.size
            x1, y1, x2, y2 = 0, 0, cloth_width, cloth_height
            print("   No clothing box detected; using full cloth image for segmentation")
        yolo_detection = {
            "selected": selected_box,
            "product_category": product_category,
            "product_type": product_type,
            "category_hint": category_hint,
            "proposal_count": len(boxes),
            "proposals": boxes[:20],
            "used_full_image_fallback": selected_box is None,
            "final_box": [x1, y1, x2, y2],
        }
        with open(os.path.join(CONFIG["debug_dir"], f"{session_id}_yolo_detection.json"), "w", encoding="utf-8") as f:
            json.dump(yolo_detection, f, indent=2)
        draw_bbox_debug(
            cloth_image_path,
            [x1, y1, x2, y2],
            os.path.join(CONFIG["debug_dir"], f"{session_id}_cloth_bbox.jpg"),
        )
        
        print(f"[2/6] FastSAM Segmentation...")
        # 2. Segmentation
        bbox = [x1, y1, x2, y2]
        segmentor = FastSAMInference(CONFIG["fastsam_model"], cloth_image_path)
        cloth_mask_path = segmentor.run_inference(bbox)
        cleaned_stats = clean_cloth_mask(cloth_mask_path, cloth_image_path)
        if cleaned_stats:
            print(f"   Cleaned cloth mask coverage: {cleaned_stats['coverage']:.1%}")
        
        print(f"[3/6] DensePose...")
        # 3. DensePose
        densepose_output_dir = os.path.join(temp_dir, "image-densepose")
        runner = DensePoseRunner(
            CONFIG["densepose_cfg"],
            CONFIG["densepose_weights"],
            person_image_path,
            densepose_output_dir
        )
        runner.run()
        
        print(f"[4/6] OpenPose...")
        # 4. OpenPose
        openpose_output_dir = os.path.join(temp_dir, "openpose_img")
        openpose_json_dir = os.path.join(temp_dir, "openpose_json")
        
        openpose_runner = OpenPoseRunner(
            CONFIG["openpose_root"],
            person_image_path,
            openpose_output_dir,
            openpose_json_dir
        )
        openpose_runner.run()
        pose_name = f"{os.path.splitext(person_filename)[0]}_keypoints.json"
        pose_path = os.path.join(openpose_json_dir, pose_name)
        if sanitize_openpose_json(pose_path, person_img_resized.size):
            print("   Filled missing OpenPose hip keypoints for DCI")
        
        print(f"[5/6] Human Parsing (Graphonomy)...")
        # 5. Human Parsing
        parse_output_dir = os.path.join(temp_dir, "image-parse-v3")
        output_name = os.path.splitext(person_filename)[0]
        requirements_path = os.path.join(CONFIG["graphonomy_repo"], 'requirements.txt')
        
        inference_runner = GraphonomyInference(
            repo_dir=CONFIG["graphonomy_repo"],
            requirements_path=requirements_path,
            python_executable=CONFIG["python_torch112"]
        )
        inference_runner.run_inference(
            CONFIG["graphonomy_weights"],
            original_person_image_path,
            parse_output_dir,
            output_name
        )

        gray_parse_path = os.path.join(parse_output_dir, f"{output_name}_gray.png")
        parse_path = os.path.join(parse_output_dir, person_filename.replace(".jpg", ".png"))
        resize_label_map(gray_parse_path, person_img_resized.size)
        if os.path.exists(gray_parse_path):
            normalize_parse_label_map(gray_parse_path, parse_path)
            resize_label_map(parse_path, person_img_resized.size)

        pose_name = f"{output_name}_keypoints.json"
        pose_path = os.path.join(openpose_json_dir, pose_name)
        densepose_guidance_path = _first_existing([
            os.path.join(densepose_output_dir, person_filename.replace(".jpg", ".0001.jpg")),
            os.path.join(densepose_output_dir, person_filename),
        ])
        if os.path.exists(parse_path):
            refine_human_parse(person_image_path, parse_path, pose_path, densepose_guidance_path)
            refined_stats = parse_label_stats(parse_path)
            if refined_stats:
                print(
                    "   Refined parse "
                    f"upper={refined_stats['upper_coverage']:.1%}, "
                    f"arms={refined_stats['arm_coverage']:.1%}, "
                    f"labels={refined_stats['unique_labels']}"
                )

        fallback_needed = False
        if os.path.exists(parse_path):
            current_stats = parse_label_stats(parse_path)
            fallback_needed = parse_is_collapsed(parse_path)
            if current_stats:
                fallback_needed = fallback_needed or (
                    current_stats["upper_coverage"] > 0.65
                    and current_stats["arm_coverage"] < 0.01
                )

        if os.path.exists(parse_path) and fallback_needed and os.path.exists(pose_path):
            print("   Graphonomy parse collapsed; using OpenPose fallback parse")
            create_pose_fallback_parse(
                person_image_path,
                pose_path,
                parse_path,
                densepose_guidance_path,
            )
            refine_human_parse(person_image_path, parse_path, pose_path, densepose_guidance_path)
        
        print(f"[6/6] Agnostic Generation...")
        # 6. Parse Agnostic
        agnostic_save_dir = os.path.join(temp_dir, "agnostic-v3.2")
        process_image(person_image_path, openpose_json_dir, parse_output_dir, agnostic_save_dir)
        
        # Final agnostic parse
        parse_agnostic_output = os.path.join(temp_dir, "image-parse-agnostic-v3.2")
        
        if os.path.exists(pose_path):
            with open(pose_path, 'r') as f:
                pose_label = json.load(f)
                pose_data = np.array(pose_label['people'][0]['pose_keypoints_2d']).reshape((-1, 3))[:, :2]
            
            parse_name = person_filename.replace('.jpg', '.png')
            im_parse = Image.open(os.path.join(parse_output_dir, parse_name))
            agnostic = get_im_parse_agnostic(im_parse, pose_data)
            agnostic.save(os.path.join(parse_agnostic_output, parse_name))
        
        print(f"Processing complete for session {session_id}")

        preflight = validate_pre_dci_inputs(session_id, person_filename, cloth_filename)
        if preflight["errors"] and PREFLIGHT_STRICT:
            debug_sheet_path = create_debug_contact_sheet(session_id, person_filename, cloth_filename)
            return {
                "success": False,
                "error": "Preflight failed: " + "; ".join(preflight["errors"]),
                "warnings": preflight["warnings"],
                "debug_sheet_path": debug_sheet_path,
                "session_id": session_id,
            }

        dataset_result = prepare_dci_dataset(session_id, person_filename, cloth_filename)
        if not dataset_result["success"]:
            create_debug_contact_sheet(session_id, person_filename, cloth_filename)
            return dataset_result

        detector = results = segmentor = runner = openpose_runner = inference_runner = None
        person_img = person_img_resized = cloth_img = cloth_img_resized = None
        im_parse = agnostic = None
        release_ml_memory()
        
        # Stage 2: Cloth Warping (PF-AFN)
        print(f"[Stage 2] Running cloth warping...")
        warp_result = run_cloth_warping(session_id, person_filename, cloth_filename)
        
        if not warp_result["success"]:
            create_debug_contact_sheet(session_id, person_filename, cloth_filename)
            return warp_result

        post_warp = validate_post_warp_inputs(session_id, person_filename)
        post_warp["warp_mode"] = warp_result.get("warp_mode")
        post_warp["pf_afn_warp_stats"] = warp_result.get("pf_afn_warp_stats")
        post_warp["pf_afn_inputs"] = warp_result.get("pf_afn_inputs")
        post_warp["pf_afn_refit"] = warp_result.get("pf_afn_refit")
        post_warp["geometric_warp"] = warp_result.get("geometric_warp")
        if post_warp["errors"] and PREFLIGHT_STRICT:
            debug_sheet_path = create_debug_contact_sheet(session_id, person_filename, cloth_filename)
            return {
                "success": False,
                "error": "Warp preflight failed: " + "; ".join(post_warp["errors"]),
                "warnings": post_warp["warnings"],
                "debug_sheet_path": debug_sheet_path,
                "preflight": preflight,
                "post_warp": post_warp,
                "session_id": session_id,
            }

        detector = results = segmentor = runner = openpose_runner = inference_runner = None
        person_img = person_img_resized = cloth_img = cloth_img_resized = None
        im_parse = agnostic = None
        import gc
        gc.collect()
        try:
            import torch
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
        except Exception:
            pass
        
        # Stage 3: Diffusion Model (DCI-VTON)
        print(f"[Stage 3] Running diffusion model for final result...")
        diffusion_result = run_diffusion_model(session_id, person_filename)
        
        if not diffusion_result["success"]:
            create_debug_contact_sheet(session_id, person_filename, cloth_filename)
            return diffusion_result
        
        # Return the final result path
        final_result_path = diffusion_result["result_path"]
        debug_sheet_path = create_debug_contact_sheet(
            session_id,
            person_filename,
            cloth_filename,
            final_result_path,
        )
        
        return {
            "success": True,
            "result_path": final_result_path,
            "debug_sheet_path": debug_sheet_path,
            "preflight": preflight,
            "post_warp": post_warp,
            "yolo_detection": yolo_detection,
            "session_id": session_id
        }
        
    except Exception as e:
        print(f"Error in processing: {e}")
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "error": str(e),
            "session_id": session_id
        }


def simple_process_tryon(person_path: str, cloth_path: str, session_id: str) -> dict:
    """
    Simplified virtual try-on using image overlay
    Works immediately without ML models
    """
    try:
        print(f"[Simplified Mode] Processing session {session_id}")
        
        # Create output directory
        output_dir = os.path.join(CONFIG["final_output_dir"], "result")
        os.makedirs(output_dir, exist_ok=True)
        
        # Output path
        output_path = os.path.join(output_dir, f"{session_id}_result.jpg")
        
        # Run the overlay
        success = advanced_overlay_tryon(person_path, cloth_path, output_path)
        
        if success:
            print(f"Simplified try-on complete: {output_path}")
            return {
                "success": True,
                "result_path": output_path,
                "session_id": session_id,
                "mode": "simplified_overlay"
            }
        else:
            return {
                "success": False,
                "error": "Overlay processing failed",
                "session_id": session_id
            }
    except Exception as e:
        print(f"Error in simplified processing: {e}")
        return {
            "success": False,
            "error": str(e),
            "session_id": session_id
        }


def _required_ml_paths() -> dict:
    return {
        key: os.path.exists(CONFIG[key])
        for key in [
            "yolo_weights",
            "fastsam_model",
            "densepose_cfg",
            "densepose_weights",
            "openpose_root",
            "graphonomy_repo",
            "graphonomy_weights",
            "warping_script",
            "warp_checkpoint",
            "diffusion_script",
            "diffusion_checkpoint",
            "diffusion_config",
            "diffusion_workdir",
            "python_pfafen",
            "python_dci_vton",
            "pf_afn_repo",
        ]
    }


def ml_stack_ready() -> bool:
    return ML_MODELS_AVAILABLE and all(_required_ml_paths().values())


def active_processing_mode() -> str:
    if PROCESSING_MODE == "ml":
        return "ml" if ML_MODELS_AVAILABLE else "simplified"
    if PROCESSING_MODE == "auto" and ml_stack_ready():
        return "ml"
    return "simplified"


@app.get("/api/tryon/readiness")
def get_readiness():
    paths = _required_ml_paths()
    return {
        "configured_mode": PROCESSING_MODE,
        "active_mode": active_processing_mode(),
        "ml_import_error": ML_IMPORT_ERROR,
        "ml_models_available": ML_MODELS_AVAILABLE,
        "ml_stack_ready": ml_stack_ready(),
        "preflight_strict": PREFLIGHT_STRICT,
        "allow_pose_fallback_parse": ALLOW_POSE_FALLBACK_PARSE,
        "diffusion_steps": CONFIG["diffusion_steps"],
        "diffusion_precision": CONFIG["diffusion_precision"],
        "graphonomy_scales": CONFIG["graphonomy_scales"],
        "warp_mode": CONFIG["warp_mode"],
        "warp_size": [CONFIG["warp_width"], CONFIG["warp_height"]],
        "required_paths": paths,
    }


def run_tryon_pipeline(
    person_path: str,
    cloth_path: str,
    session_id: str,
    product_category: Optional[str] = None,
    product_type: Optional[str] = None,
) -> dict:
    mode = active_processing_mode()

    if mode == "ml":
        result = process_virtual_tryon(
            person_path,
            cloth_path,
            session_id,
            product_category=product_category,
            product_type=product_type,
        )
        if result.get("success") or not FALLBACK_TO_SIMPLE:
            result["mode"] = "ml_pipeline"
            return result

        print(f"ML pipeline failed, falling back to simplified mode: {result.get('error')}")

    return simple_process_tryon(person_path, cloth_path, session_id)


@app.get("/")
def root():
    """Health check endpoint"""
    return {
        "status": "running",
        "service": "Virtual Try-On API",
        "version": "1.0.0",
        "configured_mode": PROCESSING_MODE,
        "active_mode": active_processing_mode(),
        "ml_models_available": ML_MODELS_AVAILABLE,
        "ml_stack_ready": ml_stack_ready(),
        "ml_import_error": ML_IMPORT_ERROR
    }


@app.post("/api/tryon/upload", response_model=TryOnResponse)
async def upload_images(
    person_image: UploadFile = File(...),
    cloth_image: UploadFile = File(...),
    product_category: Optional[str] = Form(None),
    product_type: Optional[str] = Form(None),
):
    """
    Upload person and clothing images for virtual try-on
    """
    session_id = str(uuid.uuid4())
    
    try:
        # Save uploaded files
        temp_person_path = os.path.join(CONFIG["temp_dir"], f"{session_id}_person_upload.jpg")
        temp_cloth_path = os.path.join(CONFIG["temp_dir"], f"{session_id}_cloth_upload.jpg")
        
        with open(temp_person_path, "wb") as f:
            f.write(await person_image.read())
        
        with open(temp_cloth_path, "wb") as f:
            f.write(await cloth_image.read())
        
        result = run_tryon_pipeline(
            temp_person_path,
            temp_cloth_path,
            session_id,
            product_category=product_category,
            product_type=product_type,
        )
        
        if result["success"]:
            return TryOnResponse(
                success=True,
                message="Processing completed successfully",
                session_id=session_id,
                result_image_url=f"/api/tryon/result/{session_id}"
            )
        else:
            raise HTTPException(status_code=500, detail=result.get("error", "Processing failed"))
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/tryon/process-base64", response_model=TryOnResponse)
async def process_base64_images(request: TryOnRequest):
    """
    Process base64 encoded images for virtual try-on
    """
    try:
        temp_person_path = os.path.join(CONFIG["temp_dir"], f"{request.session_id}_person.jpg")
        temp_cloth_path = os.path.join(CONFIG["temp_dir"], f"{request.session_id}_cloth.jpg")
        
        # Save base64 images
        if request.person_image_base64:
            if not save_base64_image(request.person_image_base64, temp_person_path):
                raise HTTPException(status_code=400, detail="Invalid person image")
        
        if request.cloth_image_base64:
            if not save_base64_image(request.cloth_image_base64, temp_cloth_path):
                raise HTTPException(status_code=400, detail="Invalid cloth image")
        
        result = run_tryon_pipeline(
            temp_person_path,
            temp_cloth_path,
            request.session_id,
            product_category=request.product_category,
            product_type=request.product_type,
        )
        
        if result["success"]:
            return TryOnResponse(
                success=True,
                message="Processing completed successfully",
                session_id=request.session_id,
                result_image_url=f"/api/tryon/result/{request.session_id}"
            )
        else:
            raise HTTPException(status_code=500, detail=result.get("error", "Processing failed"))
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/tryon/result/{session_id}")
async def get_result(session_id: str):
    """
    Get the result image for a session
    """
    # Prefer the diffusion result if it exists.
    final_result_path = os.path.join(
        CONFIG["final_output_dir"],
        "result",
        f"{session_id}_result.png"
    )
    
    if os.path.exists(final_result_path):
        return FileResponse(final_result_path, media_type="image/png")
    
    # Fallback to the simplified overlay result.
    simple_result_path = os.path.join(
        CONFIG["final_output_dir"],
        "result",
        f"{session_id}_result.jpg"
    )

    if os.path.exists(simple_result_path):
        return FileResponse(simple_result_path, media_type="image/jpeg")

    raise HTTPException(status_code=404, detail="Result image not found")


@app.get("/api/tryon/status/{session_id}")
async def get_status(session_id: str):
    """
    Check the processing status of a session
    """
    # Check for final diffusion result
    final_result_path = os.path.join(
        CONFIG["final_output_dir"],
        "result",
        f"{session_id}_result.png"
    )
    
    if os.path.exists(final_result_path):
        return {
            "status": "completed",
            "session_id": session_id,
            "result_url": f"/api/tryon/result/{session_id}",
            "stage": "diffusion_complete",
            "mode": "ml_pipeline"
        }

    simple_result_path = os.path.join(
        CONFIG["final_output_dir"],
        "result",
        f"{session_id}_result.jpg"
    )

    if os.path.exists(simple_result_path):
        return {
            "status": "completed",
            "session_id": session_id,
            "result_url": f"/api/tryon/result/{session_id}",
            "stage": "overlay_complete",
            "mode": "simplified"
        }
    
    # Check for warping completion
    warp_path = os.path.join(
        CONFIG["temp_dir"],
        "unpaired-cloth-warp"
    )
    
    if os.path.exists(warp_path) and any(
        name.startswith(f"{session_id}_") for name in os.listdir(warp_path)
    ):
        return {
            "status": "processing",
            "session_id": session_id,
            "stage": "running_diffusion"
        }
    
    # Check for preprocessing completion
    agnostic_path = os.path.join(
        CONFIG["temp_dir"],
        "image-parse-agnostic-v3.2",
        f"{session_id}_person.png"
    )
    
    if os.path.exists(agnostic_path):
        return {
            "status": "processing",
            "session_id": session_id,
            "stage": "running_warping"
        }
    
    # Still preprocessing
    return {
        "status": "processing",
        "session_id": session_id,
        "stage": "preprocessing"
    }


@app.delete("/api/tryon/cleanup/{session_id}")
def cleanup_session(session_id: str):
    """
    Clean up temporary files for a session
    """
    try:
        patterns = [
            f"{session_id}_*",
        ]
        
        # Clean up temp files
        for pattern in patterns:
            import glob
            for file_path in glob.glob(os.path.join(CONFIG["temp_dir"], "**", pattern), recursive=True):
                try:
                    os.remove(file_path)
                except Exception as e:
                    print(f"Error deleting {file_path}: {e}")
        
        return {"success": True, "message": "Session cleaned up"}
    except Exception as e:
        return {"success": False, "message": str(e)}


if __name__ == "__main__":
    import uvicorn
    print("Starting Virtual Try-On API Server...")
    print("API Documentation: http://localhost:8000/docs")
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=False)
