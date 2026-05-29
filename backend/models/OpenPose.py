from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


class OpenPoseRunner:
    def __init__(self, openpose_root: str, image_path: str, output_dir: str, json_dir: str) -> None:
        self.openpose_root = Path(openpose_root).resolve()
        self.image_path = Path(image_path).resolve()
        self.output_dir = Path(output_dir).resolve()
        self.json_dir = Path(json_dir).resolve()

    def run(self):
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.json_dir.mkdir(parents=True, exist_ok=True)
        single_input_dir = self.output_dir / f"_{self.image_path.stem}_input"
        single_input_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(self.image_path, single_input_dir / self.image_path.name)
        openpose_demo = self.openpose_root / "bin" / "OpenPoseDemo.exe"
        if openpose_demo.exists():
            command = [
                str(openpose_demo),
                "--image_dir",
                str(single_input_dir),
                "--write_images",
                str(self.output_dir),
                "--write_json",
                str(self.json_dir),
                "--display",
                "0",
                "--model_folder",
                str(self.openpose_root / "models"),
            ]
            subprocess.run(command, cwd=str(openpose_demo.parent), check=True)
            return

        python_script = self.openpose_root / "python" / "openpose_python.py"
        command = [
            sys.executable,
            str(python_script),
            "--image_dir",
            str(single_input_dir),
            "--write_images",
            str(self.output_dir),
            "--write_json",
            str(self.json_dir),
            "--display",
            "0",
            "--model_folder",
            str(self.openpose_root / "models"),
        ]
        subprocess.run(command, cwd=str(self.openpose_root / "python"), check=True)
