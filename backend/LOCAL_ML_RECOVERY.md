# Local ML Recovery Guide

This file records the large local artifacts that are intentionally excluded
from Git. The source code, setup scripts, evaluation documentation, and model
configuration are committed, but model repositories, checkpoints, generated
datasets, caches, and experiment results are not.

## Main Pipeline

```text
YOLO -> FastSAM -> DensePose -> OpenPose -> Graphonomy -> PF-AFN -> DCI-VTON
```

The backend entry point is `backend/api_server.py`. Evaluation commands are in
`backend/QUICK_REFERENCE.txt`.

## Third-Party Repositories

Restore these under `backend/third_party/`:

```text
DCI-VTON-Virtual-Try-On  https://github.com/bcmi/DCI-VTON-Virtual-Try-On.git
PF-AFN                   https://github.com/geyuying/PF-AFN
FastSAM                  https://github.com/CASIA-IVA-Lab/FastSAM
Graphonomy               https://github.com/Gaoyiminggithub/Graphonomy
detectron2               https://github.com/facebookresearch/detectron2
openpose                 https://github.com/CMU-Perceptual-Computing-Lab/openpose
```

OpenPose was stored locally at:

```text
backend/third_party/openpose/openpose
```

## Required Base Weights

These were stored under the project-level `weights/` folder:

```text
best.pt                                  YOLO clothing detector, about 6 MB
best_pre_product_finetune_20260531.pt    Earlier YOLO detector, about 6 MB
FastSAM-s.pt                             FastSAM weights, about 23 MB
inference.pth                            Graphonomy weights, about 159 MB
model_final_162be9.pkl                   DensePose weights, about 244 MB
pfafn_checkpoints.zip                    PF-AFN checkpoint archive, about 258 MB
```

The DCI-VTON checkpoint was:

```text
backend/third_party/DCI-VTON-Virtual-Try-On/checkpoints/viton512_v2.ckpt
```

It is approximately 5 GB and is not suitable for normal GitHub storage.

The bundled PF-AFN checkpoints were:

```text
backend/third_party/PF-AFN/PF-AFN_test/checkpoints/PFAFN/warp_model_final.pth
backend/third_party/PF-AFN/PF-AFN_test/checkpoints/PFAFN/gen_model_final.pth
```

## Tuned PF-AFN Checkpoints

The final API prefers this tuned checkpoint when it exists:

```text
backend/results/pf_afn_finetune/warp_vitonhd_tops_curated300_continue_180step.pth
```

Other experiment checkpoints previously generated:

```text
warp_selfrecon_v3_curated_60step.pth
warp_vitonhd_selfrecon_60step.pth
warp_vitonhd_selfrecon_sanity_10step.pth
warp_vitonhd_tops_curated_60step.pth
warp_vitonhd_tops_strict180_continue_80step.pth
```

Each PF-AFN checkpoint is approximately 112 MB. Preserve the preferred tuned
checkpoint separately before deleting all experiment results.

## Python Environments

`backend/api_server.py` expects these Conda environments:

```text
C:\Users\muhdi\miniconda3\envs\torch112
C:\Users\muhdi\miniconda3\envs\dci-vton
C:\Users\muhdi\miniconda3\envs\pfafen-gpu-clean
```

The project also used:

```text
.venv
.venv-pfafen
```

See `backend/requirements.txt`, setup scripts, and `verify_ml_setup.py` when
rebuilding environments.

## Generated and Disposable Folders

These folders are ignored by Git and can be regenerated:

```text
build/
.dart_tool/
runs/
backend/.cache/
backend/results/
backend/temp_uploads/
backend/FINAL*/
backend/datasets/
```

`backend/results/` may contain tuned checkpoints and audit outputs. Copy any
checkpoint or result image worth preserving before deleting that folder.

## Controlled Evaluation Assets

The controlled black wrap top exists in Supabase as:

```text
Controlled Black Wrap Top
catalog_id: 69
```

Additional controlled full-sleeve products use catalog IDs `7001` to `7006`.
Their upload scripts are:

```text
tools/upload_controlled_black_wrap_top.ps1
tools/upload_controlled_full_sleeve_products.ps1
```

## Git Repository

```text
https://github.com/IbrahimMughees1801/StyleSprint_FYP.git
```

Clone the repository, restore the ignored artifacts above, then follow
`backend/QUICK_REFERENCE.txt` to start the full ML backend and phone tunnel.
