# StyleSprint Virtual Try-On

StyleSprint is a mobile shopping application with a full virtual try-on
pipeline. The Flutter app lets a user browse products from Supabase, choose a
garment, upload or capture a person photo, and run a backend ML pipeline that
generates a try-on result.

This README is written for evaluation/demo use. The detailed backend and model
notes are in `backend/README.md`, and the quick command sheet is in
`backend/QUICK_REFERENCE.txt`.

## What the System Does

The project has three main parts:

- Flutter mobile app: user interface, authentication, product browsing,
  wishlist/profile screens, virtual try-on flow, and saved try-on results.
- Supabase product catalog: stores product metadata and product image URLs.
- FastAPI ML backend: accepts person/garment images, runs preprocessing,
  warping, and diffusion, then returns the generated try-on image.

The evaluation flow uses the full ML backend:

```text
YOLO -> FastSAM -> DensePose -> OpenPose -> Graphonomy -> PF-AFN -> DCI-VTON
```

Do not use the simplified overlay backend for final evaluation.

## Repository Structure

```text
fyp_app/
+-- lib/                         Flutter application code
|   +-- screens/                 App screens such as home, profile, search, try-on
|   +-- services/                Supabase, Firebase, wishlist, saved try-on, API calls
|   +-- models/                  Product, try-on, and saved result models
|   +-- widgets/                 Shared UI widgets
+-- backend/
|   +-- api_server.py            Main FastAPI server for full ML try-on
|   +-- api_server_simple.py     Lightweight overlay fallback, not for evaluation
|   +-- models/                  Python wrappers for YOLO, FastSAM, DensePose, OpenPose, Graphonomy
|   +-- third_party/             PF-AFN, DCI-VTON, OpenPose, Detectron2, Graphonomy repos
|   +-- results/                 Debug outputs, audits, model results
|   +-- temp_uploads/            Session inputs and staging files
|   +-- README.md                Detailed backend/model documentation
|   +-- QUICK_REFERENCE.txt      Short demo command checklist
+-- weights/                     Main model weights
+-- tools/                       Utility scripts
+-- android/                     Android project files
+-- pubspec.yaml                 Flutter dependencies and assets
```

## App Code Overview

Important Flutter files:

- `lib/services/virtual_tryon_service.dart`: sends images to the backend,
  checks try-on status, and downloads results.
- `lib/services/saved_tryon_service.dart`: stores processing/completed try-ons
  in Firestore and polls the backend until results are ready.
- `lib/services/supabase_products_service.dart`: loads product data and product
  images from Supabase.
- `lib/screens/virtual_tryon_screen.dart`: main full-screen try-on experience,
  image picker/camera flow, instructions, and result handling.
- `lib/widgets/virtual_tryon_dialog.dart`: product-detail try-on dialog.
- `lib/screens/profile_screen.dart`: profile view with Saved Try-ons.
- `lib/widgets/product_grid.dart`: product display grid.

The app uses `TRYON_API_BASE_URL` at runtime so a physical phone can connect to
the laptop backend through a public tunnel.

## Backend and Model Overview

The backend is a FastAPI server in `backend/api_server.py`.

Evaluation mode is enabled with:

```powershell
$env:API_PROCESSING_MODE='ml'
$env:API_FALLBACK_TO_SIMPLE='false'
```

The ML stages are:

1. YOLO detects the garment region in the product image.
2. FastSAM segments the garment and creates a clean cloth mask.
3. DensePose estimates dense body surface information for the person.
4. OpenPose extracts body keypoints.
5. Graphonomy creates human parsing labels for body/clothing regions.
6. Helper preprocessing creates VITON-compatible agnostic images and masks.
7. PF-AFN warps the garment into the target pose.
8. DCI-VTON diffusion generates the final try-on image.
9. Audit/debug scripts inspect stage quality and final output.

The final DCI-VTON stage is the most visually sensitive part. It can sometimes
miss garment regions or soften details, so controlled demo inputs are used for a
stable evaluation result.

## Run the Full Evaluation Demo

### 1. Start the backend

