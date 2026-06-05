from __future__ import annotations

import argparse
import json
import os
import random
import shutil
import subprocess
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
PROJECT_DIR = BASE_DIR.parent


def _pair_rows(path: Path) -> list[str]:
    rows: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        parts = line.strip().split()
        if parts:
            rows.append(parts[0])
    return rows


def _required_paths(root: Path, split: str, name: str) -> dict[str, Path]:
    stem = Path(name).stem
    return {
        "image": root / split / "image" / name,
        "cloth": root / split / "cloth" / name,
        "cloth-mask": root / split / "cloth-mask" / name,
        "image-parse-v3": root / split / "image-parse-v3" / f"{stem}.png",
        "openpose_json": root / split / "openpose_json" / f"{stem}_keypoints.json",
    }


def _copy_sample(src_root: Path, dst_root: Path, src_split: str, dst_split: str, name: str) -> None:
    paths = _required_paths(src_root, src_split, name)
    stem = Path(name).stem
    copy_targets = {
        "image": dst_root / dst_split / "image" / name,
        "cloth": dst_root / dst_split / "cloth" / name,
        "cloth-mask": dst_root / dst_split / "cloth-mask" / name,
        "image-parse-v3": dst_root / dst_split / "image-parse-v3" / f"{stem}.png",
        "openpose_json": dst_root / dst_split / "openpose_json" / f"{stem}_keypoints.json",
    }
    for key, src in paths.items():
        dst = copy_targets[key]
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)


def _generate_warp(
    dst_root: Path,
    split: str,
    name: str,
    pf_python: Path,
    repo_dir: Path,
    checkpoint: Path,
    width: int,
    height: int,
    skip_existing: bool,
) -> None:
    person = dst_root / split / "image" / name
    cloth = dst_root / split / "cloth" / name
    edge = dst_root / split / "cloth-mask" / name
    output_cloth = dst_root / split / "cloth-warp" / name
    output_mask = dst_root / split / "cloth-warp-mask" / name
    if skip_existing and output_cloth.exists() and output_mask.exists():
        return
    output_cloth.parent.mkdir(parents=True, exist_ok=True)
    output_mask.parent.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env["CUDA_VISIBLE_DEVICES"] = env.get("CUDA_VISIBLE_DEVICES", "0")
    cmd = [
        str(pf_python),
        str(BASE_DIR / "pf_afn_warp_export.py"),
        "--repo-dir",
        str(repo_dir),
        "--checkpoint",
        str(checkpoint),
        "--person",
        str(person),
        "--cloth",
        str(cloth),
        "--edge",
        str(edge),
        "--output-cloth",
        str(output_cloth),
        "--output-mask",
        str(output_mask),
        "--width",
        str(width),
        "--height",
        str(height),
    ]
    subprocess.run(cmd, check=True, env=env)


