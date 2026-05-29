from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw


def process_image(person_image_path: str, openpose_json_dir: str, parse_output_dir: str, agnostic_save_dir: str):
    person_path = Path(person_image_path)
    parse_output = Path(parse_output_dir)
    agnostic_dir = Path(agnostic_save_dir)
    parse_name = person_path.stem + ".png"
    parse_path = parse_output / parse_name
    if not parse_path.exists():
        raise FileNotFoundError(f"Parse image not found: {parse_path}")

    agnostic_dir.mkdir(parents=True, exist_ok=True)
    source = Image.open(person_path).convert("RGB")
    labels = np.array(Image.open(parse_path).convert("L"))
    source = source.resize((labels.shape[1], labels.shape[0]), Image.Resampling.BICUBIC)

    remove_mask = np.isin(labels, [5, 6, 7])
    upper_mask = remove_mask.copy()
    if upper_mask.any():
        ys, xs = np.where(upper_mask)
        y1, y2 = int(ys.min()), int(ys.max())
        x1, x2 = int(xs.min()), int(xs.max())
        height = y2 - y1 + 1
        width = x2 - x1 + 1
        yy = np.arange(labels.shape[0])[:, None]
        sleeve_band = (yy >= y1 - int(height * 0.12)) & (yy <= y1 + int(height * 1.12))
        remove_mask |= np.isin(labels, [14, 15]) & sleeve_band
        x_pad = max(12, int(width * 0.12))
        y_top = max(0, y1 - int(height * 0.10))
        y_bottom = min(labels.shape[0], y2 + int(height * 0.28))
        x_left = max(0, x1 - x_pad)
        x_right = min(labels.shape[1], x2 + x_pad)
        remove_mask[y_top:y_bottom, x_left:x_right] |= upper_mask[y_top:y_bottom, x_left:x_right]

    pose_path = Path(openpose_json_dir) / f"{person_path.stem}_keypoints.json"
    if pose_path.exists():
        try:
            with pose_path.open("r", encoding="utf-8") as handle:
                pose_label = json.load(handle)
            people = pose_label.get("people", [])
            if people:
                keypoints = np.array(people[0].get("pose_keypoints_2d", []), dtype=np.float32).reshape((-1, 3))
                height, width = labels.shape

                def valid(index: int, min_conf: float = 0.03) -> bool:
                    return index < len(keypoints) and keypoints[index, 2] > min_conf

                def point(index: int, fallback: tuple[float, float] | None = None):
                    if valid(index):
                        return float(keypoints[index, 0]), float(keypoints[index, 1])
                    return fallback

                right_shoulder = point(2, (width * 0.38, height * 0.32))
                left_shoulder = point(5, (width * 0.62, height * 0.32))
                right_hip = point(9, (width * 0.42, height * 0.67))
                left_hip = point(12, (width * 0.58, height * 0.67))
                right_elbow = point(3)
                right_wrist = point(4)
                left_elbow = point(6)
                left_wrist = point(7)
                shoulder_span = (
                    abs(left_shoulder[0] - right_shoulder[0])
                    if left_shoulder and right_shoulder
                    else width * 0.25
                )

                pose_canvas = Image.new("L", (width, height), 0)
                draw = ImageDraw.Draw(pose_canvas)
                if all([right_shoulder, left_shoulder, right_hip, left_hip]):
                    pad = max(12, shoulder_span * 0.22)
                    draw.polygon(
                        [
                            (right_shoulder[0] - pad, right_shoulder[1] - pad * 0.75),
                            (left_shoulder[0] + pad, left_shoulder[1] - pad * 0.75),
                            (left_hip[0] + pad * 0.75, left_hip[1] + pad * 1.45),
                            (right_hip[0] - pad * 0.75, right_hip[1] + pad * 1.45),
                        ],
                        fill=255,
                    )

                arm_width = max(22, int(shoulder_span * 0.28))

                def draw_limb(points: list[tuple[float, float] | None]) -> None:
                    valid_points = [p for p in points if p is not None]
                    if len(valid_points) >= 2:
                        draw.line(valid_points, fill=255, width=arm_width, joint="curve")
                        radius = max(12, arm_width // 2)
                        for x, y in valid_points:
                            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=255)

                draw_limb([left_shoulder, left_elbow, left_wrist])
                draw_limb([right_shoulder, right_elbow, right_wrist])
                remove_mask |= np.array(pose_canvas) > 0
        except Exception:
            pass

    if remove_mask.any():
        close_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11))
        dilate_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (17, 17))
        remove_mask = cv2.morphologyEx(remove_mask.astype(np.uint8), cv2.MORPH_CLOSE, close_kernel)
        remove_mask = cv2.dilate(remove_mask, dilate_kernel, iterations=1).astype(bool)

    image = np.array(source)
    neutral = np.full_like(image, 128)
    agnostic = np.where(remove_mask[:, :, None], neutral, image)
    Image.fromarray(agnostic.astype(np.uint8), mode="RGB").save(agnostic_dir / parse_name)


