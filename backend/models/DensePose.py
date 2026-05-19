from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path


class DensePoseRunner:
    def __init__(self, cfg_path: str, weights_path: str, image_path: str, output_dir: str) -> None:
        self.cfg_path = Path(cfg_path).resolve()
        self.weights_path = Path(weights_path).resolve()
        self.image_path = Path(image_path).resolve()
        self.output_dir = Path(output_dir).resolve()
        self.repo_root = Path(__file__).resolve().parents[1] / "third_party" / "detectron2"

    def run(self):
        self.output_dir.mkdir(parents=True, exist_ok=True)
        output_base = self.output_dir / self.image_path.name
        env = os.environ.copy()
        python_path = str(self.repo_root)
        if env.get("PYTHONPATH"):
            python_path = python_path + os.pathsep + env["PYTHONPATH"]
        env["PYTHONPATH"] = python_path
        command = [
            sys.executable,
            str(self.repo_root / "projects" / "DensePose" / "apply_net.py"),
            "show",
            str(self.cfg_path),
            str(self.weights_path),
            str(self.image_path),
            "dp_segm",
            "--output",
            str(output_base),
        ]
        # Ensure detectron2/DensePose runs on CPU when CUDA is unavailable
        # Override config option via CLI to avoid torch trying to initialize CUDA
        command.extend(["--opts", "MODEL.DEVICE", "cpu"])
        subprocess.run(command, cwd=str(self.repo_root), env=env, check=True)
