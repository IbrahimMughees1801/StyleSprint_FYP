# Backend and Model README

This backend runs the virtual try-on model pipeline used by the Flutter mobile
application. For evaluation, use `api_server.py` in full ML mode. Do not use
`api_server_simple.py` for the final demo because that file is only a lightweight
overlay fallback.

For the mathematical explanation of the model stages, see `backend/FORMULAS.md`.

## Evaluation Quick Start

Open PowerShell and start the full backend:

```powershell
cd C:\Users\muhdi\Desktop\fyp_app\backend
$env:API_PROCESSING_MODE='ml'
$env:API_FALLBACK_TO_SIMPLE='false'
..\.venv\Scripts\python.exe -m uvicorn api_server:app --host 0.0.0.0 --port 8000
```

Check readiness:

```powershell
Invoke-WebRequest http://127.0.0.1:8000/api/tryon/readiness -UseBasicParsing
```

Expected important values:

```text
"configured_mode":"ml"
"active_mode":"ml"
"ml_stack_ready":true
```

To connect a physical phone, start a Cloudflare quick tunnel in a second
PowerShell window:

```powershell
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --url http://localhost:8000
```

Then run Flutter from the project root with the tunnel URL printed by
Cloudflare:

```powershell
cd C:\Users\muhdi\Desktop\fyp_app
flutter run --dart-define=TRYON_API_BASE_URL=https://YOUR-TUNNEL.trycloudflare.com
```

Each new Cloudflare quick tunnel can generate a new URL. If the tunnel changes,
rerun Flutter with the new `--dart-define`; hot reload is not enough.

## Backend Responsibilities

`backend/api_server.py` is the main FastAPI application. It handles:

- accepting person and garment images from the Flutter app
- saving input images into session-specific temporary folders
- checking whether the ML stack is available
- running preprocessing, warping, and diffusion
- exposing status and result endpoints for the app
- writing debug artifacts for audit and evaluation

The app sends a request to `/api/tryon/process-base64`. The backend returns a
session immediately and continues processing in the background. The Flutter app
then polls `/api/tryon/status/{session_id}` until the result is ready, and loads
the image from `/api/tryon/result/{session_id}`.

This async design is intentional because the full ML pipeline can take several
minutes on a laptop GPU/CPU setup. It avoids phone and tunnel timeouts while
still running the real model pipeline.

## API Endpoints

### Health

```text
GET /
```

Confirms that the FastAPI server is running.

### Readiness

```text
GET /api/tryon/readiness
```

Reports configured mode, active mode, model-wrapper availability, and required
file readiness.

### Start Try-On

```text
POST /api/tryon/process-base64
```

Request body:

```json
{
  "session_id": "uuid-from-app",
  "person_image_base64": "base64-person-image",
  "cloth_image_base64": "base64-garment-image",
  "product_category": "optional category",
  "product_type": "optional product type"
}
```

Response contains the same session ID and a result URL. In ML mode, this does
not mean the model is finished; it means the background job has started.

### Status

```text
GET /api/tryon/status/{session_id}
```

Returns one of the processing states used by the Flutter Saved Try-ons flow:

- `processing`
- `completed`
- `failed`

### Result Image

```text
GET /api/tryon/result/{session_id}
```

Returns the final generated try-on image once the session has completed.

### Cleanup

```text
DELETE /api/tryon/cleanup/{session_id}
```

Removes temporary files for a session when cleanup is needed.

## Model Pipeline

The backend pipeline is:

```text
YOLO -> FastSAM -> DensePose -> OpenPose -> Graphonomy -> PF-AFN -> DCI-VTON
```

### 1. YOLO Clothing Detection

File: `backend/models/yolo.py`

YOLO detects the garment area in the uploaded product image. The detected box is
used as the starting point for cloth segmentation. The model weights are loaded
from:

```text
weights/best.pt
```

The detector includes filtering and padding logic so the selected box is more
useful for downstream segmentation.

### 2. FastSAM Cloth Segmentation

File: `backend/models/SegmentationSam2.py`

