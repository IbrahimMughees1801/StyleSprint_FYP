from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import cv2
import shutil
import numpy as np
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

# Import ML models (optional - only if models folder exists)
try:
    from models.yolo import YOLODetector  
    from models.SegmentationSam2 import FastSAMInference 
    from models.DensePose import DensePoseRunner
    from models.OpenPose import OpenPoseRunner
    from models.ParseAgnostic import GraphonomyInference
    from models.helper import process_image, get_im_parse_agnostic
    ML_MODELS_AVAILABLE = True
    print("✓ ML models loaded successfully")
except ImportError as e:
    ML_MODELS_AVAILABLE = False
    print(f"⚠ ML models not available: {e}")
    print("→ Using simplified overlay mode")

os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

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
    "yolo_weights": r"C:\Users\muhdi\Desktop\fyp_app\weights\best.pt",  # ✅ Updated to local path
    "fastsam_model": r"C:\Users\muhdi\Desktop\fyp_app\weights\FastSAM-s.pt",
    "densepose_cfg": r"C:\Users\FAST\pls\detectron2\projects\DensePose\configs\densepose_rcnn_R_50_FPN_s1x.yaml",
    "densepose_weights": r"C:\Users\muhdi\Desktop\fyp_app\weights\model_final_162be9.pkl",
    "openpose_root": r"C:\Users\FAST\Downloads\openpose-1.7.0-binaries-win64-gpu-python3.7-flir-3d_recommended\openpose",
    "graphonomy_repo": r"C:\Users\FAST\graph\Graphonomy",
    "graphonomy_weights": r"C:\Users\muhdi\Desktop\fyp_app\weights\inference.pth",
    
    # Stage 2: Warping (PF-AFN)
    "warping_script": r"C:\Users\FAST\Try\PF-AFN\PF-AFN_test\eval_PBAFN_viton.py",
    "warp_checkpoint": r"C:\Users\FAST\Try\PF-AFN\PF-AFN_test\checkpoints\warp_viton.pth",
    
    # Stage 3: Diffusion (DCI-VTON)
    "diffusion_script": r"C:\Users\FAST\Try\DCI-VTON-Virtual-Try-On\test.py",
    "diffusion_checkpoint": r"C:\Users\FAST\Downloads\viton512_v2.ckpt",
    "diffusion_config": r"C:\Users\FAST\Try\DCI-VTON-Virtual-Try-On\configs\viton512_v2.yaml",
    "diffusion_workdir": r"C:\Users\FAST\Try\DCI-VTON-Virtual-Try-On",
    
    # Python environments
    "python_torch112": r"C:\Users\FAST\anaconda3\envs\torch112\python.exe",
    "python_dci_vton": r"C:\Users\FAST\anaconda3\envs\dci-vton\python.exe",
    
    # Directories
    "temp_dir": "./temp_uploads",
    "output_dir": "./results",
    "final_output_dir": "./FINAL"
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