def _write_config(path: Path, dataroot: Path, batch_size: int, max_epochs: int, image_size: int) -> None:
    config = f"""model:
  base_learning_rate: 5.0e-06
  target: ldm.models.diffusion.ddpm.LatentTryOnDiffusion
  params:
    linear_start: 0.00085
    linear_end: 0.0120
    num_timesteps_cond: 1
    log_every_t: 200
    timesteps: 1000
    first_stage_key: "inpaint"
    cond_stage_key: "image"
    image_size: 64
    channels: 4
    cond_stage_trainable: true
    conditioning_key: crossattn
    monitor: val/loss_simple_ema
    u_cond_percent: 0.2
    scale_factor: 0.18215
    use_ema: False
    scheduler_config:
      target: ldm.lr_scheduler.LambdaLinearScheduler
      params:
        warm_up_steps: [100]
        cycle_lengths: [10000000000000]
        f_start: [1.e-6]
        f_max: [1.]
        f_min: [1.]
    unet_config:
      target: ldm.modules.diffusionmodules.openaimodel.UNetModel
      params:
        image_size: 64
        in_channels: 9
        out_channels: 4
        model_channels: 320
        attention_resolutions: [4, 2, 1]
        num_res_blocks: 2
        channel_mult: [1, 2, 4, 4]
        num_heads: 8
        use_spatial_transformer: True
        transformer_depth: 1
        context_dim: 768
        use_checkpoint: False
        legacy: False
        add_conv_in_front_of_unet: False
    first_stage_config:
      target: ldm.models.autoencoder.AutoencoderKL
      params:
        embed_dim: 4
        monitor: val/rec_loss
        ddconfig:
          double_z: true
          z_channels: 4
          resolution: {image_size}
          in_channels: 3
          out_ch: 3
          ch: 128
          ch_mult: [1, 2, 4, 4]
          num_res_blocks: 2
          attn_resolutions: []
          dropout: 0.0
        lossconfig:
          target: torch.nn.Identity
    cond_stage_config:
      target: ldm.modules.encoders.modules.FrozenCLIPImageEmbedder

data:
  target: main.DataModuleFromConfig
  params:
    batch_size: {batch_size}
    num_workers: 0
    wrap: False
    train:
      target: ldm.data.cp_dataset_v2.CPDataset
      params:
        mode: train
        dataroot: "{dataroot.as_posix()}"
        image_size: {image_size}
    validation:
      target: ldm.data.cp_dataset_v2.CPDataset
      params:
        mode: test
        dataroot: "{dataroot.as_posix()}"
        image_size: {image_size}
    test:
      target: ldm.data.cp_dataset_v2.CPDataset
      params:
        mode: test
        dataroot: "{dataroot.as_posix()}"
        image_size: {image_size}

lightning:
  trainer:
    max_epochs: {max_epochs}
    num_nodes: 1
    gpus: "0,"
    accumulate_grad_batches: 1
  modelcheckpoint:
    params:
      every_n_epochs: 1
      save_top_k: 1
      save_last: True
"""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(config, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a tiny VITON-HD-style dataset for DCI fine-tuning.")
    parser.add_argument("--source-root", default=r"C:\Users\muhdi\Desktop\mobile database")
    parser.add_argument("--output", default=str(BASE_DIR / "datasets" / "dci_finetune_tiny"))
    parser.add_argument("--train-count", type=int, default=16)
    parser.add_argument("--val-count", type=int, default=4)
    parser.add_argument("--seed", type=int, default=31)
    parser.add_argument("--pf-python", default=r"C:\Users\muhdi\miniconda3\envs\pfafen-gpu-clean\python.exe")
    parser.add_argument("--pf-repo", default=str(BASE_DIR / "third_party" / "PF-AFN" / "PF-AFN_test"))
    parser.add_argument(
        "--warp-checkpoint",
        default=str(BASE_DIR / "results" / "pf_afn_finetune" / "warp_vitonhd_tops_curated300_continue_180step.pth"),
    )
    parser.add_argument("--width", type=int, default=192)
    parser.add_argument("--height", type=int, default=256)
    parser.add_argument("--image-size", type=int, default=512)
    parser.add_argument("--skip-warps", action="store_true")
    parser.add_argument("--no-skip-existing", action="store_true")
    args = parser.parse_args()

    src_root = Path(args.source_root)
    dst_root = Path(args.output)
    pair_file = src_root / "test_pairs.txt"
    names = _pair_rows(pair_file)
    valid = [name for name in names if all(path.exists() for path in _required_paths(src_root, "test", name).values())]
    random.Random(args.seed).shuffle(valid)
    total = args.train_count + args.val_count
    selected = valid[:total]
    train_names = selected[: args.train_count]
    val_names = selected[args.train_count : total]

    for split in ["train", "test"]:
        for folder in ["image", "cloth", "cloth-mask", "image-parse-v3", "openpose_json", "cloth-warp", "cloth-warp-mask"]:
            (dst_root / split / folder).mkdir(parents=True, exist_ok=True)

    for name in train_names:
        _copy_sample(src_root, dst_root, "test", "train", name)
    for name in val_names:
        _copy_sample(src_root, dst_root, "test", "test", name)

    (dst_root / "train_pairs.txt").write_text("".join(f"{name} {name}\n" for name in train_names), encoding="utf-8")
    (dst_root / "test_pairs.txt").write_text("".join(f"{name} {name}\n" for name in val_names), encoding="utf-8")

    if not args.skip_warps:
        checkpoint = Path(args.warp_checkpoint)
        if not checkpoint.exists():
            checkpoint = BASE_DIR / "third_party" / "PF-AFN" / "PF-AFN_test" / "checkpoints" / "PFAFN" / "warp_model_final.pth"
        for split, split_names in [("train", train_names), ("test", val_names)]:
            for index, name in enumerate(split_names, start=1):
                print(f"[{split} {index}/{len(split_names)}] generating PF-AFN warp for {name}", flush=True)
                _generate_warp(
                    dst_root,
                    split,
                    name,
                    Path(args.pf_python),
                    Path(args.pf_repo),
                    checkpoint,
                    args.width,
                    args.height,
                    skip_existing=not args.no_skip_existing,
                )

    config_path = BASE_DIR / "configs" / "dci_finetune_tiny.yaml"
    _write_config(config_path, dst_root.resolve(), batch_size=1, max_epochs=1, image_size=args.image_size)
    summary = {
        "source_root": str(src_root),
        "output": str(dst_root),
        "config": str(config_path),
        "valid_source_samples": len(valid),
        "train": len(train_names),
        "validation": len(val_names),
        "train_names": train_names,
        "validation_names": val_names,
    }
    (dst_root / "build_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
