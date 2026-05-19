# StyleSprint FYP (fyp_app)

AI-powered fashion e-commerce app with a 3-stage virtual try-on pipeline.

## Highlights

- Flutter client with virtual try-on UI and API integration.
- FastAPI backend with 3-stage ML pipeline:
	1) Preprocess (YOLO, FastSAM, DensePose, OpenPose, Graphonomy)
	2) Warping (PF-AFN)
	3) Diffusion (DCI-VTON)
- Local development supported on Windows.

## Repository Layout

- Flutter app: `lib/`, `android/`, `ios/`
- Backend: `backend/`
- ML assets: `weights/`, `backend/third_party/`

## Quick Start (Flutter)

```bash
flutter pub get
flutter run
```

## Quick Start (Backend)

```bash
cd backend
python api_server.py
```

API docs: `http://localhost:8000/docs`

## Notes

- The Flutter app calls the backend at `http://localhost:8000` by default.
	For a physical device, update the base URL to your PC's LAN IP in
	`lib/services/virtual_tryon_service.dart`.
- Stage 2 (PF-AFN) is wired locally; Stage 3 (DCI-VTON) is being finalized.

See [backend/README.md](backend/README.md) for detailed backend setup and
pipeline instructions.
