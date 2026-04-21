"""
StyleSprint Virtual Try-On API - Simplified Version
Works immediately without ML models using image overlay
"""

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import uuid
from typing import Optional
from pydantic import BaseModel

# Import simplified try-on
from simple_tryon import advanced_overlay_tryon

app = FastAPI(title="Virtual Try-On API - Simplified", version="1.0.0")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
CONFIG = {
    "temp_dir": "./temp_uploads",
    "output_dir": "./results",
    "final_output_dir": "./FINAL"
}

# Create directories
for dir_path in [CONFIG["temp_dir"], CONFIG["output_dir"], CONFIG["final_output_dir"]]:
    os.makedirs(dir_path, exist_ok=True)
    os.makedirs(os.path.join(dir_path, "result"), exist_ok=True)


class TryOnResponse(BaseModel):
    success: bool
    message: str
    session_id: str
    result_image_url: Optional[str] = None
    processing_time: Optional[float] = None


@app.get("/")
def root():
    """Health check endpoint"""
    return {
        "status": "running",
        "service": "Virtual Try-On API",
        "version": "1.0.0-simplified",
        "mode": "Simplified Overlay",
        "ml_models_available": False
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
        temp_person_path = os.path.join(CONFIG["temp_dir"], f"{session_id}_person.jpg")
        temp_cloth_path = os.path.join(CONFIG["temp_dir"], f"{session_id}_cloth.jpg")
        
        with open(temp_person_path, "wb") as f:
            f.write(await person_image.read())
        
        with open(temp_cloth_path, "wb") as f:
            f.write(await cloth_image.read())
        
        # Process with simple overlay
        output_path = os.path.join(CONFIG["final_output_dir"], "result", f"{session_id}_result.jpg")
        success = advanced_overlay_tryon(temp_person_path, temp_cloth_path, output_path)
        
        if success:
            return TryOnResponse(
                success=True,
                message="Processing completed successfully",
                session_id=session_id,
                result_image_url=f"/api/tryon/result/{session_id}"
            )
        else:
            raise HTTPException(status_code=500, detail="Processing failed")
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/tryon/result/{session_id}")
async def get_result(session_id: str):
    """
    Get the result image for a session
    """
    result_path = os.path.join(
        CONFIG["final_output_dir"],
        "result",
        f"{session_id}_result.jpg"
    )
    
    if os.path.exists(result_path):
        return FileResponse(result_path, media_type="image/jpeg")
    
    raise HTTPException(status_code=404, detail="Result not found")


@app.get("/api/tryon/status/{session_id}")
def check_status(session_id: str):
    """
    Check the processing status of a session
    """
    result_path = os.path.join(
        CONFIG["final_output_dir"],
        "result",
        f"{session_id}_result.jpg"
    )
    
    if os.path.exists(result_path):
        return {
            "status": "completed",
            "session_id": session_id,
            "result_url": f"/api/tryon/result/{session_id}",
            "stage": "overlay_complete",
            "mode": "simplified"
        }
    
    return {
        "status": "processing",
        "session_id": session_id,
        "stage": "processing"
    }


@app.delete("/api/tryon/cleanup/{session_id}")
def cleanup_session(session_id: str):
    """
    Clean up temporary files for a session
    """
    try:
        import glob
        patterns = [
            f"{session_id}_*",
        ]
        
        for pattern in patterns:
            for file_path in glob.glob(os.path.join(CONFIG["temp_dir"], pattern)):
                try:
                    os.remove(file_path)
                except Exception as e:
                    print(f"Error deleting {file_path}: {e}")
        
        return {"success": True, "message": "Session cleaned up"}
    except Exception as e:
        return {"success": False, "message": str(e)}


if __name__ == "__main__":
    import uvicorn
    print("=" * 60)
    print("StyleSprint Virtual Try-On API - Simplified Mode")
    print("=" * 60)
    print("Server starting at: http://localhost:8000")
    print("API Documentation: http://localhost:8000/docs")
    print("")
    print("Mode: Simplified Overlay (No ML models required)")
    print("Processing time: ~2-3 seconds per request")
    print("=" * 60)
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=False)
