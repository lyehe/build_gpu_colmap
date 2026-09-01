# COLMAP Build v4.2.0-3

This build revision adds native Ubuntu 24.04 archives to the GPU-accelerated
upstream COLMAP 4.2.0 packages for Windows and Linux. CUDA archives include
Caspar GPU bundle adjustment.

Both COLMAP source submodules are pinned to the upstream `4.2.0` tag at commit
`be5e29168d4aff238409d60424812df66aac919f`. Every artifact includes a
`build_info.json` provenance record; `SHA256SUMS.txt` covers every published
asset.

This release also includes the post-4.1.1 build fixes: ONNX model download and
cache support is enabled, the offline helper fetches the full default model set,
and the vcpkg baseline and binary-cache configuration are current. These fixes
are required for reliable Windows and Linux package builds and for learned
feature pipelines to obtain their ONNX models.

## Highlights in COLMAP 4.2.0

- The global mapper can reconstruct disconnected view-graph components into
  separate models. This is available in the CLI and pycolmap.
- LoMa learned feature extraction and matching are available through ONNX in
  the CLI, GUI, and pycolmap.
- HIP/ROCm support adds AMD GPU acceleration for `patch_match_stereo`.
  HIP and CUDA builds are mutually exclusive; this release continues to ship
  CUDA builds.
- The GUI adds incremental, global, and hierarchical mapper selection with
  mapper-specific configuration and progress rendering.
- pycolmap now exposes hierarchical mapping, expanded global-pipeline bindings,
  cooperative cancellation, and nanosecond timestamps.
- Two-view geometry gains 6-point focal-length solvers, optional DEGENSAC, and
  more accurate pixel-consistent tangent Sampson error.
- Analytical camera-model Jacobians improve common incremental-mapping runs.
- Caspar handling and its fixed-rotation global-bundle-adjustment stage are
  corrected. CUDA builds also fall back to CPU Ceres when no compatible GPU is
  present at runtime.

## Compatibility notes

- Global mapping now returns models for all connected components by default.
  Set `GlobalMapper.multiple_models` to `false` to retain the former
  largest-component-only behavior. Models smaller than
  `GlobalMapper.min_model_size` registered frames are discarded.
- `hierarchical_mapper` options `num_threads`, `num_workers`, `image_overlap`,
  and `leaf_max_num_images` are now prefixed with `HierarchicalMapper.`.
- `pycolmap.estimate_essential_matrix` no longer returns `inlier_points3D`, and
  `pycolmap.cost_functions.SampsonErrorCost` now accepts image-plane points.
- C++ users should note renamed hierarchical-pipeline and fisheye helpers,
  `CamRayWithJac` relative-pose APIs, and removal of global
  `std::hash<std::pair<...>>` specializations. Use `colmap::PairHash` for pair
  keys in unordered containers.

See the upstream COLMAP 4.2.0 changelog for the complete change list.

## Package matrix

### COLMAP archives (11)

| Platform | Variants |
| --- | --- |
| Ubuntu 22.04 | `CPU`, `CUDA-Caspar`, `CUDA-cuDSS-Caspar` |
| Ubuntu 24.04 | `CPU`, `CUDA-Caspar`, `CUDA-cuDSS-Caspar` |
| Windows 2022 | `CPU`, `CUDA-Caspar`, `CUDA-cuDSS-Caspar`, `CUDA-Caspar-GUI`, `CUDA-cuDSS-Caspar-GUI` |

### pycolmap wheels (55)

Wheels are available for Python 3.10 through 3.14 on Windows (`win_amd64`) and
Linux (`manylinux_2_35_x86_64`). The Linux wheels are compatible with both
Ubuntu 22.04 and 24.04. Windows has CPU, CUDA, and CUDA+cuDSS wheels; Linux
additionally offers self-contained CUDA 12.8, 13.0, and 13.1 wheels, with and
without cuDSS.

## Runtime requirements

- CPU packages do not require an NVIDIA GPU.
- CUDA packages require a driver compatible with the packaged CUDA runtime.
- Windows CUDA archives bundle the required runtime DLLs.
- Linux CUDA archives require compatible NVIDIA runtime support on the host.
- CUDA support in Caspar requires a GPU architecture of 7.0 or newer.

## Validation

Use the deterministic Caspar sample to validate a downloaded binary and,
optionally, a pycolmap wheel:

```bash
python scripts/validate_caspar_sample.py --colmap /path/to/colmap --require-pycolmap
```