FastSAM segments the garment from the product image using the YOLO box as a
prompt. The cleaned garment mask is used for:

- removing background around the product
- preparing cloth inputs for PF-AFN
- preparing mask/edge inputs for DCI-VTON

Weights:

```text
weights/FastSAM-s.pt
```

### 3. DensePose

File: `backend/models/DensePose.py`

DensePose estimates dense body surface information from the person image. This
gives the pipeline a stronger representation of human body shape and pose.

Important paths:

```text
backend/third_party/detectron2/projects/DensePose/configs/densepose_rcnn_R_50_FPN_s1x.yaml
weights/model_final_162be9.pkl
```

### 4. OpenPose

File: `backend/models/OpenPose.py`

OpenPose extracts body keypoints. These keypoints are needed by the VITON-style
preprocessing code and help construct agnostic person inputs. The backend also
sanitizes weak keypoints where possible so DCI-VTON receives a valid pose file.

OpenPose root:

```text
backend/third_party/openpose/openpose
```

### 5. Graphonomy Human Parsing

File: `backend/models/ParseAgnostic.py`

Graphonomy segments the person into semantic body/clothing regions. This parse
is important because the try-on model needs to know which areas are body,
existing upper clothing, arms, hair, pants, and background.

Weights:

```text
weights/inference.pth
```

Current note: the bundled Graphonomy checkpoint is handled as a Pascal-part
target model and mapped back into the VITON-style label space before DCI-VTON.
The backend also checks for collapsed parses and can use pose-guided fallback
logic when allowed.

### 6. Parse and Agnostic Helpers

File: `backend/models/helper.py`

This stage prepares the VITON-compatible inputs:

- refined human parse
- parse-agnostic image
- agnostic mask
- pose-compatible labels
- DCI/PF-AFN input folders

These helpers are what connect general vision models to the expected structure
of PF-AFN and DCI-VTON.

### 7. PF-AFN Cloth Warping

Files:

- `backend/pf_afn_warp_export.py`
- `backend/third_party/PF-AFN/PF-AFN_test/`

PF-AFN warps the segmented garment onto the target body pose. It produces:

- warped cloth
- warped cloth mask
- fit/debug metrics

Checkpoint selection:

```text
backend/results/pf_afn_finetune/warp_vitonhd_tops_curated300_continue_180step.pth
```

If that tuned checkpoint is missing, the backend falls back to the legacy tuned
checkpoint or the bundled PF-AFN checkpoint.

PF-AFN is a key conditioning step. When PF-AFN is good, DCI-VTON has a better
spatial guide for where the garment should appear.

### 8. DCI-VTON Diffusion

Files:

- `backend/third_party/DCI-VTON-Virtual-Try-On/test.py`
- `backend/third_party/DCI-VTON-Virtual-Try-On/configs/viton512_v2.yaml`
- `backend/third_party/DCI-VTON-Virtual-Try-On/checkpoints/viton512_v2.ckpt`

DCI-VTON generates the final try-on image. It uses the person representation,
human parse, pose, cloth image, cloth mask, PF-AFN warped cloth, and related
VITON-format inputs.

This is currently the visually weakest part of the research pipeline. It can
occasionally miss garment regions, soften garment texture, or overwrite parts of
the PF-AFN warp. For evaluation, use the controlled input pair listed below
because it gives the most repeatable result.

## Important Configuration

These values are defined in `backend/api_server.py`.

```python
CONFIG = {
    "yolo_weights": "weights/best.pt",
    "fastsam_model": "weights/FastSAM-s.pt",
    "densepose_weights": "weights/model_final_162be9.pkl",
    "graphonomy_weights": "weights/inference.pth",
    "warp_checkpoint": "backend/results/pf_afn_finetune/...",
    "diffusion_checkpoint": "backend/third_party/DCI-VTON-Virtual-Try-On/checkpoints/viton512_v2.ckpt",
    "diffusion_config": "backend/third_party/DCI-VTON-Virtual-Try-On/configs/viton512_v2.yaml",
    "python_torch112": "C:/Users/muhdi/miniconda3/envs/torch112/python.exe",
    "python_dci_vton": "C:/Users/muhdi/miniconda3/envs/dci-vton/python.exe",
    "python_pfafen": "C:/Users/muhdi/miniconda3/envs/pfafen-gpu-clean/python.exe"
}
```