```powershell
cd C:\Users\muhdi\Desktop\fyp_app\backend
$env:API_PROCESSING_MODE='ml'
$env:API_FALLBACK_TO_SIMPLE='false'
..\.venv\Scripts\python.exe -m uvicorn api_server:app --host 0.0.0.0 --port 8000
```

Keep this terminal open.

Check readiness:

```powershell
Invoke-WebRequest http://127.0.0.1:8000/api/tryon/readiness -UseBasicParsing
```

Expected values include:

```text
"configured_mode":"ml"
"active_mode":"ml"
"ml_stack_ready":true
```

### 2. Start the Cloudflare tunnel

Open a second PowerShell window:

```powershell
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --url http://localhost:8000
```

Copy the printed URL, for example:

```text
https://something-random.trycloudflare.com
```

Each new quick tunnel can create a new URL.

### 3. Run Flutter on the phone

Open a third PowerShell window:

```powershell
cd C:\Users\muhdi\Desktop\fyp_app
flutter run --dart-define=TRYON_API_BASE_URL=https://YOUR-TUNNEL.trycloudflare.com
```

Use the exact tunnel URL. If the tunnel changes, rerun this command.

## Expected Demo Flow

1. Open the app on the phone.
2. Browse products from Supabase.
3. Open the controlled product or another try-on-ready item.
4. Start virtual try-on.
5. Upload or capture a clear person photo.
6. The app tells the user the try-on is processing in the background.
7. Continue browsing the app.
8. When processing finishes, the app shows a notification.
9. Open Profile -> Saved Try-ons to view the result.

This async flow exists because the real ML pipeline can take several minutes.

## Controlled Evaluation Inputs

Use this pair for the most repeatable demo:

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

- Person: female model in a blue/green patterned shirt with white pants.
- Garment: black long-sleeve wrap top with a front tie.

## Evaluation Checklist

Before showing the demo:

- Backend is running in `ml` mode.
- `/api/tryon/readiness` reports `ml_stack_ready:true`.
- Cloudflare tunnel is open.
- Flutter was started with the current tunnel URL.
- Phone browser can open `https://YOUR-TUNNEL.trycloudflare.com/api/tryon/readiness`.
- Controlled product is visible in the app.
- Profile -> Saved Try-ons is available.

## Auditing Model Quality

The backend writes debug outputs to:

```text
backend/results/debug/
backend/FINAL/result/
backend/results/
```

Run the audit script from the repo root:

```powershell
.\.venv\Scripts\python.exe backend\audit_model_accuracy.py
```

The audit checks the main stages:

- YOLO product detection
- FastSAM cloth mask
- DensePose
- OpenPose
- Graphonomy parse
- PF-AFN warp
- DCI-VTON final image

Use audit numbers as diagnostic support, not as a formal benchmark score.

## Known Limitations

- The full ML pipeline is slow and can take several minutes per try-on.
- DCI-VTON is the weakest visual stage and may not always preserve the whole
  garment perfectly.
- Cloudflare quick tunnel URLs change when a tunnel is restarted.
- `api_server_simple.py` exists only as a fallback and is not evaluation quality.
- Service-role credentials for Supabase must never be committed to the repo or
  placed in the Flutter app.

## Stop the Demo

List backend and tunnel processes:

```powershell
Get-Process python,cloudflared -ErrorAction SilentlyContinue | Select-Object ProcessName,Id,StartTime,Path
```

Stop the relevant process IDs:

```powershell
Stop-Process -Id YOUR_PROCESS_IDS -Force
```

Confirm port 8000 is free:

```powershell
Test-NetConnection -ComputerName 127.0.0.1 -Port 8000
```

Expected when stopped:

```text
TcpTestSucceeded : False
```

## More Detail

- Backend/model details: `backend/README.md`
- Demo command checklist: `backend/QUICK_REFERENCE.txt`
- Model audit script: `backend/audit_model_accuracy.py`
- Backend entry point: `backend/api_server.py`
- Flutter API service: `lib/services/virtual_tryon_service.dart`
