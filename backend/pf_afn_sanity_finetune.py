from __future__ import annotations

import argparse
import json
import math
import os
import random
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
        return original_grid_sample(
            input,
            grid,
            mode=mode,
            padding_mode=padding_mode,
            align_corners=align_corners,
        )

    F.grid_sample = grid_sample_legacy


def _load_rgb(path: Path, size: tuple[int, int]) -> torch.Tensor:
    image = Image.open(path).convert("RGB").resize(size, Image.BICUBIC)
    tensor = transforms.ToTensor()(image)
    tensor = transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))(tensor)
    return tensor


def _load_edge(path: Path, size: tuple[int, int]) -> torch.Tensor:
    image = Image.open(path).convert("L").resize(size, Image.NEAREST)
    tensor = transforms.ToTensor()(image)
    return (tensor > 0.5).float()


def _save_rgb(tensor: torch.Tensor, path: Path) -> None:
    array = tensor.detach().cpu().clamp(-1, 1)
    array = ((array + 1) / 2).permute(1, 2, 0).numpy()
    image = Image.fromarray((array * 255).astype(np.uint8))
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def _save_mask(tensor: torch.Tensor, path: Path) -> None:
    array = tensor.detach().cpu().clamp(0, 1).squeeze(0).numpy()
    image = Image.fromarray((array * 255).astype(np.uint8))
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def _load_checkpoint(model: torch.nn.Module, checkpoint_path: Path) -> None:
    checkpoint = torch.load(checkpoint_path, map_location="cpu")
    model_state = model.state_dict()
    for parameter_name in model_state:
        model_state[parameter_name] = checkpoint[parameter_name]
    model.load_state_dict(model_state)


def _paired_files(data_root: Path) -> list[tuple[Path, Path]]:
    clothes_dir = data_root / "test_clothes"
    edge_dir = data_root / "test_edge"
    pairs: list[tuple[Path, Path]] = []
    for cloth_path in sorted(clothes_dir.glob("*")):
        if not cloth_path.is_file():
            continue
        edge_path = edge_dir / cloth_path.name
        if edge_path.exists():
            pairs.append((cloth_path, edge_path))
    if not pairs:
        raise FileNotFoundError(f"No PF-AFN cloth/edge pairs found under {data_root}")
    return pairs


def _random_affine(batch_size: int, device: torch.device) -> torch.Tensor:
    matrices = []
    for _ in range(batch_size):
        angle = math.radians(random.uniform(-12.0, 12.0))
        scale_x = random.uniform(0.88, 1.10)
        scale_y = random.uniform(0.90, 1.14)
        shear = math.radians(random.uniform(-5.0, 5.0))
        tx = random.uniform(-0.12, 0.12)
        ty = random.uniform(-0.08, 0.10)

        cos_a = math.cos(angle)
        sin_a = math.sin(angle)
        shear_t = math.tan(shear)
        matrix = torch.tensor(
            [
                [scale_x * cos_a, -sin_a + shear_t, tx],
                [sin_a, scale_y * cos_a, ty],
            ],
            dtype=torch.float32,
            device=device,
        )
        matrices.append(matrix)
    return torch.stack(matrices, dim=0)


def _resolve_record_path(path_value: str, manifest_path: Path) -> Path:
    path = Path(path_value)
    if path.is_absolute():
        return path
    manifest_relative = manifest_path.parent / path
    if manifest_relative.exists():
        return manifest_relative
    return Path.cwd() / path


def _load_manifest(manifest_path: Path) -> list[dict[str, str]]:
    records: list[dict[str, str]] = []
    with manifest_path.open("r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            record = json.loads(line)
            required = ["person", "cloth", "edge", "target_cloth", "target_edge"]
            missing = [key for key in required if key not in record]
            if missing:
                raise ValueError(f"Manifest record missing keys {missing}: {record}")
            records.append(record)
    if not records:
        raise ValueError(f"No fine-tune samples found in {manifest_path}")
    return records


def _make_synthetic_batch(
    pairs: list[tuple[Path, Path]],
    size: tuple[int, int],
    batch_size: int,
    device: torch.device,
) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor, torch.Tensor, torch.Tensor]:
    sampled = random.choices(pairs, k=batch_size)
    clothes = []
    edges = []
    for cloth_path, edge_path in sampled:
        edge = _load_edge(edge_path, size)
        cloth = _load_rgb(cloth_path, size) * edge
        clothes.append(cloth)
        edges.append(edge)

    source_cloth = torch.stack(clothes, dim=0).to(device)
    source_edge = torch.stack(edges, dim=0).to(device)
    theta = _random_affine(batch_size, device)
    grid = F.affine_grid(theta, source_cloth.size(), align_corners=True)
    target_cloth = F.grid_sample(
        source_cloth,
        grid,
        mode="bilinear",
        padding_mode="zeros",
        align_corners=True,
    )
    target_edge = F.grid_sample(
        source_edge,
        grid,
        mode="bilinear",
        padding_mode="zeros",
        align_corners=True,
    ).clamp(0, 1)

    gray_background = torch.zeros_like(target_cloth)
    person_like = target_cloth * target_edge + gray_background * (1 - target_edge)
    return person_like, source_cloth, source_edge, target_cloth, target_edge


