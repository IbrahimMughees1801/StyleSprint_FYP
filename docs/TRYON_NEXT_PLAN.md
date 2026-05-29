# Virtual Try-On Next Plan

Last updated: May 26, 2026

## Current Honest Status

The full 3-stage pipeline is executable, but the try-on result is not usable yet.

The latest real dataset test completed without crashing:

- Person image: `C:\Users\muhdi\Desktop\mobile database\person.jpg`
- Product image: `C:\Users\muhdi\Desktop\mobile database\ecommerce products\tshirt\99.jpg`
- Output: `backend\FINAL\result\dataset_0d0e72b5_result.png`
- Mode returned: `ml_pipeline`
- Diffusion steps: `1`

However, the generated image was green/dark and did not replace the shirt. That means the pipeline currently passes an engineering smoke test, but fails the actual product-quality test.

## Update After `shirt1.jpg` Debug Run

Test:

- Person image: `C:\Users\muhdi\Desktop\mobile database\person.jpg`
- Product image: `C:\Users\muhdi\Desktop\mobile database\shirt1.jpg`
- Session: `shirt1_b3303569`
- Output: `backend\FINAL\result\shirt1_b3303569_result.png`
- Debug sheet: `backend\results\debug\shirt1_b3303569_debug_sheet.jpg`

This run proved the product side can work when the garment image is cleaner:

- YOLO covered the shirt properly: `(202, 113, 570, 942)`
- The cloth mask looked clean.
- PF-AFN produced a warped shirt.

But the run still failed visually because the human parser collapsed the person parse into one class:

```text
Human parse collapsed to 1 label(s): [7]
```

That is the clearest current blocker. DCI cannot perform a valid try-on when the person parse does not describe body parts and clothing regions. It receives a nearly meaningless parse/agnostic input and produces a corrupted green image.

Strict preflight checks were added so this kind of bad parse should now stop before PF-AFN/DCI instead of wasting a full run.

## Human Parsing Fix Added

Graphonomy is still unreliable on our current portrait input, but the pipeline now has a fallback parser:

- Graphonomy runs first.
- If its parse map collapses to fewer than 3 labels, the backend generates a VITON-style parse map from OpenPose keypoints.
- The fallback creates labels for background, face/head, upper body, lower body, left arm, and right arm.
- Preflight now passes with the fallback parse.

Validation run:

- Session: `fallback_f595c317`
- Parse labels: valid multi-label map
- Preflight: passed
- Debug sheet: `backend\results\debug\fallback_f595c317_debug_sheet.jpg`

The final image was still green, so the active blocker has moved downstream from human parsing to DCI input composition/output normalization.

I also switched the local DCI runner from `cp_dataset` to `cp_dataset_v2`, matching `viton512_v2.yaml`. That changed the output mask behavior but did not fix the green artifact, confirming the next issue is inside DCI conditioning/composition rather than the parser alone.

## DCI Check: Green Output Root Cause Found

DCI was generating invalid numeric values in the default `autocast` precision path on this machine. The visible symptom was the green/dark output and this warning at save time:

```text
RuntimeWarning: invalid value encountered in cast
```

I added DCI tensor diagnostics around input loading, CLIP conditioning, VAE encoding, PLMS sampling, decoding, composition, and save. The important result:

- `autocast` path: produced invalid output during the DCI save path.
- `full` precision path: no NaNs or Infs in the same prepared test inputs.

I also fixed DCI's `--precision full` mode. The script was still forcing the CLIP reference tensor to `float16`, which made full precision crash with:

```text
Input type (torch.cuda.HalfTensor) and weight type (torch.cuda.FloatTensor) should be the same
```

Current DCI validation:

- Prepared inputs: `v2parse_56cb4de6`
- Command mode: `--precision full`
- 1 diffusion step: no green/NaN output, but noisy as expected.
- 10 diffusion steps: produced an actual blue shirt result instead of green corruption.
- Output: `backend\FINAL_FULL10\result\v2parse_56cb4de6_person.png`

The 10-step result is still not production quality. The shirt appears, but the crossed arms and oversized agnostic mask cause heavy artifacts. This means DCI is now running, but the person preparation/masking quality is the next visual blocker.

Backend update:

- API now passes `--precision full` to DCI by default.
- Override is available with `API_DIFFUSION_PRECISION`.
- DCI's local default was also changed from `autocast` to `full`.

## Crossed-Arm Parsing Patch

The next visual issue was crossed-arm occlusion. DCI restores original pixels only where the human parse labels arms as `14` or `15`. Our OpenPose fallback parse was drawing arms mostly from shoulder-elbow-wrist skeleton lines. On the test portrait, OpenPose missed both wrists and placed elbows very low, so the visible crossed forearms were not labeled as arms. DCI then treated those forearms as replaceable shirt area.