def run_cloth_warping(session_id: str, person_filename: str):
    """
    Stage 2: Run PF-AFN cloth warping
    """
    try:
        import subprocess
        
        temp_dir = CONFIG["temp_dir"]
        output_dir = CONFIG["output_dir"]
        
        print("   Running PF-AFN warping module...")
        
        warp_command = [
            CONFIG["python_dci_vton"],
            CONFIG["warping_script"],
            "--name=cloth-warp",
            "--resize_or_crop=none",
            "--batchSize=1",
            "--gpu_ids=0",
            f"--warp_checkpoint={CONFIG['warp_checkpoint']}",
            "--label_nc=13",
            f"--dataroot={temp_dir}",
            "--fineSize=512",
            "--unpaired"
        ]
        
        result = subprocess.run(warp_command, capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"Warping error: {result.stderr}")
            return {
                "success": False,
                "error": f"Cloth warping failed: {result.stderr}"
            }
        
        # Move warping results to proper location
        person_base = os.path.splitext(person_filename)[0]
        
        # Move cloth-warp files
        src_cloth_warp_dir = os.path.join(output_dir, "cloth-warp")
        dst_cloth_warp_dir = os.path.join(temp_dir, "unpaired-cloth-warp")
        
        moved = False
        if os.path.exists(src_cloth_warp_dir):
            for file in os.listdir(src_cloth_warp_dir):
                if person_base in file:
                    src_path = os.path.join(src_cloth_warp_dir, file)
                    dst_path = os.path.join(dst_cloth_warp_dir, file)
                    shutil.move(src_path, dst_path)
                    print(f"   Moved warped cloth: {file}")
                    moved = True
        
        # Move cloth-warp-mask files
        src_mask_dir = os.path.join(output_dir, "cloth-warp-mask")
        dst_mask_dir = os.path.join(temp_dir, "unpaired-cloth-warp-mask")
        
        if os.path.exists(src_mask_dir):
            for file in os.listdir(src_mask_dir):
                if person_base in file:
                    src_path = os.path.join(src_mask_dir, file)
                    dst_path = os.path.join(dst_mask_dir, file)
                    shutil.move(src_path, dst_path)
                    print(f"   Moved warp mask: {file}")
                    moved = True
        
        if not moved:
            print(f"   Warning: No warping output found for {person_base}")
        
        print("   ✓ Cloth warping complete")
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
            "--ddim_steps", "100",
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
            text=True
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
        
        print(f"   ✓ Final result saved: {final_result_path}")
        
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
        temp_dir = CONFIG["temp_dir"]
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
        
        if not boxes:
            raise Exception("No clothing detected in the image")
        
        first_box = boxes[0]
        x1, y1, x2, y2 = first_box['box']
        print(f"   Detected clothing at: ({x1}, {y1}, {x2}, {y2})")
        
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
            requirements_path=requirements_path
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
        
        print(f"✓ Processing complete for session {session_id}")
        
        # Stage 2: Cloth Warping (PF-AFN)
        print(f"[Stage 2] Running cloth warping...")
        warp_result = run_cloth_warping(session_id, person_filename)
        
        if not warp_result["success"]:
            return warp_result
        
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
            print(f"✓ Simplified try-on complete: {output_path}")
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
            } - use simplified version if ML models not available
        if ML_MODELS_AVAILABLE:
            result = process_virtual_tryon(temp_person_path, temp_cloth_path, session_id)
        else:
            result = simple_process
    except Exception as e:
        print(f"Error in simplified processing: {e}")
        return {
            "success": False,
            "error": str(e),
            "session_id": session_id
        }


@app.get("/")
def root():
    """Health check endpoint"""
    return {
        "status": "running",
        "service": "Virtual Try-On API",
        "version": "1.0.0",
        "mode": "ML Pipeline" if ML_MODELS_AVAILABLE else "Simplified Overlay",
        "ml_models_available": ML_MODELS_AVAILABLE
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
        
        # Process the images - use simplified version if ML models not available
        if ML_MODELS_AVAILABLE:
            result = process_virtual_tryon(temp_person_path, temp_cloth_path, session_id)
        else:
            result = simple_process_tryon(temp_person_path, temp_cloth_path, session_id)
        
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
        
        # Process the images - use simplified version if ML models not available
        if ML_MODELS_AVAILABLE:
            result = process_virtual_tryon(temp_person_path, temp_cloth_path, request.session_id)
        else:
            result = simple_process_tryon(temp_person_path, temp_cloth_path, request.session_id)
        
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

Check for simplified result (JPG)
    simple_result_path = os.path.join(
        CONFIG["final_output_dir"],
        "result",
        f"{session_id}_result.jpg"
    )
    
    if os.path.exists(simple_result_path):
        return FileResponse(simple_result_path, media_type="image/jpeg")
    
    # Check for final diffusion result (PNG)
@app.get("/api/tryon/result/{session_id}")
async def get_result(session_id: str):
    """
    Get the result image for a session
    """
    # First, check for final diffusion result
    final_result_path = os.path.join(
        CONFIG["final_output_dir"],
        "result",
        f"{session_id}_result.png"
    )
    
    if os.path.exists(final_result_path):
        return FileResponse(final_result_path, media_type="image/png")
    
    # Fallback: Check for any recent result in the final output directory
    result_dir = os.path.join(CONFIG["final_output_dir"], "result")
    if os.path.exists(result_dir):
        import glob
        result_files = glob.glob(os.path.join(result_dir, "*.png"))
        if result_files:
            latest_result = max(result_files, key=os.path.getmtime)
            return FileResponse(latest_result, media_type="image/png")
    
    # Fallback: Return agnostic parse (preprocessing output)
    result_path = os.path.join(
        CONFIG["simplified result (JPG)
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
    
    # Check for final diffusion result (PNG)
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
            "mode": "ml_pipelin
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
            "stage": "diffusion_complete"
        }
    
    # Check for warping completion
    warp_path = os.path.join(
        CONFIG["temp_dir"],
        "unpaired-cloth-warp"
    )
    
    if os.path.exists(warp_path) and os.listdir(warp_path):
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
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
