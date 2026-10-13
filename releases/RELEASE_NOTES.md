# COLMAP Build v4.2.1

This release updates the GPU-accelerated Windows and Linux packages to upstream
COLMAP 4.2.1. Native Linux archives cover Ubuntu 22.04 and 24.04. CUDA archives
include Caspar GPU bundle adjustment.

Both COLMAP source submodules are pinned to the upstream `4.2.1` tag at commit
`bd1fcf654d2dd8fefa1466999c190a246f83f4b9`. Every artifact includes a
`build_info.json` provenance record; `SHA256SUMS.txt` covers every published
asset.

ONNX model download and cache support, the offline model helper, and the existing
vcpkg binary-cache configuration are retained from the 4.2.0 packages.

## Fixes in COLMAP 4.2.1

- Restores the global mapper's bundle-adjustment behavior after a 4.2.0
  regression. Retriangulation refinement keeps camera poses and intrinsics fixed
  while refining 3D points.
- Upgrades ONNX Runtime to 1.30.0 to fix a GPU memory leak in LoMa matching.
- Uses a fixed hash-map backend to prevent binary compatibility mismatches
  caused by different Boost versions on build machines.
- Fixes CUDA rotate, transpose, and flip operations on large images.
- Prevents Delaunay meshing from hanging or consuming unbounded memory when a
  point coincides with a camera center, and fixes binary PLY output in PoissonRecon.
- Corrects merged point colors, two-view geometry filtering, rig pose selection,
  and pycolmap method chaining and NumPy annotations.

## Compatibility notes

- Both packaged COLMAP builds explicitly use the `STD` hash-map backend. C++
  consumers must use the same backend and rebuild against the 4.2.1 libraries.

The API and mapping changes introduced in 4.2.0 still apply:

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

See the [upstream COLMAP 4.2.1 release notes](https://github.com/colmap/colmap/releases/tag/4.2.1)
for the complete change list.

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