def get_im_parse_agnostic(im_parse, pose_data):
    parse_image = im_parse.convert("L")
    array = np.array(parse_image)
    agnostic = array.copy()
    upper = np.isin(agnostic, [5, 6, 7])
    agnostic[upper] = 0
    if upper.any():
        ys, _ = np.where(upper)
        y1, y2 = int(ys.min()), int(ys.max())
        height = y2 - y1 + 1
        yy = np.arange(agnostic.shape[0])[:, None]
        sleeve_band = (yy >= y1 - int(height * 0.12)) & (yy <= y1 + int(height * 1.12))
        agnostic[np.isin(agnostic, [14, 15]) & sleeve_band] = 0
    agnostic[agnostic > 19] = 0
    agnostic = agnostic.astype(np.uint8)
    return Image.fromarray(agnostic)


def parse_unique_labels(parse_path: str | Path) -> list[int]:
    image = Image.open(parse_path).convert("L")
    labels = np.array(image)
    return sorted(int(value) for value in np.unique(labels) if int(value) <= 19)


def parse_is_collapsed(parse_path: str | Path, min_labels: int = 3) -> bool:
    return len(parse_unique_labels(parse_path)) < min_labels


def refine_human_parse(
    person_image_path: str | Path,
    parse_path: str | Path,
    pose_json_path: str | Path | None = None,
    densepose_image_path: str | Path | None = None,
) -> bool:
    parse_file = Path(parse_path)
    if not parse_file.exists():
        return False

    labels = np.array(Image.open(parse_file).convert("L"))
    height, width = labels.shape
    refined = np.where(labels <= 19, labels, 0).astype(np.uint8)
    changed = False

    # Keep upper-clothes labels consistent for downstream DCI/PF-AFN expectations.
    upper = np.isin(refined, [5, 6, 7]).astype(np.uint8)
    if upper.any():
        close_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9))
        cleaned_upper = cv2.morphologyEx(upper, cv2.MORPH_CLOSE, close_kernel)
        count, cc_labels, stats, _ = cv2.connectedComponentsWithStats(cleaned_upper, 8)
        if count > 1:
            largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
            cleaned_upper = (cc_labels == largest).astype(np.uint8)
        changed = bool(changed or not np.array_equal(cleaned_upper > 0, upper > 0))
        refined[np.isin(refined, [5, 6, 7])] = 0
        refined[cleaned_upper > 0] = 5

    if pose_json_path and Path(pose_json_path).exists():
        with open(pose_json_path, "r", encoding="utf-8") as f:
            pose_label = json.load(f)
    else:
        pose_label = {"people": []}

    people = pose_label.get("people", [])
    keypoints = None
    if people:
        raw = people[0].get("pose_keypoints_2d", [])
        if len(raw) >= 39:
            keypoints = np.array(raw, dtype=np.float32).reshape((-1, 3))

    def valid(index: int, min_conf: float = 0.03) -> bool:
        return keypoints is not None and index < len(keypoints) and keypoints[index, 2] > min_conf

    def point(index: int, fallback: tuple[float, float] | None = None):
        if valid(index):
            return float(keypoints[index, 0]), float(keypoints[index, 1])
        return fallback

    if keypoints is not None:
        nose = point(0, (width * 0.5, height * 0.16))
        neck = point(1, (width * 0.5, height * 0.30))
        right_shoulder = point(2, (width * 0.38, height * 0.34))
        right_elbow = point(3)
        right_wrist = point(4)
        left_shoulder = point(5, (width * 0.62, height * 0.34))
        left_elbow = point(6)
        left_wrist = point(7)
        right_hip = point(9, (width * 0.42, height * 0.72))
        left_hip = point(12, (width * 0.58, height * 0.72))

        shoulder_span = max(40.0, abs(left_shoulder[0] - right_shoulder[0])) if left_shoulder and right_shoulder else width * 0.25

        if all([right_shoulder, left_shoulder, right_hip, left_hip]):
            torso_canvas = Image.new("L", (width, height), 0)
            draw = ImageDraw.Draw(torso_canvas)
            shoulder_pad = shoulder_span * 0.12
            hip_pad = shoulder_span * 0.08
            torso_poly = [
                (right_shoulder[0] - shoulder_pad, right_shoulder[1] - shoulder_span * 0.10),
                (left_shoulder[0] + shoulder_pad, left_shoulder[1] - shoulder_span * 0.10),
                (left_hip[0] + hip_pad, left_hip[1] + shoulder_span * 0.16),
                (right_hip[0] - hip_pad, right_hip[1] + shoulder_span * 0.16),
            ]
            draw.polygon(torso_poly, fill=255)
            torso_mask = np.array(torso_canvas) > 0
            upper_current = refined == 5
            # Fill only when Graphonomy already agrees with most of the pose torso.
            overlap = float((upper_current & torso_mask).sum() / max(1, torso_mask.sum()))
            if overlap >= 0.28 or upper_current.mean() < 0.12:
                fill_mask = torso_mask & ~np.isin(refined, [1, 2, 4, 13, 14, 15])
                before = refined.copy()
                refined[fill_mask] = 5
                changed = bool(changed or not np.array_equal(before, refined))

        arm_width = max(16, int(shoulder_span * 0.18))
        arm_canvas = Image.new("L", (width, height), 0)
        arm_draw = ImageDraw.Draw(arm_canvas)

        def draw_arm(points, label):
            valid_points = [p for p in points if p is not None]
            if len(valid_points) < 2:
                return
            arm_draw.line(valid_points, fill=label, width=arm_width, joint="curve")
            radius = max(8, arm_width // 2)
            for x, y in valid_points:
                arm_draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=label)

        draw_arm([left_shoulder, left_elbow, left_wrist], 14)
        draw_arm([right_shoulder, right_elbow, right_wrist], 15)
        arm_hint = np.array(arm_canvas)
        before_arms = refined.copy()
        refined[(arm_hint == 14) & (refined == 0)] = 14
        refined[(arm_hint == 15) & (refined == 0)] = 15
        changed = bool(changed or not np.array_equal(before_arms, refined))

        if nose and neck:
            head_canvas = Image.new("L", (width, height), 0)
            head_draw = ImageDraw.Draw(head_canvas)
            head_width = max(34, int(shoulder_span * 0.44))
            head_height = max(46, int(shoulder_span * 0.58))
            cx = (nose[0] + neck[0]) / 2
            cy = (nose[1] + neck[1]) / 2
            head_draw.ellipse(
                (cx - head_width / 2, cy - head_height / 2, cx + head_width / 2, cy + head_height / 2),
                fill=255,
            )
            head_mask = np.array(head_canvas) > 0
            before_head = refined.copy()
            refined[head_mask & (refined == 0)] = 4
            changed = bool(changed or not np.array_equal(before_head, refined))

    if (
        densepose_image_path
        and Path(densepose_image_path).exists()
        and str(__import__("os").environ.get("API_GRAPHONOMY_DENSEPOSE_CLIP", "false")).strip().lower()
        in {"1", "true", "yes"}
    ):
        densepose = Image.open(densepose_image_path).convert("RGB").resize((width, height), Image.Resampling.BILINEAR)
        hsv = cv2.cvtColor(np.array(densepose), cv2.COLOR_RGB2HSV)
        saturation = hsv[:, :, 1]
        value = hsv[:, :, 2]
        body_hint = (saturation > 55) & (value > 70)
        body_hint = cv2.morphologyEx(
            body_hint.astype(np.uint8),
            cv2.MORPH_CLOSE,
            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)),
        ).astype(bool)
        before_body = refined.copy()
        refined[(refined == 5) & ~cv2.dilate(body_hint.astype(np.uint8), np.ones((9, 9), np.uint8), iterations=1).astype(bool)] = 0
        changed = bool(changed or not np.array_equal(before_body, refined))

    if changed:
        Image.fromarray(refined.astype(np.uint8), mode="L").save(parse_file)
    return changed


