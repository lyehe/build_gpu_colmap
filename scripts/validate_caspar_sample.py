#!/usr/bin/env python3
"""Validate Caspar bundle adjustment on a deterministic COLMAP sample model."""

from __future__ import annotations

import argparse
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def write_sample_model(model_dir: Path, num_images: int, num_points: int) -> None:
    model_dir.mkdir(parents=True, exist_ok=True)
    width, height = 1280, 960
    fx = fy = 800.0
    cx, cy = width / 2.0, height / 2.0

    points = []
    for point_idx in range(num_points):
        a = (point_idx * 37) % 1000 / 1000.0
        b = (point_idx * 91) % 1000 / 1000.0
        c = (point_idx * 53) % 1000 / 1000.0
        points.append((-1.0 + 2.0 * a, -0.65 + 1.30 * b, 5.5 + 2.5 * c))

    centers = []
    for image_idx in range(num_images):
        u = image_idx / max(num_images - 1, 1)
        centers.append((-1.5 + 3.0 * u, 0.10 * math.sin(2.0 * math.pi * u), 0.0))

    (model_dir / "cameras.txt").write_text(
        f"1 PINHOLE {width} {height} {fx:.12g} {fy:.12g} {cx:.12g} {cy:.12g}\n",
        encoding="ascii",
    )

    with (model_dir / "images.txt").open("w", encoding="ascii") as file:
        for image_idx, (cam_x, cam_y, cam_z) in enumerate(centers, start=1):
            file.write(
                f"{image_idx} 1 0 0 0 {-cam_x:.12g} {-cam_y:.12g} "
                f"{-cam_z:.12g} 1 image_{image_idx:03d}.jpg\n"
            )
            observations = []
            for point_idx, (x, y, z) in enumerate(points, start=1):
                x_cam = x - cam_x
                y_cam = y - cam_y
                z_cam = z - cam_z
                noise_x = 0.35 * math.sin(point_idx * 0.17 + image_idx * 0.31)
                noise_y = 0.35 * math.cos(point_idx * 0.13 - image_idx * 0.29)
                pixel_x = fx * x_cam / z_cam + cx + noise_x
                pixel_y = fy * y_cam / z_cam + cy + noise_y
                observations.append(f"{pixel_x:.6f} {pixel_y:.6f} {point_idx}")
            file.write(" ".join(observations) + "\n")

    with (model_dir / "points3D.txt").open("w", encoding="ascii") as file:
        for point_idx, (x, y, z) in enumerate(points, start=1):
            track = " ".join(
                f"{image_idx} {point_idx - 1}"
                for image_idx in range(1, num_images + 1)
            )
            red = (point_idx * 41) % 256
            green = (point_idx * 73) % 256
            blue = (point_idx * 17) % 256
            file.write(
                f"{point_idx} {x:.12g} {y:.12g} {z:.12g} "
                f"{red} {green} {blue} 1.0 {track}\n"
            )


def run_command(args: list[str]) -> subprocess.CompletedProcess[str]:
    print("+ " + " ".join(args), flush=True)
    completed = subprocess.run(
        args,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    print(completed.stdout, end="")
    if completed.returncode != 0:
        raise RuntimeError(f"command failed with exit code {completed.returncode}")
    return completed


def analyze_model(colmap: str, model_dir: Path) -> float:
    completed = run_command(
        [colmap, "model_analyzer", "--path", str(model_dir), "--log_target", "stderr"]
    )
    for line in completed.stdout.splitlines():
        if "Mean reprojection error:" in line:
            return float(line.rsplit(":", 1)[1].strip().removesuffix("px"))
    raise RuntimeError("model_analyzer did not report mean reprojection error")


def validate_pycolmap(
    model_dir: Path,
    input_error: float,
    gpu_index: str,
    solver_iter_max: int,
) -> None:
    import pycolmap  # type: ignore[import-not-found]

    assert (
        pycolmap.BundleAdjustmentBackend("CASPAR")
        == pycolmap.BundleAdjustmentBackend.CASPAR
    )
    options = pycolmap.BundleAdjustmentOptions()
    options.backend = pycolmap.BundleAdjustmentBackend.CASPAR
    assert isinstance(options.caspar, pycolmap.CasparBundleAdjustmentOptions)
    options.caspar.gpu_index = gpu_index
    options.caspar.solver_iter_max = solver_iter_max
    options.refine_focal_length = False
    options.refine_principal_point = False
    options.refine_extra_params = False
    options.min_track_length = 2
    options.print_summary = False

    reconstruction = pycolmap.Reconstruction(model_dir)
    pycolmap.bundle_adjustment(reconstruction, options)
    output_error = reconstruction.compute_mean_reprojection_error()
    if output_error >= input_error:
        raise RuntimeError(
            "pycolmap Caspar bundle adjustment did not improve reprojection "
            f"error: {input_error:.6f}px -> {output_error:.6f}px"
        )
    print(
        "pycolmap Caspar validation passed: "
        f"{input_error:.6f}px -> {output_error:.6f}px"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--colmap", default=shutil.which("colmap") or "colmap")
    parser.add_argument("--work-dir", type=Path)
    parser.add_argument("--images", type=int, default=4)
    parser.add_argument("--points", type=int, default=100)
    parser.add_argument("--gpu-index", default="0")
    parser.add_argument("--solver-iter-max", type=int, default=20)
    parser.add_argument("--require-pycolmap", action="store_true")
    args = parser.parse_args()

    if args.images < 2:
        raise ValueError("--images must be at least 2")
    if args.points < 1:
        raise ValueError("--points must be at least 1")

    base_dir = args.work_dir or Path(tempfile.mkdtemp(prefix="colmap-caspar-"))
    input_dir = base_dir / "input"
    output_dir = base_dir / "caspar-output"
    output_dir.mkdir(parents=True, exist_ok=True)

    write_sample_model(input_dir, args.images, args.points)
    input_error = analyze_model(args.colmap, input_dir)

    run_command(
        [
            args.colmap,
            "bundle_adjuster",
            "--input_path",
            str(input_dir),
            "--output_path",
            str(output_dir),
            "--BundleAdjustment.backend",
            "CASPAR",
            "--BundleAdjustmentCaspar.gpu_index",
            args.gpu_index,
            "--BundleAdjustmentCaspar.solver_iter_max",
            str(args.solver_iter_max),
            "--BundleAdjustment.refine_focal_length",
            "0",
            "--BundleAdjustment.refine_principal_point",
            "0",
            "--BundleAdjustment.refine_extra_params",
            "0",
            "--BundleAdjustment.min_track_length",
            "2",
            "--log_target",
            "stderr",
        ]
    )

    for filename in ("cameras.bin", "images.bin", "points3D.bin"):
        if not (output_dir / filename).is_file():
            raise RuntimeError(f"missing output file: {output_dir / filename}")

    output_error = analyze_model(args.colmap, output_dir)
    if output_error >= input_error:
        raise RuntimeError(
            "Caspar bundle adjustment did not improve reprojection error: "
            f"{input_error:.6f}px -> {output_error:.6f}px"
        )

    if args.require_pycolmap:
        validate_pycolmap(
            input_dir,
            input_error,
            args.gpu_index,
            args.solver_iter_max,
        )
    print(
        "Caspar sample validation passed: "
        f"{input_error:.6f}px -> {output_error:.6f}px"
    )
    print(f"Work directory: {base_dir}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