Patch added:

- The fallback parser now detects missing wrists or unusually low elbows.
- When that crossed-arm signal is present, it scans the lower torso area for visible skin-colored connected components.
- Those components are lightly dilated and written back into the parse as left/right arm labels.
- Lower-body labels are drawn before arms so arm occlusions stay in front of clothing/lower labels.

Validation:

- Previous 10-step full precision result: shirt appeared, but crossed arms were washed into the generated shirt.
- First crossed-arm patch: arms were preserved better, but the center tie/jacket area was over-preserved.
- Tightened crossed-arm patch: best result so far. Forearms and hands survive better, with less over-preservation in the torso center.

Latest comparison output:

```text
backend\FINAL_CROSSED_TIGHT10\result\v2parse_56cb4de6_person.png
```

This is still not final-quality try-on, but it is a real improvement in occlusion handling for crossed-arm portraits.

## Old Clothing Fragment Patch

After the crossed-arm patch, some old clothing still leaked into the generated shirt. The main cause was over-preservation: when OpenPose missed wrists, the fallback parser used synthetic wrist fallback points and drew long arm labels through the torso. DCI restores original pixels wherever the parse says "arm", so fake arm labels through the tie/jacket area preserved old clothing fragments.

Patch added:

- Missing wrists no longer create fake arm skeleton lines through the torso.
- Reliable arm lines are drawn only when real wrist keypoints exist, or when elbow-only geometry is still near the shoulder.
- Crossed-arm preservation now relies more on visible skin components.
- Skin detection now combines YCrCb and HSV thresholds so dark red/brown clothing, like the tie, is less likely to be mistaken for skin.

Validation:

- Previous output: `backend\FINAL_CROSSED_TIGHT10\result\v2parse_56cb4de6_person.png`
- New output: `backend\FINAL_NO_FRAG10\result\v2parse_56cb4de6_person.png`

The new result has much less old tie/jacket leakage inside the generated shirt area. It still has artifacts, but the failure is now more about natural hand/occlusion rendering than obvious previous-clothing fragments.

## Why This Failed Visually

### 1. The Product Image Was Not a Clean Garment Image

The file `99.jpg` is a fashion model wearing a gray t-shirt. It is not a standalone shirt cutout or flat product image.

Our pipeline expects the cloth input to behave like a VITON garment image:

- mostly just the garment
- minimal body/face/background
- clear clothing silhouette
- clean mask

For `99.jpg`, YOLO detected:

```text
(230, 16, 428, 141)
```

That is near the upper/head/neck area of the product-model image, not the full t-shirt region. So Stage 1 sent a bad cloth crop/mask downstream.

Bad cloth mask -> bad PF-AFN warp -> bad DCI-VTON conditioning -> bad final image.

### 2. The Person Image Is Hard for This Pipeline

The person photo is a formal portrait:

- arms folded
- black suit jacket
- white shirt and tie
- dark background
- upper body only

Most VITON-style pipelines work best on front-facing full or mid-body images where the torso and arms are clearly separated. Folded arms and suit layers make parsing much harder.

The model is trying to replace an upper garment, but the visible clothing is not a simple t-shirt region. It has suit lapels, cuffs, tie, arms crossing the chest, and dark-on-dark boundaries.

### 3. The Green Output Suggests Output Normalization or Invalid Latent Values

The run emitted this warning:

```text
RuntimeWarning: invalid value encountered in cast
```

That means DCI produced invalid numeric values, likely NaN or out-of-range values, before saving the final image. The green tint is probably not a fashion result; it is a broken decode/save artifact from bad conditioning or unstable low-step diffusion.

### 4. We Used 1 Diffusion Step

`API_DIFFUSION_STEPS=1` is only useful to prove the code path runs. It is not enough for image quality.

Still, even at 1 step, we should expect a rough but recognizable try-on. Since this output was completely wrong, increasing to 30 steps alone is not the next move. We need to fix input preparation and output validation first.

## Why It Took About 12 Minutes

The strict real-data run took about 684 seconds, which is roughly 11.4 minutes.

Approximate breakdown:

| Stage | Time / Cost |
|---|---:|
| OpenPose | ~307 seconds |
| Graphonomy parsing | ~28 seconds |
| YOLO + FastSAM + DensePose | tens of seconds |
| PF-AFN subprocess startup + warp | likely tens of seconds |
| DCI-VTON model load + 1-step diffusion | likely several minutes |

The biggest reason is that the pipeline launches multiple old research models as separate processes:

