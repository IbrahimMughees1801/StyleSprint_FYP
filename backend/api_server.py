from fastapi import FastAPI, UploadFile, File, HTTPException
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
from PIL import Image

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

ML_IMPORT_ERROR = None
ML_MODELS_AVAILABLE = False

if PROCESSING_MODE in {"ml", "auto"}:
    try:
        from models.yolo import YOLODetector
        from models.SegmentationSam2 import FastSAMInference
        from models.DensePose import DensePoseRunner
        from models.OpenPose import OpenPoseRunner
        from models.ParseAgnostic import GraphonomyInference
        from models.helper import process_image, get_im_parse_agnostic
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
CONFIG = {
    # Stage 1: Preprocessing models
    "yolo_weights": str(PROJECT_DIR / "weights" / "best.pt"),
    "fastsam_model": str(PROJECT_DIR / "weights" / "FastSAM-s.pt"),
    "densepose_cfg": str(BASE_DIR / "third_party" / "detectron2" / "projects" / "DensePose" / "configs" / "densepose_rcnn_R_50_FPN_s1x.yaml"),
    "densepose_weights": str(PROJECT_DIR / "weights" / "model_final_162be9.pkl"),
    "openpose_root": str(BASE_DIR / "third_party" / "openpose" / "openpose"),
    "graphonomy_repo": str(BASE_DIR / "third_party" / "Graphonomy"),
    "graphonomy_weights": str(PROJECT_DIR / "weights" / "inference.pth"),
    
    # Stage 2: Warping (PF-AFN)
    "warping_script": str(BASE_DIR / "pf_afn_warp_export.py"),
    "pf_afn_repo": str(BASE_DIR / "third_party" / "PF-AFN" / "PF-AFN_test"),
    "warp_checkpoint": str(BASE_DIR / "third_party" / "PF-AFN" / "PF-AFN_test" / "checkpoints" / "PFAFN" / "warp_model_final.pth"),
    
    # Stage 3: Diffusion (DCI-VTON)
    "diffusion_script": str(BASE_DIR / "third_party" / "DCI-VTON-Virtual-Try-On" / "test.py"),
    "diffusion_checkpoint": str(BASE_DIR / "third_party" / "DCI-VTON-Virtual-Try-On" / "checkpoints" / "viton512_v2.ckpt"),
    "diffusion_config": str(BASE_DIR / "third_party" / "DCI-VTON-Virtual-Try-On" / "configs" / "viton512_v2.yaml"),
    "diffusion_workdir": str(BASE_DIR / "third_party" / "DCI-VTON-Virtual-Try-On"),
    "diffusion_steps": os.getenv("API_DIFFUSION_STEPS", "30"),
    
    # Python environments
    "python_torch112": r"C:\Users\muhdi\miniconda3\envs\torch112\python.exe",
    "python_dci_vton": r"C:\Users\muhdi\miniconda3\envs\dci-vton\python.exe",
    "python_pfafen": r"C:\Users\muhdi\miniconda3\envs\pfafen-gpu-clean\python.exe",
    
    # Directories
    "temp_dir": str(BASE_DIR / "temp_uploads"),
    "output_dir": str(BASE_DIR / "results"),
    "final_output_dir": str(BASE_DIR / "FINAL")
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


class TryOnRequest(BaseModel):
    session_id: str
    person_image_base64: Optional[str] = None
    cloth_image_base64: Optional[str] = None


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
    path_parts = [
        str(env_root),
        str(env_root / "Library" / "bin"),
        str(env_root / "DLLs"),
        str(env_root / "Scripts"),
        str(env_root / "bin"),
    ]
    env["PATH"] = os.pathsep.join(path_parts + [env.get("PATH", "")])
    env["CUDA_VISIBLE_DEVICES"] = env.get("CUDA_VISIBLE_DEVICES") or "0"
    return env


def _copy_if_exists(src: str, dst: str) -> bool:
    if not os.path.exists(src):
        return False
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    return True


def prepare_dci_dataset(session_id: str, person_filename: str, cloth_filename: str):
    temp_dir = CONFIG["temp_dir"]
    dci_test_dir = os.path.join(temp_dir, "test")

    for subdir in DCI_SUBDIRS:
        os.makedirs(os.path.join(dci_test_dir, subdir), exist_ok=True)

    person_parse = person_filename.replace(".jpg", ".png")
    cloth_mask = cloth_filename.replace(".jpg", ".png")

    copies = {
        os.path.join(temp_dir, "image", person_filename): os.path.join(dci_test_dir, "image", person_filename),
        os.path.join(temp_dir, "cloth", cloth_filename): os.path.join(dci_test_dir, "cloth", cloth_filename),
        os.path.join(temp_dir, "cloth", "cloth-mask", cloth_mask): os.path.join(dci_test_dir, "cloth-mask", cloth_filename),
        os.path.join(temp_dir, "openpose_json", person_filename.replace(".jpg", "_keypoints.json")): os.path.join(dci_test_dir, "openpose_json", person_filename.replace(".jpg", "_keypoints.json")),
        os.path.join(temp_dir, "image-parse-v3", person_parse): os.path.join(dci_test_dir, "image-parse-v3", person_parse),
        os.path.join(temp_dir, "image-parse-agnostic-v3.2", person_parse): os.path.join(dci_test_dir, "image-parse-agnostic-v3.2", person_parse),
    }

    missing = [src for src, dst in copies.items() if not _copy_if_exists(src, dst)]
    if missing:
        return {
            "success": False,
            "error": "Missing DCI-VTON inputs: " + ", ".join(missing),
        }

    pair_path = os.path.join(temp_dir, "test_pairs.txt")
    with open(pair_path, "w", encoding="utf-8") as f:
        f.write(f"{person_filename} {cloth_filename}\n")

    return {"success": True}


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
        
        print("   Running PF-AFN warping module...")
        
        warp_command = [
            CONFIG["python_pfafen"],
            CONFIG["warping_script"],
            "--repo-dir", CONFIG["pf_afn_repo"],
            "--checkpoint", CONFIG["warp_checkpoint"],
            "--person", person_path,
            "--cloth", cloth_path,
            "--edge", cloth_mask_path,
            "--output-cloth", warped_cloth_path,
            "--output-mask", warped_mask_path,
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
        
        print("   Cloth warping complete")
        return {"success": True}
        
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
        
        print("   Running DCI-VTON diffusion model...")
        
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
                "error": f"Diffusion model failed: {result.stderr}"
            }
        
        # Find the latest result file
        result_dir = os.path.join(final_output_dir, "result")
        result_files = glob.glob(os.path.join(result_dir, "*.png"))
        
        if not result_files:
            return {
                "success": False,
                "error": "No result image generated"
            }
        
        # Get the most recent result
        latest_result = max(result_files, key=os.path.getmtime)
        
        # Copy to a session-specific name
        final_result_path = os.path.join(result_dir, f"{session_id}_result.png")
        shutil.copy(latest_result, final_result_path)
        
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


def process_virtual_tryon(person_image_path: str, cloth_image_path: str, session_id: str):
    """
    Main processing pipeline for virtual try-on
    """
    try:
        import numpy as np

        temp_dir = CONFIG["temp_dir"]
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
        results = detector.detect(cloth_image_path)
        boxes = detector.get_bounding_boxes(results)
        
        if boxes:
            first_box = boxes[0]
            x1, y1, x2, y2 = first_box['box']
            print(f"   Detected clothing at: ({x1}, {y1}, {x2}, {y2})")
        else:
            cloth_width, cloth_height = cloth_img_resized.size
            x1, y1, x2, y2 = 0, 0, cloth_width, cloth_height
            print("   No clothing box detected; using full cloth image for segmentation")
        
        print(f"[2/6] FastSAM Segmentation...")
        # 2. Segmentation
        bbox = [x1, y1, x2, y2]
        segmentor = FastSAMInference(CONFIG["fastsam_model"], cloth_image_path)
        segmentor.run_inference(bbox)
        
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
            person_image_path,
            parse_output_dir,
            output_name
        )
        
        print(f"[6/6] Agnostic Generation...")
        # 6. Parse Agnostic
        agnostic_save_dir = os.path.join(temp_dir, "agnostic-v3.2")
        process_image(person_image_path, openpose_json_dir, parse_output_dir, agnostic_save_dir)
        
        # Final agnostic parse
        parse_agnostic_output = os.path.join(temp_dir, "image-parse-agnostic-v3.2")
        pose_name = f"{output_name}_keypoints.json"
        pose_path = os.path.join(openpose_json_dir, pose_name)
        
        if os.path.exists(pose_path):
            with open(pose_path, 'r') as f:
                pose_label = json.load(f)
                pose_data = np.array(pose_label['people'][0]['pose_keypoints_2d']).reshape((-1, 3))[:, :2]
            
            parse_name = person_filename.replace('.jpg', '.png')
            im_parse = Image.open(os.path.join(parse_output_dir, parse_name))
            agnostic = get_im_parse_agnostic(im_parse, pose_data)
            agnostic.save(os.path.join(parse_agnostic_output, parse_name))
        
        print(f"Processing complete for session {session_id}")

        dataset_result = prepare_dci_dataset(session_id, person_filename, cloth_filename)
        if not dataset_result["success"]:
            return dataset_result
        
        # Stage 2: Cloth Warping (PF-AFN)
        print(f"[Stage 2] Running cloth warping...")
        warp_result = run_cloth_warping(session_id, person_filename, cloth_filename)
        
        if not warp_result["success"]:
            return warp_result

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
            return diffusion_result
        
        # Return the final result path
        final_result_path = diffusion_result["result_path"]
        
        return {
            "success": True,
            "result_path": final_result_path,
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
        "required_paths": paths,
    }


def run_tryon_pipeline(person_path: str, cloth_path: str, session_id: str) -> dict:
    mode = active_processing_mode()

    if mode == "ml":
        result = process_virtual_tryon(person_path, cloth_path, session_id)
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
    cloth_image: UploadFile = File(...)
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
        
        result = run_tryon_pipeline(temp_person_path, temp_cloth_path, session_id)
        
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
        
        result = run_tryon_pipeline(temp_person_path, temp_cloth_path, request.session_id)
        
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
