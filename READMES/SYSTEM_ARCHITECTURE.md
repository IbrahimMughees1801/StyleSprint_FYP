# Virtual Try-On System - Complete Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         USER'S PHONE                                 │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │              StyleSprint Flutter App                          │ │
│  │                                                               │ │
│  │  ┌─────────────────────────────────────────────────────┐    │ │
│  │  │  Product Detail Screen                              │    │ │
│  │  │                                                      │    │ │
│  │  │  [Product Image]                                    │    │ │
│  │  │  ┌──────────────────────────┐                       │    │ │
│  │  │  │  🌟 Try This On Button   │  ← User clicks       │    │ │
│  │  │  └──────────────────────────┘                       │    │ │
│  │  └─────────────────────┬────────────────────────────────┘    │ │
│  │                        │                                      │ │
│  │                        ▼                                      │ │
│  │  ┌─────────────────────────────────────────────────────┐    │ │
│  │  │  Virtual Try-On Dialog                              │    │ │
│  │  │                                                      │    │ │
│  │  │  1. Upload Photo 📷                                 │    │ │
│  │  │  2. Processing... ⏳                                │    │ │
│  │  │     → Stage 1: Preprocessing                        │    │ │
│  │  │     → Stage 2: Warping                              │    │ │
│  │  │     → Stage 3: Generating Result                    │    │ │
│  │  │  3. Show Result! ✨                                 │    │ │
│  │  └─────────────────────┬────────────────────────────────┘    │ │
│  └────────────────────────┼────────────────────────────────────┘ │
└───────────────────────────┼──────────────────────────────────────┘
                            │
                            │ HTTP/REST API
                            │ (http://192.168.x.x:8000)
                            │
┌───────────────────────────▼──────────────────────────────────────┐
│                    YOUR COMPUTER / SERVER                         │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │           FastAPI Backend (api_server.py)                   ││
│  │                                                             ││
│  │  ┌────────────────────────────────────────────────────┐   ││
│  │  │  POST /api/tryon/upload                            │   ││
│  │  │  ├─ Receives: person_image, cloth_image            │   ││
│  │  │  └─ Returns: session_id                            │   ││
│  │  └────────────────────────────────────────────────────┘   ││
│  │                        │                                    ││
│  │                        ▼                                    ││
│  │  ┌────────────────────────────────────────────────────┐   ││
│  │  │  STAGE 1: Preprocessing (torch112 env)             │   ││
│  │  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ││
│  │  │  [YOLO] → [FastSAM] → [DensePose]                 │   ││
│  │  │      ↓         ↓           ↓                       │   ││
│  │  │  [OpenPose] → [Graphonomy] → [Parse Agnostic]     │   ││
│  │  │                                                    │   ││
│  │  │  Output: temp_uploads/image-parse-agnostic-v3.2/  │   ││
│  │  └────────────────────────────────────────────────────┘   ││
│  │                        │                                    ││
│  │                        ▼                                    ││
│  │  ┌────────────────────────────────────────────────────┐   ││
│  │  │  STAGE 2: Cloth Warping (dci-vton env)            │   ││
│  │  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ││
│  │  │  subprocess.run([                                  │   ││
│  │  │    python_dci_vton,                                │   ││
│  │  │    eval_PBAFN_viton.py,                           │   ││
│  │  │    --warp_checkpoint=warp_viton.pth               │   ││
│  │  │  ])                                                │   ││
│  │  │                                                    │   ││
│  │  │  PF-AFN Model:                                     │   ││
│  │  │  • Warps cloth to match person's pose             │   ││
│  │  │  • Generates warped cloth + mask                  │   ││
│  │  │                                                    │   ││
│  │  │  Output: temp_uploads/unpaired-cloth-warp/        │   ││
│  │  └────────────────────────────────────────────────────┘   ││
│  │                        │                                    ││
│  │                        ▼                                    ││
│  │  ┌────────────────────────────────────────────────────┐   ││
│  │  │  STAGE 3: Diffusion Model (dci-vton env)          │   ││
│  │  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │   ││
│  │  │  subprocess.run([                                  │   ││
│  │  │    python_dci_vton,                                │   ││
│  │  │    test.py,                                        │   ││
│  │  │    --ckpt=viton512_v2.ckpt,                       │   ││
│  │  │    --config=viton512_v2.yaml                      │   ││
│  │  │  ])                                                │   ││
│  │  │                                                    │   ││
│  │  │  DCI-VTON Diffusion:                              │   ││
│  │  │  • Generates photo-realistic result               │   ││
│  │  │  • Natural lighting & shadows                     │   ││
│  │  │  • Realistic wrinkles & fabric drape              │   ││
│  │  │                                                    │   ││
│  │  │  Output: FINAL/result/session_id_result.png       │   ││
│  │  └────────────────────────────────────────────────────┘   ││
│  │                        │                                    ││
│  │  ┌────────────────────▼────────────────────────────┐      ││
│  │  │  GET /api/tryon/status/{session_id}             │      ││
│  │  │  ├─ Returns: {"status": "processing",           │      ││
│  │  │  │            "stage": "running_warping"}        │      ││
│  │  │  └─ Or: {"status": "completed"}                 │      ││
│  │  └─────────────────────────────────────────────────┘      ││
│  │                        │                                    ││
│  │  ┌────────────────────▼────────────────────────────┐      ││
│  │  │  GET /api/tryon/result/{session_id}             │      ││
│  │  │  └─ Returns: Final PNG image                    │      ││
│  │  └─────────────────────────────────────────────────┘      ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   File System                               ││
│  │                                                             ││
│  │  temp_uploads/                 ← Working directory         ││
│  │  ├── image/                    ← Person images             ││
│  │  ├── cloth/                    ← Clothing images           ││
│  │  ├── openpose_json/            ← Pose keypoints            ││
│  │  ├── image-parse-v3/           ← Human parsing             ││
│  │  ├── agnostic-v3.2/            ← Agnostic representation   ││
│  │  ├── image-parse-agnostic-v3.2/ ← Agnostic parse          ││
│  │  ├── unpaired-cloth-warp/     ← Stage 2 output            ││
│  │  └── unpaired-cloth-warp-mask/                            ││
│  │                                                             ││
│  │  results/                      ← Intermediate results      ││
│  │  ├── cloth-warp/                                           ││
│  │  └── cloth-warp-mask/                                      ││
│  │                                                             ││
│  │  FINAL/                        ← Final output! ✨         ││
│  │  └── result/                   ← Try-on images            ││
│  │      └── {session_id}_result.png                          ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   ML Models & Repos                         ││
│  │                                                             ││
│  │  weights/                      ← Model checkpoints         ││
│  │  ├── best.pt                   ← YOLO                      ││
│  │  ├── FastSAM-s.pt              ← FastSAM                   ││
│  │  ├── model_final_162be9.pkl    ← DensePose                ││
│  │  ├── inference.pth             ← Graphonomy                ││
│  │  ├── warp_viton.pth            ← PF-AFN (Stage 2)         ││
│  │  └── viton512_v2.ckpt          ← DCI-VTON (Stage 3)       ││
│  │                                                             ││
│  │  models/                       ← Python model wrappers     ││
│  │  ├── yolo.py                                               ││
│  │  ├── SegmentationSam2.py                                   ││
│  │  ├── DensePose.py                                          ││
│  │  ├── OpenPose.py                                           ││
│  │  ├── ParseAgnostic.py                                      ││
│  │  └── helper.py                                             ││
│  │                                                             ││
│  │  External Repos:                                           ││
│  │  ├── PF-AFN/                   ← Stage 2 warping           ││
│  │  ├── DCI-VTON-Virtual-Try-On/  ← Stage 3 diffusion        ││
│  │  ├── Graphonomy/               ← Human parsing             ││
│  │  └── openpose/                 ← Pose estimation           ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   Conda Environments                        ││
│  │                                                             ││
│  │  torch112/                     ← Stage 1 (Preprocessing)   ││
│  │  └── python.exe                                            ││
│  │                                                             ││
│  │  dci-vton/                     ← Stages 2 & 3              ││
│  │  └── python.exe                                            ││
│  └─────────────────────────────────────────────────────────────┘│
└───────────────────────────────────────────────────────────────────┘
```

## Data Flow Example

```
USER: Uploads selfie + selects t-shirt
                 │
                 ▼
┌────────────────────────────────────────────────┐
│ 1. API receives images                         │
│    → Saves to temp_uploads/image/              │
│    → Saves to temp_uploads/cloth/              │
│    → Creates session: abc-123-def              │
└──────────────────┬─────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────┐
│ 2. STAGE 1: Preprocessing (30-60s)            │
│    → YOLO detects t-shirt in image            │
│    → FastSAM segments t-shirt                 │
│    → DensePose maps body                      │
│    → OpenPose extracts keypoints              │
│    → Graphonomy segments body parts           │
│    → Creates agnostic representation          │
│                                                │
│    Files created:                              │
│    ✓ openpose_json/abc-123-def_keypoints.json │
│    ✓ image-parse-v3/abc-123-def.png           │
│    ✓ agnostic-v3.2/abc-123-def.jpg            │
└──────────────────┬─────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────┐
│ 3. STAGE 2: Cloth Warping (15-30s)            │
│    → PF-AFN warps t-shirt to match pose       │
│    → Adjusts for body shape and position      │
│    → Generates warped cloth + mask            │
│                                                │
│    Files created:                              │
│    ✓ unpaired-cloth-warp/abc-123-def.png      │
│    ✓ unpaired-cloth-warp-mask/abc-123-def.png │
└──────────────────┬─────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────┐
│ 4. STAGE 3: Diffusion Model (45-90s)          │
│    → DCI-VTON generates realistic result      │
│    → Adds natural lighting                    │
│    → Creates realistic shadows                │
│    → Adds fabric wrinkles and texture         │
│                                                │
│    File created:                               │
│    ✓ FINAL/result/abc-123-def_result.png ✨   │
└──────────────────┬─────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────┐
│ 5. USER sees result in Flutter app!           │
│    → Downloads from /api/tryon/result/abc...  │
│    → Displays in dialog                       │
│    → User can save/share/retry                │
└────────────────────────────────────────────────┘
```

## File Names Through Pipeline

```
Input:
  person_image.jpg
  cloth_image.jpg
             ↓
Saved as:
  abc-123-def_person.jpg
  abc-123-def_cloth.jpg
             ↓
Stage 1 outputs:
  abc-123-def_person_keypoints.json
  abc-123-def_person.png (parse)
  abc-123-def_person.jpg (agnostic)
             ↓
Stage 2 outputs:
  abc-123-def_person.png (warped cloth)
  abc-123-def_person.png (warp mask)
             ↓
Stage 3 output:
  abc-123-def_result.png  ← FINAL! ✨
```

## Technology Stack

```
Frontend:
  ├─ Flutter/Dart
  ├─ Material Design UI
  ├─ HTTP client
  └─ Image picker

Backend:
  ├─ FastAPI (Python)
  ├─ Uvicorn server
  └─ Subprocess management

ML Pipeline:
  ├─ Stage 1 (torch112 env)
  │  ├─ YOLO (Ultralytics)
  │  ├─ FastSAM (CASIA-IVA-Lab)
  │  ├─ DensePose (Facebook)
  │  ├─ OpenPose (CMU)
  │  └─ Graphonomy
  │
  ├─ Stage 2 (dci-vton env)
  │  └─ PF-AFN (Parser-Free AFN)
  │
  └─ Stage 3 (dci-vton env)
     └─ DCI-VTON (Diffusion)
```

## Timing Breakdown

```
Total: ~2-3 minutes on GPU

├─ Stage 1: 30-60s     ████████████░░░░░░░░
├─ Stage 2: 15-30s     ██████░░░░░░░░░░░░░░
└─ Stage 3: 45-90s     ██████████████████░░
```

---

**This is what you're building!** 🚀

A complete, production-ready virtual try-on system from phone to server to AI models and back!