def _make_manifest_batch(
    records: list[dict[str, str]],
    manifest_path: Path,
    size: tuple[int, int],
    batch_size: int,
    device: torch.device,
) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor, torch.Tensor, torch.Tensor]:
    sampled = random.choices(records, k=batch_size)
    people = []
    clothes = []
    edges = []
    target_clothes = []
    target_edges = []
    for record in sampled:
        person = _load_rgb(_resolve_record_path(record["person"], manifest_path), size)
        edge = _load_edge(_resolve_record_path(record["edge"], manifest_path), size)
        cloth = _load_rgb(_resolve_record_path(record["cloth"], manifest_path), size) * edge
        target_edge = _load_edge(_resolve_record_path(record["target_edge"], manifest_path), size)
        target_cloth = _load_rgb(_resolve_record_path(record["target_cloth"], manifest_path), size)
        people.append(person)
        clothes.append(cloth)
        edges.append(edge)
        target_clothes.append(target_cloth)
        target_edges.append(target_edge)

    return (
        torch.stack(people, dim=0).to(device),
        torch.stack(clothes, dim=0).to(device),
        torch.stack(edges, dim=0).to(device),
        torch.stack(target_clothes, dim=0).to(device),
        torch.stack(target_edges, dim=0).to(device),
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run a small supervised PF-AFN warp fine-tune."
    )
    parser.add_argument("--repo-dir", required=True)
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--data-root")
    parser.add_argument("--manifest")
    parser.add_argument("--output", required=True)
    parser.add_argument("--steps", type=int, default=10)
    parser.add_argument("--batch-size", type=int, default=1)
    parser.add_argument("--lr", type=float, default=1e-6)
    parser.add_argument("--width", type=int, default=192)
    parser.add_argument("--height", type=int, default=256)
    parser.add_argument("--gpu-id", default="0")
    parser.add_argument("--seed", type=int, default=23)
    parser.add_argument(
        "--fixed-batch",
        action="store_true",
        help="Reuse one batch so loss movement is easy to judge.",
    )
    parser.add_argument(
        "--train-scope",
        choices=("all", "flow"),
        default="flow",
        help="Use 'flow' for a fast sanity update of AFWM flow/refine layers only.",
    )
    args = parser.parse_args()

    random.seed(args.seed)
    torch.manual_seed(args.seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(args.seed)

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
        *[path for path in sys.path if path and Path(path).resolve() != script_dir],
    ]
    sys.modules.pop("models", None)
    _use_legacy_grid_sample_alignment()

    from models.afwm import AFWM

    has_cuda = torch.cuda.is_available() and torch.cuda.device_count() > 0
    device = torch.device("cuda:0" if has_cuda and args.gpu_id != "-1" else "cpu")
    print(
        json.dumps(
            {
                "stage": "device",
                "device": str(device),
                "cuda_available": bool(torch.cuda.is_available()),
                "cuda_count": int(torch.cuda.device_count()),
            }
        ),
        flush=True,
    )
    size = (args.width, args.height)
    manifest_path = Path(args.manifest).resolve() if args.manifest else None
    records = _load_manifest(manifest_path) if manifest_path else None
    pairs = None if manifest_path else _paired_files(Path(args.data_root))
    print(
        json.dumps(
            {
                "stage": "data",
                "mode": "manifest" if manifest_path else "synthetic",
                "sample_count": len(records) if records is not None else len(pairs or []),
            }
        ),
        flush=True,
    )

    print(json.dumps({"stage": "model_init"}), flush=True)
    model = AFWM(SimpleNamespace(), 3).to(device)
    print(json.dumps({"stage": "load_checkpoint", "checkpoint": args.checkpoint}), flush=True)
    _load_checkpoint(model, Path(args.checkpoint))

    if args.train_scope == "flow":
        for name, parameter in model.named_parameters():
            parameter.requires_grad = name.startswith("aflow_net.")
        trainable_count = sum(parameter.numel() for parameter in model.parameters() if parameter.requires_grad)
        frozen_count = sum(parameter.numel() for parameter in model.parameters() if not parameter.requires_grad)
        print(
            json.dumps(
                {
                    "stage": "freeze",
                    "train_scope": args.train_scope,
                    "trainable_params": trainable_count,
                    "frozen_params": frozen_count,
                }
            ),
            flush=True,
        )
    model.train()

    optimizer = torch.optim.Adam(
        [parameter for parameter in model.parameters() if parameter.requires_grad],
        lr=args.lr,
    )
    history = []
    fixed_batch = None
    if args.fixed_batch:
        if records is not None and manifest_path is not None:
            fixed_batch = _make_manifest_batch(records, manifest_path, size, args.batch_size, device)
        elif pairs is not None:
            fixed_batch = _make_synthetic_batch(pairs, size, args.batch_size, device)

    for step in range(1, args.steps + 1):
        if fixed_batch is None:
            if records is not None and manifest_path is not None:
                person_like, source_cloth, source_edge, target_cloth, target_edge = _make_manifest_batch(
                    records,
                    manifest_path,
                    size,
                    args.batch_size,
                    device,
                )
            elif pairs is not None:
                person_like, source_cloth, source_edge, target_cloth, target_edge = _make_synthetic_batch(
                    pairs,
                    size,
                    args.batch_size,
                    device,
                )
            else:
                raise RuntimeError("No training data configured")
        else:
            person_like, source_cloth, source_edge, target_cloth, target_edge = fixed_batch
        optimizer.zero_grad(set_to_none=True)
        warped_cloth, last_flow = model(person_like, source_cloth)
        warped_edge = F.grid_sample(
            source_edge,
            last_flow.permute(0, 2, 3, 1),
            mode="bilinear",
            padding_mode="zeros",
            align_corners=True,
        ).clamp(0, 1)

        mask = (target_edge > 0.05).float()
        cloth_loss = F.l1_loss(warped_cloth * mask, target_cloth * mask)
        edge_loss = F.l1_loss(warped_edge, target_edge)
        loss = cloth_loss + 2.0 * edge_loss
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        optimizer.step()

        row = {
            "step": step,
            "loss": float(loss.detach().cpu()),
            "cloth_loss": float(cloth_loss.detach().cpu()),
            "edge_loss": float(edge_loss.detach().cpu()),
        }
        history.append(row)
        print(json.dumps(row), flush=True)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    torch.save(model.state_dict(), output_path)

    model.eval()
    with torch.no_grad():
        if records is not None and manifest_path is not None:
            person_like, source_cloth, source_edge, target_cloth, target_edge = _make_manifest_batch(
                records,
                manifest_path,
                size,
                1,
                device,
            )
        elif pairs is not None:
            person_like, source_cloth, source_edge, target_cloth, target_edge = _make_synthetic_batch(
                pairs,
                size,
                1,
                device,
            )
        else:
            raise RuntimeError("No training data configured")
        warped_cloth, last_flow = model(person_like, source_cloth)
        warped_edge = F.grid_sample(
            source_edge,
            last_flow.permute(0, 2, 3, 1),
            mode="bilinear",
            padding_mode="zeros",
            align_corners=True,
        )

    sample_dir = output_path.parent / "samples"
    _save_rgb(person_like[0], sample_dir / "person.jpg")
    _save_rgb(source_cloth[0], sample_dir / "source_cloth.jpg")
    _save_rgb(target_cloth[0], sample_dir / "target_cloth.jpg")
    _save_rgb(warped_cloth[0], sample_dir / "warped_cloth.jpg")
    _save_mask(target_edge[0], sample_dir / "target_edge.png")
    _save_mask(warped_edge[0], sample_dir / "warped_edge.png")

    history_path = output_path.with_suffix(".json")
    history_path.write_text(json.dumps({"device": str(device), "steps": history}, indent=2))
    print(f"saved_checkpoint={output_path}", flush=True)
    print(f"saved_history={history_path}", flush=True)
    print(f"saved_samples={sample_dir}", flush=True)


if __name__ == "__main__":
    main()
