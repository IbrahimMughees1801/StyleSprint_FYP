from __future__ import annotations

import os
import sys
import subprocess
from pathlib import Path


class GraphonomyInference:
    def __init__(self, repo_dir: str, requirements_path: str, python_executable: str | None = None) -> None:
        self.repo_dir = Path(repo_dir).resolve()
        self.requirements_path = Path(requirements_path).resolve()
        self.python_executable = Path(python_executable).resolve() if python_executable else Path(sys.executable)

    def run_inference(self, weights_path: str, image_path: str, output_dir: str, output_name: str):
        self.repo_dir.mkdir(parents=True, exist_ok=True)
        output_path = Path(output_dir).resolve()
        output_path.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        python_path = str(self.repo_dir)
        if env.get("PYTHONPATH"):
            python_path = python_path + os.pathsep + env["PYTHONPATH"]
        env["PYTHONPATH"] = python_path
        env_dir = self.python_executable.parent
        env_paths = [
            str(env_dir),
            str(env_dir / "Library" / "bin"),
            str(env_dir / "DLLs"),
            str(env_dir / "Scripts"),
            str(env_dir / "bin"),
        ]
        env["PATH"] = os.pathsep.join(env_paths + [env.get("PATH", "")])
        try:
            import torch
            check_command = [
                str(self.python_executable),
                "-c",
                "import torch; print('1' if torch.cuda.is_available() else '0')",
            ]
            cuda_check = subprocess.run(
                check_command,
                cwd=str(self.repo_dir),
                env=env,
                check=True,
                capture_output=True,
                text=True,
            )
            use_gpu = cuda_check.stdout.strip().splitlines()[-1]
        except Exception:
            use_gpu = "0"
        command = [
            str(self.python_executable),
            str(self.repo_dir / "exp" / "inference" / "inference.py"),
            "--loadmodel",
            str(Path(weights_path).resolve()),
            "--img_path",
            str(Path(image_path).resolve()),
            "--output_path",
            str(output_path),
            "--output_name",
            output_name,
            "--use_gpu",
            use_gpu,
        ]
        subprocess.run(command, cwd=str(self.repo_dir), env=env, check=True)
