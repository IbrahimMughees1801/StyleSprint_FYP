from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np
from PIL import Image


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
    parse_image = Image.open(parse_path).convert("RGB")
    source = source.resize(parse_image.size)
    source.save(agnostic_dir / parse_name)


def get_im_parse_agnostic(im_parse, pose_data):
    parse_image = im_parse.convert("L")
    array = np.array(parse_image)
    agnostic = np.where(array > 0, 255, 0).astype(np.uint8)
    return Image.fromarray(agnostic)