def create_pose_fallback_parse(
    person_image_path: str,
    pose_json_path: str,
    output_path: str,
    densepose_image_path: str | Path | None = None,
) -> bool:
    person = Image.open(person_image_path).convert("RGB")
    width, height = person.size
    canvas = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(canvas)

    with open(pose_json_path, "r", encoding="utf-8") as f:
        pose_label = json.load(f)

    people = pose_label.get("people", [])
    if not people:
        return False

    raw = people[0].get("pose_keypoints_2d", [])
    if len(raw) < 3:
        return False

    keypoints = np.array(raw, dtype=np.float32).reshape((-1, 3))

    def valid(index: int, min_conf: float = 0.03) -> bool:
        return index < len(keypoints) and keypoints[index, 2] > min_conf

    def point(index: int, fallback: tuple[float, float] | None = None, min_conf: float = 0.03):
        if valid(index, min_conf):
            return float(keypoints[index, 0]), float(keypoints[index, 1])
        return fallback

    nose = point(0, (width * 0.5, height * 0.16))
    neck = point(1, (width * 0.5, height * 0.30))
    right_shoulder = point(2, (width * 0.38, height * 0.34))
    right_elbow = point(3, (width * 0.32, height * 0.50))
    right_wrist = point(4, (width * 0.30, height * 0.65))
    left_shoulder = point(5, (width * 0.62, height * 0.34))
    left_elbow = point(6, (width * 0.68, height * 0.50))
    left_wrist = point(7, (width * 0.70, height * 0.65))
    right_hip = point(9, (width * 0.42, height * 0.74))
    left_hip = point(12, (width * 0.58, height * 0.74))
    actual_right_elbow = point(3)
    actual_right_wrist = point(4)
    actual_left_elbow = point(6)
    actual_left_wrist = point(7)

    torso = [right_shoulder, left_shoulder, left_hip, right_hip]
    if all(torso):
        draw.polygon(torso, fill=5)

    shoulder_span = abs(left_shoulder[0] - right_shoulder[0]) if left_shoulder and right_shoulder else width * 0.25
    arm_width = max(18, int(shoulder_span * 0.22))
    joint_radius = max(10, arm_width // 2)

    if left_hip and right_hip:
        lower_y = min(height - 1, max(left_hip[1], right_hip[1]) + height * 0.18)
        draw.polygon([right_hip, left_hip, (left_hip[0], lower_y), (right_hip[0], lower_y)], fill=9)

    def draw_limb(points, label):
        valid = [p for p in points if p]
        if len(valid) < 2:
            return
        draw.line(valid, fill=label, width=arm_width, joint="curve")
        for x, y in valid:
            draw.ellipse((x - joint_radius, y - joint_radius, x + joint_radius, y + joint_radius), fill=label)

    def draw_reliable_arm(shoulder, elbow, wrist, label):
        if wrist:
            draw_limb([shoulder, elbow, wrist], label)
        elif elbow and elbow[1] < shoulder[1] + shoulder_span * 0.75:
            draw_limb([shoulder, elbow], label)

    draw_reliable_arm(left_shoulder, actual_left_elbow, actual_left_wrist, 14)
    draw_reliable_arm(right_shoulder, actual_right_elbow, actual_right_wrist, 15)

    def add_visible_arm_occlusion_labels() -> None:
        if not (left_shoulder and right_shoulder and neck):
            return

        shoulder_y = max(left_shoulder[1], right_shoulder[1])
        hip_y = max(left_hip[1], right_hip[1]) if left_hip and right_hip else shoulder_y + shoulder_span * 1.7
        missing_wrists = not valid(4, 0.05) or not valid(7, 0.05)
        low_elbows = (
            (valid(3, 0.05) and keypoints[3, 1] > shoulder_y + shoulder_span * 0.7)
            or (valid(6, 0.05) and keypoints[6, 1] > shoulder_y + shoulder_span * 0.7)
        )
        if not (missing_wrists or low_elbows):
            return

        rgb = np.array(person)
        ycrcb = cv2.cvtColor(rgb, cv2.COLOR_RGB2YCrCb)
        y_channel, cr_channel, cb_channel = cv2.split(ycrcb)
        hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
        hue_channel, saturation_channel, value_channel = cv2.split(hsv)
        skin = (
            (y_channel > 45)
            & (cr_channel >= 132)
            & (cr_channel <= 180)
            & (cb_channel >= 75)
            & (cb_channel <= 140)
            & (hue_channel <= 25)
            & (saturation_channel >= 20)
            & (saturation_channel <= 150)
            & (value_channel >= 70)
        ).astype(np.uint8)

        roi = np.zeros((height, width), dtype=np.uint8)
        x_min = max(0, int(min(right_shoulder[0], left_shoulder[0]) - shoulder_span * 0.75))
        x_max = min(width, int(max(right_shoulder[0], left_shoulder[0]) + shoulder_span * 0.75))
        y_min = max(0, int(shoulder_y + shoulder_span * 0.35))
        y_max = min(height, int(hip_y + shoulder_span * 0.55))
        roi[y_min:y_max, x_min:x_max] = 1
        skin &= roi

        if not skin.any():
            return

        close_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
        skin = cv2.morphologyEx(skin, cv2.MORPH_CLOSE, close_kernel)
        dilate_size = max(11, int(arm_width * 0.45))
        if dilate_size % 2 == 0:
            dilate_size += 1
        dilate_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (dilate_size, dilate_size))
        skin = cv2.dilate(skin, dilate_kernel, iterations=1)

        count, labels, stats, centroids = cv2.connectedComponentsWithStats(skin, 8)
        canvas_array = np.array(canvas)
        min_area = max(180, int(width * height * 0.00055))
        mid_x = (right_shoulder[0] + left_shoulder[0]) / 2

        for component in range(1, count):
            area = int(stats[component, cv2.CC_STAT_AREA])
            if area < min_area:
                continue
            comp_x = int(stats[component, cv2.CC_STAT_LEFT])
            comp_y = int(stats[component, cv2.CC_STAT_TOP])
            comp_w = int(stats[component, cv2.CC_STAT_WIDTH])
            comp_h = int(stats[component, cv2.CC_STAT_HEIGHT])
            if comp_y < y_min - arm_width or comp_w < arm_width or comp_h < joint_radius:
                continue

            component_mask = labels == component
            label = 15 if centroids[component][0] < mid_x else 14
            canvas_array[component_mask] = label

        updated = Image.fromarray(canvas_array.astype(np.uint8), mode="L")
        canvas.paste(updated)

    if nose and neck:
        head_width = max(34, int(shoulder_span * 0.42))
        head_height = max(46, int(shoulder_span * 0.55))
        cx = (nose[0] + neck[0]) / 2
        cy = (nose[1] + neck[1]) / 2
        draw.ellipse(
            (cx - head_width / 2, cy - head_height / 2, cx + head_width / 2, cy + head_height / 2),
            fill=4,
        )

    def apply_densepose_guidance() -> None:
        if not densepose_image_path:
            return

        densepose_path = Path(densepose_image_path)
        if not densepose_path.exists():
            return

        densepose = Image.open(densepose_path).convert("RGB").resize((width, height), Image.Resampling.BILINEAR)
        rgb = np.array(densepose)
        hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
        hue, saturation, value = cv2.split(hsv)

        colored = (saturation > 55) & (value > 70)
        if not colored.any():
            return

        close_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11))
        colored = cv2.morphologyEx(colored.astype(np.uint8), cv2.MORPH_CLOSE, close_kernel)
        count, dense_labels, dense_stats, _ = cv2.connectedComponentsWithStats(colored.astype(np.uint8), 8)
        if count <= 1:
            return
        largest = 1 + int(np.argmax(dense_stats[1:, cv2.CC_STAT_AREA]))
        colored = dense_labels == largest
        colored_coverage = float(colored.mean())
        if not 0.06 <= colored_coverage <= 0.42:
            return

        canvas_array = np.array(canvas)
        mid_x = (right_shoulder[0] + left_shoulder[0]) / 2 if right_shoulder and left_shoulder else width * 0.5
        shoulder_y = min(right_shoulder[1], left_shoulder[1]) if right_shoulder and left_shoulder else height * 0.34
        hip_y = max(left_hip[1], right_hip[1]) if left_hip and right_hip else height * 0.72
        neck_x, neck_y = neck if neck else (mid_x, shoulder_y)

        yy, xx = np.indices((height, width))

        # OpenCV hue: blue around 100-130, green around 35-85, yellow around 20-35.
        blue = colored & (hue >= 85) & (hue <= 135)
        green = colored & (hue >= 35) & (hue < 85)
        yellow = colored & (hue >= 18) & (hue < 35)

        torso_region = (yy >= shoulder_y - shoulder_span * 0.25) & (yy <= hip_y + shoulder_span * 0.55)
        head_region = (
            (yy < neck_y + shoulder_span * 0.35)
            & (np.abs(xx - neck_x) < shoulder_span * 0.75)
        )
        blank = canvas_array == 0
        upper_or_blank = (canvas_array == 5) | blank
        head_or_blank = (canvas_array == 4) | blank
        arm_or_blank = np.isin(canvas_array, [14, 15]) | blank

        canvas_array[blue & torso_region & upper_or_blank] = 5
        canvas_array[yellow & head_region & head_or_blank] = 4

        arm_candidates = (green | (yellow & torso_region & ~head_region)) & torso_region
        left_arm = arm_candidates & (xx >= mid_x)
        right_arm = arm_candidates & (xx < mid_x)
        canvas_array[left_arm & arm_or_blank] = 14
        canvas_array[right_arm & arm_or_blank] = 15

        canvas.paste(Image.fromarray(canvas_array.astype(np.uint8), mode="L"))

    apply_densepose_guidance()
    add_visible_arm_occlusion_labels()

    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)
    return not parse_is_collapsed(output)