Useful environment variables:

```powershell
$env:API_PROCESSING_MODE='ml'
$env:API_FALLBACK_TO_SIMPLE='false'
$env:API_DIFFUSION_STEPS='12'
$env:API_GRAPHONOMY_SCALES='1.0'
$env:API_ALLOW_POSE_FALLBACK_PARSE='false'
```

For evaluation, keep fallback disabled so any ML failure is visible instead of
silently switching to the simple overlay path.

## Output and Debug Folders

Important folders:

```text
backend/temp_uploads/        session inputs and model staging files
backend/FINAL/result/        DCI-VTON result images
backend/results/debug/       debug contact sheets and audit images
backend/results/             stage outputs and diagnostics
```

Use `backend/results/debug/` to visually inspect whether each model stage is
healthy before judging the final output.

## Audit Tools

Main audit script:

```powershell
cd C:\Users\muhdi\Desktop\fyp_app
.\.venv\Scripts\python.exe backend\audit_model_accuracy.py
```

The audit script scores or flags:

- YOLO product detection
- FastSAM cloth mask
- DensePose output
- OpenPose keypoints
- Graphonomy human parse
- PF-AFN warp
- DCI-VTON final image

The score is a diagnostic quality estimate, not a formal benchmark against a
ground-truth dataset.

For one saved run, use:

```powershell
.\.venv\Scripts\python.exe backend\diagnose_tryon_run.py SESSION_ID
```

## Controlled Evaluation Inputs

Use these for repeatable demo testing:

Person image:

```text
C:\Users\muhdi\Desktop\fyp_app\backend\temp_uploads\image\fresh_yolo_20260601_02_person.jpg
```

Garment image:

```text
C:\Users\muhdi\Desktop\fyp_app\backend\temp_uploads\cloth\fresh_yolo_20260601_02_cloth.jpg
```

Supabase product:

```text
Name: Controlled Black Wrap Top
Catalog ID: 69
Image URL: https://jygqfwpqcwnxdtipokqc.supabase.co/storage/v1/object/public/products/controlled/black_wrap_top_fresh_yolo_20260601_02.jpg
```

Visual description:

- Person: female model wearing a blue/green patterned shirt with white pants.
- Garment: black long-sleeve wrap top with a front tie.

## Troubleshooting

### Port 8000 is already in use

```powershell
Get-Process python -ErrorAction SilentlyContinue | Select-Object Id,StartTime,Path
```

Stop the old backend process, then restart the full ML backend.

### Phone says the backend is not running

Check:

- backend terminal is still open
- Cloudflare tunnel terminal is still open
- Flutter was run with the current tunnel URL
- phone browser can open `/api/tryon/readiness`

### Try-on takes several minutes

This is expected for the full model stack. The Flutter app saves the session in
Profile -> Saved Try-ons and continues polling in the background.

### DCI result is incomplete

Check debug outputs in this order:

1. YOLO selected the garment box correctly.
2. FastSAM mask covers the full garment.
3. OpenPose keypoints match the person.
4. Graphonomy parse is not collapsed.
5. PF-AFN warped cloth covers the target clothing region.
6. DCI-VTON result follows the PF-AFN warp.

Most visible failures come from weak DCI conditioning, weak parse masks, or
diffusion overwriting the warped garment.

## Notes for Evaluation

- Use `api_server.py`, not `api_server_simple.py`.
- Keep `API_PROCESSING_MODE=ml`.
- Keep `API_FALLBACK_TO_SIMPLE=false` during evaluation.
- Use the controlled black wrap top and controlled person image for the most
  stable demo.
- The pipeline is research-grade and may not produce perfect retail-quality
  images, but it demonstrates a full multi-model virtual try-on system.
