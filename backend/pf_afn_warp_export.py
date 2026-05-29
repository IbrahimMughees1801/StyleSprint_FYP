from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from types import SimpleNamespace

import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image
from torchvision import transforms


def _use_legacy_grid_sample_alignment() -> None:
    original_grid_sample = F.grid_sample

    def grid_sample_legacy(input, grid, mode="bilinear", padding_mode="zeros", align_corners=None):
        if align_corners is None:
            align_corners = True
        return original_grid_sample(input, grid, mode=mode, padding_mode=padding_mode, align_corners=align_corners)

    F.grid_sample = grid_sample_legacy


def _load_rgb(path: Path, size: tuple[int, int]) -> torch.Tensor:
    image = Image.open(path).convert("RGB").resize(size, Image.BICUBIC)
    tensor = transforms.ToTensor()(image)
    tensor = transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))(tensor)
    return tensor.unsqueeze(0)


def _load_edge(path: Path, size: tuple[int, int]) -> torch.Tensor:
    image = Image.open(path).convert("L").resize(size, Image.NEAREST)
    tensor = transforms.ToTensor()(image)
    return (tensor > 0.5).float().unsqueeze(0)


def _save_rgb(tensor: torch.Tensor, path: Path) -> None:
    array = tensor.squeeze(0).detach().cpu().clamp(-1, 1)
    array = ((array + 1) / 2).permute(1, 2, 0).numpy()
    image = Image.fromarray((array * 255).astype(np.uint8))
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def _save_mask(tensor: torch.Tensor, path: Path) -> None:
    array = tensor.squeeze(0).squeeze(0).detach().cpu().clamp(0, 1).numpy()
    image = Image.fromarray((array * 255).astype(np.uint8))
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-dir", required=True)
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--person", required=True)
    parser.add_argument("--cloth", required=True)
    parser.add_argument("--edge", required=True)
    parser.add_argument("--output-cloth", required=True)
    parser.add_argument("--output-mask", required=True)
    parser.add_argument("--width", type=int, default=192)
    parser.add_argument("--height", type=int, default=256)
    parser.add_argument("--gpu-id", default="0")
    args = parser.parse_args()

    env_root = Path(sys.executable).resolve().parent
    env_bin = env_root / "bin"
    if env_bin.exists():
        os.environ["PATH"] = str(env_bin) + os.pathsep + os.environ.get("PATH", "")
        if hasattr(os, "add_dll_directory"):
            os.add_dll_directory(str(env_bin))

    repo_dir = Path(args.repo_dir).resolve()
    script_dir = Path(__file__).resolve().parent
    sys.path = [
        str(repo_dir),
        *[
            path
            for path in sys.path
            if path and Path(path).resolve() != script_dir
        ],
    ]
    sys.modules.pop("models", None)
    _use_legacy_grid_sample_alignment()

    from models.afwm import AFWM
    def load_warp_checkpoint(model: torch.nn.Module, checkpoint_path: Path) -> None:
        if not checkpoint_path.exists():
            raise FileNotFoundError(f"No checkpoint found at {checkpoint_path}")

        checkpoint = torch.load(checkpoint_path, map_location="cpu")
        model_state = model.state_dict()
        for parameter_name in model_state:
            model_state[parameter_name] = checkpoint[parameter_name]
        model.load_state_dict(model_state)

    has_cuda_device = torch.cuda.is_available() and torch.cuda.device_count() > 0
    print(
        "PF-AFN device check: "
        f"CUDA_VISIBLE_DEVICES={os.environ.get('CUDA_VISIBLE_DEVICES')!r}, "
        f"cuda_available={torch.cuda.is_available()}, "
        f"device_count={torch.cuda.device_count()}",
        file=sys.stderr,
    )
    device = torch.device("cuda:0" if has_cuda_device and args.gpu_id != "-1" else "cpu")
    size = (args.width, args.height)

    person = _load_rgb(Path(args.person), size).to(device)
    cloth = _load_rgb(Path(args.cloth), size).to(device)
    edge = _load_edge(Path(args.edge), size).to(device)
    cloth = cloth * edge

    opt = SimpleNamespace()
    model = AFWM(opt, 3)
    model.eval()
    load_warp_checkpoint(model, Path(args.checkpoint))
    model.to(device)

    with torch.no_grad():
        warped_cloth, last_flow = model(person, cloth)
        warped_edge = F.grid_sample(
            edge,
            last_flow.permute(0, 2, 3, 1),
            mode="bilinear",
            padding_mode="zeros",
            align_corners=True,
        )

    _save_rgb(warped_cloth, Path(args.output_cloth))
    _save_mask(warped_edge, Path(args.output_mask))


if __name__ == "__main__":
    main()