def sanitize_openpose_json(pose_json_path: str | Path, image_size: tuple[int, int]) -> bool:
    pose_path = Path(pose_json_path)
    if not pose_path.exists():
        return False

    with open(pose_path, "r", encoding="utf-8") as f:
        pose_label = json.load(f)

    people = pose_label.get("people", [])
    if not people:
        return False

    width, height = image_size

    def person_score(person: dict) -> float:
        raw_points = person.get("pose_keypoints_2d", [])
        if len(raw_points) < 3:
            return -1.0
        points = np.array(raw_points, dtype=np.float32).reshape((-1, 3))
        confident = points[:, 2] > 0.05
        if not confident.any():
            return -1.0
        visible = points[confident]
        x1, y1 = visible[:, 0].min(), visible[:, 1].min()
        x2, y2 = visible[:, 0].max(), visible[:, 1].max()
        area_ratio = ((x2 - x1) * (y2 - y1)) / max(1.0, float(width * height))
        center_x = (x1 + x2) / 2
        center_y = (y1 + y2) / 2
        center_distance = abs(center_x - width * 0.5) / max(1, width) + abs(center_y - height * 0.48) / max(1, height)
        core_bonus = sum(
            1
            for index in [1, 2, 5, 9, 12]
            if index < len(points) and points[index, 2] > 0.05
        )
        return float(confident.sum()) + core_bonus * 1.5 + area_ratio * 12 - center_distance * 4

    best_index = max(range(len(people)), key=lambda index: person_score(people[index]))
    changed = False
    if best_index != 0 or len(people) > 1:
        people = [people[best_index]]
        pose_label["people"] = people
        changed = True

    raw = people[0].get("pose_keypoints_2d", [])
    if len(raw) < 39:
        return False

    keypoints = np.array(raw, dtype=np.float32).reshape((-1, 3))

    def valid(index: int, min_conf: float = 0.03) -> bool:
        return index < len(keypoints) and keypoints[index, 2] > min_conf

    if valid(2) and valid(5):
        right_shoulder = keypoints[2, :2]
        left_shoulder = keypoints[5, :2]
        shoulder_span = max(40.0, float(abs(left_shoulder[0] - right_shoulder[0])))
        hip_y = min(height - 1.0, max(right_shoulder[1], left_shoulder[1]) + shoulder_span * 0.82)
        right_hip = np.array([right_shoulder[0] + shoulder_span * 0.10, hip_y], dtype=np.float32)
        left_hip = np.array([left_shoulder[0] - shoulder_span * 0.10, hip_y], dtype=np.float32)
    else:
        right_hip = np.array([width * 0.42, height * 0.72], dtype=np.float32)
        left_hip = np.array([width * 0.58, height * 0.72], dtype=np.float32)

    for index, point_value in [(9, right_hip), (12, left_hip)]:
        if index < len(keypoints) and not valid(index):
            keypoints[index, 0] = point_value[0]
            keypoints[index, 1] = point_value[1]
            keypoints[index, 2] = 0.35
            changed = True

    if 8 < len(keypoints) and not valid(8):
        keypoints[8, 0] = (keypoints[9, 0] + keypoints[12, 0]) / 2
        keypoints[8, 1] = (keypoints[9, 1] + keypoints[12, 1]) / 2
        keypoints[8, 2] = 0.35
        changed = True

    if changed:
        people[0]["pose_keypoints_2d"] = keypoints.reshape(-1).tolist()
        with open(pose_path, "w", encoding="utf-8") as f:
            json.dump(pose_label, f)

    return changed