1. OpenPose is running from the Windows OpenPose binary and took about 5 minutes by itself.
2. Graphonomy runs in a separate `torch112` conda environment.
3. PF-AFN runs in a separate `pfafen-gpu-clean` conda environment.
4. DCI-VTON runs in a separate `dci-vton` conda environment and loads a 5.3 GB checkpoint.
5. The GPU is a GTX 1650 Max-Q with 4 GB VRAM, so the heavy parts cannot stay fully resident comfortably.
6. Because each stage is a separate process, models are repeatedly loaded from disk instead of staying warm in memory.

So the 12-minute runtime is not because one clean model spent 12 minutes doing useful try-on inference. It is mostly model startup, preprocessing, subprocess overhead, old Windows binaries, and a very slow OpenPose stage.

Important fix added:

OpenPose was accidentally processing the whole accumulated `backend\temp_uploads\image` folder, not just the current request. The runner now creates a one-image input folder per request.

After that fix, OpenPose dropped from roughly 307 seconds to roughly 17 seconds on the `shirt1.jpg` run. The full 1-step run dropped from about 11.4 minutes to about 3 minutes.

## What We Should Do Next

### Phase 1: Build a Valid Test Pair

Before changing models, create one controlled test pair:

- Person image should be front-facing.
- Arms should be down or slightly away from torso.
- Torso should be visible.
- Existing top should be simple.
- Product image should be a clean t-shirt image, not a model wearing it.

Try candidates:

```text
C:\Users\muhdi\Desktop\mobile database\shirt1.jpg
```

or manually pick one `ecommerce products\tshirt\*.jpg` that is a standalone product image.

### Phase 2: Add Debug Contact Sheets

We need a debug output image per run showing:

- original person
- original product
- YOLO clothing box
- FastSAM cloth mask
- DensePose output
- OpenPose output
- Graphonomy parse
- agnostic image
- PF-AFN warped cloth
- DCI final output

This will show exactly where the pipeline breaks instead of guessing from the final image.

Status: added. Debug sheets are saved under:

```text
backend\results\debug\<session>_debug_sheet.jpg
```

### Phase 3: Validate Intermediate Files Before Running DCI

Add preflight checks:

- cloth mask is not empty
- cloth mask covers a reasonable percentage of the image
- parse map uses only labels `0..19`
- openpose has at least body keypoints
- PF-AFN warp output exists and is not blank
- DCI input tensors do not contain invalid values

If a check fails, the API should return a clear error instead of spending 12 minutes and producing green output.

Status: partially added.

Current preflight checks:

- cloth mask exists and is not empty
- human parse exists and has at least 3 labels
- OpenPose JSON exists and has enough confident body keypoints

The current `person.jpg` fails with raw Graphonomy because Graphonomy produces only one parse label. The OpenPose fallback now repairs this enough for preflight to pass.

### Phase 4: Fix Garment Extraction for Catalog Images

Our product dataset seems mixed: some images are standalone products, others are models wearing products.

We need one of these approaches:

1. Prefer standalone product images only for VITON.
2. Add a garment extraction step for model-worn product images.
3. Store a prepared `cloth_mask` or transparent PNG per product in the database.

The most realistic FYP path is option 3: preprocess product images once, save cleaned garment assets, and use those at try-on time.

### Phase 5: Improve Runtime

After quality is fixed, reduce runtime:

- Replace OpenPose with a faster keypoint model if possible.
- Keep ML models warm in a long-running worker instead of spawning subprocesses.
- Cache preprocessing for repeated person/product tests.
- Run DCI only after all intermediate checks pass.
- Use `steps=1` only for smoke tests, `steps=10` for quick quality tests, and `steps=30` for final demos.

## Immediate Next Test When Back

Do not spend more DCI runs on the current `person.jpg` until parsing is fixed or we use a better person image.

First, test the parser on a simpler person image:

- front-facing
- arms down
- visible torso
- normal top
- plain-ish background

Then inspect:

```text
backend\results\debug\<session>_debug_sheet.jpg
```

If the parse-label tile has multiple body/clothing classes, continue to PF-AFN/DCI.

If the parse-label tile is a single solid color, fix/replace the human parser before trying DCI again.

Current state: parse-label tile is now multi-label with the fallback parser. The next investigation should focus on DCI green-output generation.

Original candidate strict test:

- `person.jpg`
- `shirt1.jpg`
- `API_DIFFUSION_STEPS=1`

Then inspect the debug intermediates, not only the final output.

If the cloth mask and warp are bad, fix Stage 1 or Stage 2 first.

If the mask and warp look good but DCI is green, fix DCI decoding/input normalization.

## Success Criteria

We should not call the ML try-on working until:

- The final output visibly replaces the upper garment.
- The result is not tinted green or corrupted.
- The pipeline rejects bad product images before DCI.
- A test run produces a readable debug contact sheet.
- Runtime is understood and acceptable for demo mode.
