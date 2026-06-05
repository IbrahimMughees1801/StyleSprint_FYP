# Virtual Try-On Model Formulas

This document explains the main mathematical ideas used in the StyleSprint
virtual try-on pipeline. The system combines object detection, segmentation,
pose estimation, human parsing, cloth warping, and diffusion-based image
generation.

Pipeline:

```text
YOLO -> FastSAM -> DensePose -> OpenPose -> Graphonomy -> PF-AFN -> DCI-VTON
```

## 1. YOLO Clothing Detection

YOLO detects the garment region in the product image.

The model predicts a bounding box:

```text
B = (x_min, y_min, x_max, y_max)
```

The width and height of the box are:

```text
width  = x_max - x_min
height = y_max - y_min
```

The area of the box is:

```text
Area(B) = width * height
```

YOLO uses a confidence score to decide whether a prediction should be kept:

```text
confidence = objectness_score * class_probability
```

Intersection over Union is commonly used to compare predicted boxes:

```text
IoU = Area(B_pred intersect B_true) / Area(B_pred union B_true)
```

In this project, YOLO is used to find the clothing box before segmentation. The
box is passed to FastSAM so the segmentation model focuses on the correct
garment area.

## 2. FastSAM Cloth Segmentation

FastSAM creates a garment mask from the product image.

A binary mask can be written as:

```text
M(x, y) = 1  if pixel (x, y) belongs to the garment
M(x, y) = 0  otherwise
```

Mask coverage is:

```text
coverage = number_of_garment_pixels / total_number_of_pixels
```

The masked garment image is:

```text
C_masked(x, y) = C(x, y) * M(x, y)
```

Where:

- `C(x, y)` is the original cloth image pixel
- `M(x, y)` is the cloth mask
- `C_masked(x, y)` is the extracted cloth pixel

This step removes the product background and gives PF-AFN/DCI-VTON a cleaner
cloth input.

## 3. OpenPose Keypoint Estimation

OpenPose detects human body joints in the person image.

Each keypoint is represented as:

```text
K_i = (x_i, y_i, c_i)
```

Where:

- `x_i` is the horizontal coordinate
- `y_i` is the vertical coordinate
- `c_i` is the confidence score

The distance between two keypoints is calculated using Euclidean distance:

```text
d(K_i, K_j) = sqrt((x_i - x_j)^2 + (y_i - y_j)^2)
```

This helps describe body pose, shoulder width, arm position, torso direction,
and other layout information needed for virtual try-on.

## 4. DensePose Body Surface Mapping

DensePose maps pixels from the person image to a human body surface.

For each body pixel:

```text
D(x, y) = (I, U, V)
```

Where:

- `I` is the body part index
- `U` is the horizontal coordinate on that body part surface
- `V` is the vertical coordinate on that body part surface

This gives the pipeline a stronger understanding of the person's 3D body layout
than keypoints alone.

## 5. Graphonomy Human Parsing

Graphonomy performs semantic segmentation on the person image.

Each pixel is assigned a body/clothing label:

```text
P(x, y) = class_id
```

Example labels include:

```text
background, hair, face, upper_clothes, arms, pants, shoes
```

For a specific class, a binary mask can be created:

```text
M_class(x, y) = 1  if P(x, y) = class_id
M_class(x, y) = 0  otherwise
```

This parsing is used to create the agnostic person representation, where the
original upper clothing is removed or hidden before applying the new garment.

## 6. Agnostic Person Representation

The agnostic image removes the original clothing region while preserving body,
face, hair, and background details.

Using a clothing mask `M_cloth`, the hidden region can be represented as:

```text
I_agnostic(x, y) = I_person(x, y) * (1 - M_cloth(x, y))
```

In practice, the implementation also preserves important non-clothing regions
such as face, hair, hands, pants, and background.

The goal is to give the try-on model a person image where the old upper garment
does not conflict with the new garment.

## 7. PF-AFN Cloth Warping

PF-AFN aligns the garment with the target person's pose and body shape.

The model estimates a flow field:

```text
F(x, y) = (flow_x(x, y), flow_y(x, y))
```

The warped cloth is obtained by sampling the original cloth image using this
flow:

```text
C_warped(x, y) = C(x + flow_x(x, y), y + flow_y(x, y))
```

More compactly:

```text
C_warped = sample(C, F)
```

Where:

- `C` is the original cloth image
- `F` is the learned transformation/flow field
- `C_warped` is the cloth aligned to the person

PF-AFN is important because it provides DCI-VTON with a spatial guide for where
the garment should appear on the body.

## 8. DCI-VTON Diffusion Generation

DCI-VTON creates the final try-on image using a diffusion model.

Diffusion models work by adding noise during a forward process and learning to
remove that noise during the reverse process.

The forward noising step can be written as:

```text
x_t = sqrt(alpha_t) * x_0 + sqrt(1 - alpha_t) * epsilon
```

Where:

- `x_0` is the clean target image
- `x_t` is the noisy image at timestep `t`
- `alpha_t` controls how much of the original image remains
- `epsilon` is random Gaussian noise

The model predicts the noise:

```text
epsilon_pred = model(x_t, t, conditioning)
```

The common training objective is mean squared error between true noise and
predicted noise:

```text
L = mean((epsilon - epsilon_pred)^2)
```

During inference, DCI-VTON repeatedly denoises the image while using
conditioning inputs:

```text
conditioning = person_agnostic + pose + parse + cloth + cloth_mask + warped_cloth
```

The final output is:

```text
I_tryon = DCI_VTON(conditioning)
```

In this project, DCI-VTON is responsible for making the final image look more
natural after PF-AFN has provided the warped garment guide.

## 9. Image Blending and Mask Use

Many try-on operations depend on masks. A standard mask blend is:

```text
I_output = M * I_foreground + (1 - M) * I_background
```

Where:

- `M` is a mask with values from 0 to 1
- `I_foreground` is the garment or generated region
- `I_background` is the original person/background region

This idea is used throughout preprocessing and postprocessing to preserve
important regions while replacing the clothing area.

## 10. Audit and Quality Metrics

The audit scripts use practical image measurements to estimate whether a stage
looks healthy.

### Mask Coverage

```text
coverage = mask_pixels / total_pixels
```

This helps detect masks that are too small, too large, or empty.

### Pixel Difference

```text
diff(x, y) = abs(I_a(x, y) - I_b(x, y))
```

This helps compare two stage outputs or detect whether an image changed too
much.

### Mean Squared Error

```text
MSE = mean((I_a - I_b)^2)
```

This measures average squared pixel difference between two images.

### Structural Similarity Concept

When comparing visual quality, the main idea is to preserve structure:

```text
similarity = structure_preservation + contrast_preservation + luminance_preservation
```

The project mostly uses practical audit checks rather than a formal benchmark
dataset, but the goal is the same: detect whether the model output preserves
the person, applies the garment, and avoids missing regions.

## Summary for Evaluation

The main mathematical concepts used in this project are:

- bounding boxes and confidence scores for YOLO detection
- binary masks and mask coverage for segmentation
- keypoint geometry for pose estimation
- UV body surface mapping for DensePose
- semantic pixel labels for human parsing
- flow-field sampling for PF-AFN cloth warping
- denoising equations for DCI-VTON diffusion
- mask blending and pixel-level quality checks for auditing

In simple terms, the system first understands the garment and person geometry,
then warps the garment to match the body, and finally uses diffusion to produce
a more realistic try-on image.
