# StyleSprint 👗✨

> **AI-Powered Mobile Fashion E-Commerce with Virtual Try-On**  
> Final Year Project — BS Computer Science (Hons), Forman Christian College (A Chartered University)

StyleSprint is a cross-platform Flutter shopping app connected to a FastAPI backend that runs a 3-stage machine-learning virtual try-on pipeline. Users browse a product catalogue, select a garment, upload a photo of themselves, and receive a photorealistic composited image showing them wearing that garment — all within the same mobile experience as the rest of the shopping flow.

---

## Table of Contents

- [Demo & Screenshots](#demo--screenshots)
- [Features](#features)
- [Architecture](#architecture)
- [3-Stage ML Pipeline](#3-stage-ml-pipeline)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
  - [1. Flutter App](#1-flutter-app)
  - [2. Firebase Setup](#2-firebase-setup)
  - [3. Supabase Setup](#3-supabase-setup)
  - [4. Backend & ML Environments](#4-backend--ml-environments)
  - [5. Model Checkpoints](#5-model-checkpoints)
  - [6. Configure Paths](#6-configure-paths)
  - [7. Run Everything](#7-run-everything)
- [API Reference](#api-reference)
- [Environment Variables](#environment-variables)
- [Testing](#testing)
- [Performance](#performance)
- [Known Issues & Roadmap](#known-issues--roadmap)
- [Team](#team)
- [Acknowledgements](#acknowledgements)
- [License](#license)

---

## Demo & Screenshots

| Onboarding | Home | AI Try-On |
|:-----------:|:----:|:---------:|
| *(first-launch flow)* | *(categories + new arrivals)* | *(garment selection + result)* |

> Screenshots of the running application are available in `docs/screenshots/`.

---

## Features

- **AI Virtual Try-On** — Upload a full-body photo + select a catalogue garment → 3-stage ML pipeline returns a photorealistic try-on result in ~90 seconds with live per-stage progress feedback.
- **Full Shopping Experience** — Onboarding, email/password auth, home feed, category browsing, search, product detail with size & colour selection, wishlist, shopping cart, promo codes, checkout, order history, and order tracking.
- **Firebase Authentication** — Secure email/password sign-up, sign-in, password reset, session persistence across relaunches, and account deletion.
- **Supabase Product Catalogue** — PostgreSQL-backed catalogue with row-level security; public read, service-role write.
- **Theme Toggle** — Light and dark mode, persisted across restarts via `shared_preferences`.
- **Graceful Degradation** — If Stage 3 (DCI-VTON) is unavailable, the backend automatically falls back to a simplified OpenPose-guided overlay try-on in under 5 seconds, with a clear flag shown in the UI.
- **Session-based Async Processing** — Upload returns a UUID session immediately; Flutter polls `/status` every 3 seconds; cleanup is called after result retrieval.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                Flutter App (Android / iOS)               │
│  Screens · Widgets · Services · Models · Provider state  │
└──────────────┬─────────────────┬───────────────┬─────────┘
               │                 │               │
        Firebase SDK      Supabase SDK      HTTP (REST)
               │                 │               │
     ┌─────────▼──────┐ ┌────────▼───────┐ ┌────▼──────────────┐
     │ Firebase Auth  │ │ Supabase       │ │ FastAPI Backend   │
     │ + Firestore    │ │ PostgreSQL+RLS │ │ Python · Uvicorn  │
     │ Users, Orders  │ │ Products       │ │ api_server.py     │
     └────────────────┘ └────────────────┘ └────────┬──────────┘
                                                     │ subprocess
                                           ┌─────────▼──────────────────┐
                                           │   3-Stage ML Pipeline       │
                                           │  Stage 1 → Stage 2 → Stage 3│
                                           └────────────────────────────┘
```

The mobile client never touches ML models directly. All inference runs on the backend host (GPU required for Stage 2 & 3). The three data planes — Firebase for identity/orders, Supabase for products, FastAPI for try-on — are each accessed through a dedicated service class in `lib/services/`.

---

## 3-Stage ML Pipeline

The pipeline takes a **person image** and a **garment image** and produces a composited try-on result through three isolated Python environments:

```
Person image + Garment image
          │
          ▼
┌─────────────────────────────────────────────────┐
│  Stage 1 — Preprocessing  (orchestrator env)    │
│  YOLO → clothing bounding box                   │
│  FastSAM → fine-grained garment mask            │
│  DensePose → IUV body-surface map               │
│  OpenPose → BODY_25 skeletal keypoints          │
│  Graphonomy → 20-class human parse map          │
│  ParseAgnostic → agnostic representation        │
│                              ~8–18 s (GPU)      │
└────────────────────┬────────────────────────────┘
                     │ 7 artefact files
                     ▼
┌─────────────────────────────────────────────────┐
│  Stage 2 — PF-AFN Warping  (pfafen-gpu-clean)   │
│  Parser-free appearance flows align garment     │
│  to body pose → warped_cloth.png + warp_mask    │
│                              ~35–45 s (GPU)     │
└────────────────────┬────────────────────────────┘
                     │ warped cloth + mask
                     ▼
┌─────────────────────────────────────────────────┐
│  Stage 3 — DCI-VTON Diffusion  (dci-vton env)   │
│  Latent diffusion model fuses warped garment    │
│  onto agnostic person → 512×512 PNG result      │
│                              ~60–80 s (GPU)     │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
              final_result.png
```

Stages communicate through the **filesystem** — each stage reads inputs from and writes outputs to the session's directory under `backend/temp_uploads/{session_id}/`. The orchestrator in `api_server.py` calls each stage via `subprocess.run` with explicit conda python paths, so all three dependency stacks stay fully isolated.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile framework | Flutter 3.16+ / Dart 3.2+ |
| State management | Provider |
| Auth | Firebase Authentication |
| User data | Cloud Firestore |
| Product catalogue | Supabase (PostgreSQL + RLS) |
| Backend API | FastAPI + Uvicorn (Python 3.9) |
| Object detection | YOLOv8 (Ultralytics) |
| Segmentation | FastSAM-s |
| Dense pose | Detectron2 DensePose |
| Pose estimation | OpenPose (BODY_25, Windows binaries) |
| Human parsing | Graphonomy |
| Garment warping | PF-AFN |
| Diffusion composition | DCI-VTON |
| Image processing | OpenCV, Pillow |
| Environment management | Conda |
| Version control | Git / GitHub |

---

## Project Structure

```
stylesprint/
├── lib/                          # Flutter application
│   ├── main.dart
│   ├── models/                   # Data models (User, Product, Order, …)
│   ├── screens/                  # One file per route
│   │   ├── onboarding_screen.dart
│   │   ├── home_screen.dart
│   │   ├── product_detail_screen.dart
│   │   ├── cart_screen.dart
│   │   ├── checkout_screen.dart
│   │   └── …
│   ├── services/                 # External-service abstractions
│   │   ├── firebase_auth_service.dart
│   │   ├── firestore_service.dart
│   │   ├── supabase_service.dart
│   │   └── virtual_tryon_service.dart
│   └── widgets/                  # Reusable UI components
│
├── android/                      # Android host project
├── ios/                          # iOS host project
│
├── backend/
│   ├── api_server.py             # FastAPI app + pipeline orchestrator
│   ├── check_setup.py            # Pre-flight config verifier
│   ├── requirements.txt          # Python deps (orchestrator env)
│   ├── models/                   # ML wrapper modules
│   │   ├── yolo.py
│   │   ├── SegmentationSam2.py
│   │   ├── DensePose.py
│   │   ├── OpenPose.py
│   │   ├── Graphonomy.py
│   │   ├── ParseAgnostic.py
│   │   └── helper.py
│   ├── third_party/
│   │   ├── PF-AFN_test/          # Stage 2 — PF-AFN repo
│   │   └── DCI-VTON/             # Stage 3 — DCI-VTON repo
│   ├── weights/                  # Model checkpoints (not tracked by git)
│   │   ├── best.pt               # YOLO clothing detector
│   │   ├── FastSAM-s.pt
│   │   ├── densepose/model_final_162be9.pkl
│   │   ├── graphonomy/inference.pth
│   │   └── vgg/vgg19_conv.pth    # DCI-VTON perceptual loss
│   ├── temp_uploads/             # Created at runtime — session artefacts
│   └── results/                  # Created at runtime — final result PNGs
│
├── docs/
│   └── screenshots/
│
├── pubspec.yaml
└── README.md
```

> **Note:** `backend/weights/`, `backend/temp_uploads/`, and `backend/results/` are excluded from version control via `.gitignore`. Large third-party model repos (`PF-AFN_test/`, `DCI-VTON/`) should be cloned into `backend/third_party/` separately — see [Installation](#installation).

---

## Prerequisites

### Flutter (mobile app)
- Flutter SDK 3.16+ with Dart 3.2+ — [Install guide](https://docs.flutter.dev/get-started/install)
- Android Studio / VS Code with Flutter & Dart extensions
- Android emulator or physical device (Android API 24+ or iOS 12+)

### Backend (ML pipeline)
- Windows 10/11 with an NVIDIA GPU (CUDA 11.x or 12.x)
- [Anaconda or Miniconda](https://docs.conda.io/en/latest/miniconda.html)
- Python 3.9 available in base or a dedicated conda env
- ~10 GB free disk space for model checkpoints
- [OpenPose Windows binaries](https://github.com/CMU-Perceptual-Computing-Lab/openpose/releases) (BODY_25 model)

### Cloud services
- [Firebase project](https://console.firebase.google.com) with Authentication (Email/Password) and Firestore enabled
- [Supabase project](https://app.supabase.com) with the products schema applied

---

## Installation

### 1. Flutter App

```bash
git clone https://github.com/<your-username>/stylesprint.git
cd stylesprint
flutter pub get
```

Verify everything is in order:

```bash
flutter doctor
flutter devices
```

### 2. Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com).
2. Enable **Email/Password** under Authentication → Sign-in method.
3. Create a **Cloud Firestore** database (start in Production mode).
4. Add an **Android** app using the package name in `android/app/build.gradle` and download `google-services.json` into `android/app/`.
5. *(iOS only)* Add an **iOS** app and place `GoogleService-Info.plist` in `ios/Runner/`.
6. Apply the Firestore Security Rules from `firestore.rules` in the repo root.

### 3. Supabase Setup

1. Create a project at [app.supabase.com](https://app.supabase.com).
2. Copy the **Project URL** and **anon public key** into `lib/services/supabase_service.dart` (or your config file).
3. Run the migration in `db/supabase_schema.sql` to create the `products` and `categories` tables.
4. Apply the RLS policy in `db/supabase_rls.sql` to allow public read access.
5. Seed product data via the Supabase dashboard or `scripts/seed_products.dart`.

### 4. Backend & ML Environments

#### Orchestrator environment

```bash
conda create -n styles-orch python=3.9 -y
conda activate styles-orch
pip install -r backend/requirements.txt
```

#### Stage 2 — PF-AFN warping

```bash
# Clone PF-AFN into the third_party directory
cd backend/third_party
git clone https://github.com/geyuying/PF-AFN.git PF-AFN_test
cd PF-AFN_test

conda create -n pfafen-gpu-clean python=3.8 -y
conda activate pfafen-gpu-clean
pip install -r requirements.txt
```

#### Stage 3 — DCI-VTON diffusion

```bash
cd backend/third_party
git clone https://github.com/bcmi/DCI-VTON-Virtual-Try-On.git DCI-VTON
cd DCI-VTON

conda create -n dci-vton python=3.9 -y
conda activate dci-vton
pip install -r requirements.txt   # or use environment.yaml
```

#### OpenPose

Download the [OpenPose Windows release](https://github.com/CMU-Perceptual-Computing-Lab/openpose/releases) and extract to a stable path (e.g. `C:\openpose`). Confirm that `models/pose/body_25/` contains the BODY_25 model files.

### 5. Model Checkpoints

Download each checkpoint and place it at the path shown. Total size is approximately 3 GB.

| Checkpoint | Size | Destination | Source |
|-----------|------|-------------|--------|
| `best.pt` (YOLO clothing detector) | ~30 MB | `backend/weights/best.pt` | Project release page |
| `FastSAM-s.pt` | ~23 MB | `backend/weights/FastSAM-s.pt` | [FastSAM repo](https://github.com/CASIA-IVA-Lab/FastSAM) |
| `model_final_162be9.pkl` (DensePose) | ~256 MB | `backend/weights/densepose/model_final_162be9.pkl` | [Detectron2 model zoo](https://github.com/facebookresearch/detectron2/blob/main/projects/DensePose/doc/DENSEPOSE_IUV.md) |
| `inference.pth` (Graphonomy) | ~256 MB | `backend/weights/graphonomy/inference.pth` | [Graphonomy repo](https://github.com/Gaoyiminggithub/Graphonomy) |
| `warp_model_final.pth` (PF-AFN) | ~163 MB | `backend/third_party/PF-AFN_test/checkpoints/warp_model_final.pth` | [PF-AFN repo](https://github.com/geyuying/PF-AFN) |
| `viton512.ckpt` (DCI-VTON) | ~1.6 GB | `backend/third_party/DCI-VTON/checkpoints/viton512.ckpt` | [DCI-VTON repo](https://github.com/bcmi/DCI-VTON-Virtual-Try-On) |
| `vgg19_conv.pth` (DCI-VTON perceptual) | ~548 MB | `backend/weights/vgg/vgg19_conv.pth` | Provided with DCI-VTON release |

### 6. Configure Paths

Open `backend/api_server.py` and update the `CONFIG` dictionary at the top of the file:

```python
CONFIG = {
    # Python executables (full paths to conda env pythons)
    "python_stage2": r"C:\Users\<user>\anaconda3\envs\pfafen-gpu-clean\python.exe",
    "python_stage3": r"C:\Users\<user>\anaconda3\envs\dci-vton\python.exe",

    # Model weights
    "yolo_weights":       r"backend/weights/best.pt",
    "fastsam_weights":    r"backend/weights/FastSAM-s.pt",
    "densepose_weights":  r"backend/weights/densepose/model_final_162be9.pkl",
    "graphonomy_weights": r"backend/weights/graphonomy/inference.pth",

    # OpenPose
    "openpose_root": r"C:\openpose",

    # Stage scripts
    "pfafn_script":   r"backend/third_party/PF-AFN_test/test.py",
    "pfafn_ckpt":     r"backend/third_party/PF-AFN_test/checkpoints/warp_model_final.pth",
    "dcivton_script": r"backend/third_party/DCI-VTON/test.py",
    "dcivton_ckpt":   r"backend/third_party/DCI-VTON/checkpoints/viton512.ckpt",
    "dcivton_config": r"backend/third_party/DCI-VTON/configs/viton512.yaml",
}
```

Then verify the full setup:

```bash
conda activate styles-orch
cd backend
python check_setup.py
```

`check_setup.py` will confirm every file exists and every interpreter is callable. Fix any reported issues before starting the server.

### 7. Run Everything

#### Start the backend

```bash
conda activate styles-orch
cd backend
uvicorn api_server:app --host 0.0.0.0 --port 8000 --reload
```

Swagger UI will be available at `http://localhost:8000/docs`.

#### Configure the Flutter app's base URL

Open `lib/services/virtual_tryon_service.dart` and set the `baseUrl`:

```dart
// Android emulator → host machine
static const String baseUrl = 'http://10.0.2.2:8000';

// Physical device on the same Wi-Fi network
static const String baseUrl = 'http://192.168.1.XXX:8000';
```

#### Run the Flutter app

```bash
flutter run -d <device-id>
```

---

## API Reference

All endpoints are documented interactively at `http://localhost:8000/docs` (Swagger UI).

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/` | Health check — returns `{status, version}` |
| `POST` | `/api/tryon/upload` | Submit person + garment images (multipart form) |
| `POST` | `/api/tryon/process-base64` | Submit images as base64 JSON (fallback) |
| `GET` | `/api/tryon/status/{session_id}` | Poll current pipeline stage and progress |
| `GET` | `/api/tryon/result/{session_id}` | Retrieve final result as `image/png` |
| `DELETE` | `/api/tryon/cleanup/{session_id}` | Delete session artefacts from disk |

### Example: upload and poll

```bash
# Upload
curl -X POST http://localhost:8000/api/tryon/upload \
  -F "person_image=@person.jpg" \
  -F "cloth_image=@cloth.jpg"
# → {"session_id": "abc123", "status": "queued"}

# Poll
curl http://localhost:8000/api/tryon/status/abc123
# → {"session_id": "abc123", "status": "stage2", "stage": "warping", "message": "PF-AFN warping…"}

# Retrieve result
curl http://localhost:8000/api/tryon/result/abc123 --output result.png

# Cleanup
curl -X DELETE http://localhost:8000/api/tryon/cleanup/abc123
```

---

## Environment Variables

These are optional overrides for `api_server.py`:

```bash
export PORT=8000          # Server port (default: 8000)
export HOST=0.0.0.0       # Bind address (default: 0.0.0.0)
export DEVICE=cuda        # Force device: "cuda" or "cpu"
export LOG_LEVEL=INFO     # Logging level: DEBUG | INFO | WARNING
```

---

## Testing

### Backend

```bash
conda activate styles-orch
cd backend
python check_setup.py          # Verify all paths and weights
```

Stage-by-stage testing (comment out later stages in `api_server.py` to isolate):

```bash
# Test Stage 1 only
python -c "from models import yolo, SegmentationSam2, DensePose, OpenPose, Graphonomy; print('Stage 1 imports OK')"

# Full API smoke test
curl http://localhost:8000/
```

### Flutter

```bash
flutter test                   # Unit and widget tests
flutter analyze                # Static analysis
```

End-to-end checklist (manual):
1. Sign up → home screen loads with products
2. Open a product → sizes and colours selectable → add to cart
3. Cart → checkout → place order → appears in My Orders
4. Try-On from home → camera/gallery → Process → result displayed
5. Sign out → sign back in → wishlist and orders persisted

---

## Performance

Measured on Windows 11 with an NVIDIA RTX-class GPU:

| Stage | Typical | Worst case |
|-------|---------|-----------|
| Stage 1 — Preprocessing | 8–18 s | 25 s |
| Stage 2 — PF-AFN Warping | 35–45 s | 60 s |
| Stage 3 — DCI-VTON Diffusion | 60–80 s | 110 s |
| **End-to-end (full pipeline)** | **~90–140 s** | **180 s** |
| Simplified fallback | < 5 s | 8 s |

Cold-start latency (~12 s) is dominated by model loading on first Stage 2 invocation. Using a long-running worker process (future work) would eliminate this overhead.

---

## Known Issues & Roadmap

### Current limitations

- **Stage 3 checkpoint** — `viton512.ckpt` must be downloaded manually; no automated download script yet.
- **Windows-only backend** — OpenPose binaries are distributed for Windows. Linux support requires building OpenPose from source.
- **Single-host threading** — The threading-based job model does not scale horizontally. Suitable for local/demo use; production needs Celery + Redis.
- **Cart not persisted** — Cart state lives in memory during a session. Firestore persistence is planned.

### Roadmap

- [ ] Cloud GPU deployment (AWS EC2 G-class / GCP A2)
- [ ] Real payment gateway — JazzCash, EasyPaisa, Stripe
- [ ] Stage-persistent GPU workers to remove model-load overhead
- [ ] Lower-body garments + full-outfit composition
- [ ] On-device TFLite fallback for zero-latency preview
- [ ] Firebase Cloud Messaging push notifications
- [ ] Google Sign-In and Apple Sign-In
- [ ] Urdu localisation (RTL layout)
- [ ] Expanded product catalogue (1,000+ items)
- [ ] Admin console for catalogue management
- [ ] Prometheus metrics + Grafana dashboards

---

## Team

| Name | Roll Number | Role |
|------|-------------|------|
| **Noman Umer** | 261933598 | Lead developer — Flutter client, backend integration |
| **Naser Muhammed** | 261936735 | ML pipeline — Stage 1 preprocessing wrappers |
| **Muhammed Ibrahim Mughees** | 261945643 | ML pipeline — Stage 2 & 3 subprocess orchestration |

**Primary Advisor:** Ms. Samia Qureshi  
**Institution:** Forman Christian College (A Chartered University), Department of Computer Science

---

## Acknowledgements

- [Han et al. 2018](https://arxiv.org/abs/1711.08447) — VITON, the foundational virtual try-on architecture
- [Ge et al. 2021](https://arxiv.org/abs/2103.04559) — PF-AFN, parser-free appearance flows
- [Gou et al. 2023](https://arxiv.org/abs/2308.06101) — DCI-VTON, diffusion-conditioned composition
- [Güler et al. 2018](https://arxiv.org/abs/1802.00434) — DensePose
- [Cao et al. 2019](https://arxiv.org/abs/1812.08008) — OpenPose
- [Gong et al. 2019](https://arxiv.org/abs/1904.04536) — Graphonomy
- [Zhao et al. 2023](https://arxiv.org/abs/2306.12156) — FastSAM
- [Jocher et al. 2023](https://github.com/ultralytics/ultralytics) — YOLOv8 (Ultralytics)
- [Wu et al. 2019](https://github.com/facebookresearch/detectron2) — Detectron2 (DensePose implementation)
- Flutter, FastAPI, Firebase, Supabase — for excellent SDKs and documentation

---

## License

This project was developed for academic purposes as a Final Year Project at Forman Christian College. The StyleSprint application code (Flutter + FastAPI orchestrator) is released under the [MIT License](LICENSE).

Third-party ML models integrated in this project retain their own licences:

| Component | Licence |
|-----------|---------|
| PF-AFN | Non-commercial research only |
| DCI-VTON | Non-commercial research only |
| Detectron2 / DensePose | Apache 2.0 |
| OpenPose | Non-commercial — see [OpenPose licence](https://github.com/CMU-Perceptual-Computing-Lab/openpose/blob/master/LICENSE) |
| Graphonomy | MIT |
| FastSAM | Apache 2.0 |
| YOLOv8 | AGPL-3.0 |

**For any commercial use, verify and comply with the individual licences of all integrated components.**
