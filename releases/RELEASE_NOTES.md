# COLMAP Build v4.3.0 - development preview

This custom preview adds FlexGlue to the CUDA-accelerated Windows and Linux
COLMAP packages and matching pycolmap wheels. Upstream has not released 4.3.0;
these packages stamp version `4.3.0` onto upstream `4.3.0.dev0` source.

Both COLMAP source submodules are pinned to commit
`f0ddf77c3a1f2a1d15c6798e669872d1025fdc53` from November 8, 2026.
Every artifact includes a `build_info.json` provenance record;
`SHA256SUMS.txt` covers every published asset. This build is published as a
GitHub prerelease and leaves the latest stable release in place.
Preview wheels are excluded from the default pip index; download and install
them directly from this release's assets.

## FlexGlue

- Matches keypoints from any extractor through dense image features.
- Predicts covisibility to reject look-alike image pairs and supports early
  stopping for pairs that are confidently not covisible.
- Caches dense features on the GPU and uses float16 transformer layers on
  compatible CUDA GPUs, with float32 fallback.
- Available through the CLI, GUI, and `pycolmap.FlexGlueMatchingOptions`.
- ONNX support is enabled by default in both native and Python builds.

After extracting features, match with:

```bash
colmap exhaustive_matcher --database_path ./database.db --FeatureMatching.type FLEXGLUE --FlexGlueMatching.image_path ./images
```

For automatic extraction and matching with DaD keypoints:

```bash
colmap automatic_reconstructor --workspace_path ./project --image_path ./images --feature flexglue
```

FlexGlue reads the original images during matching, so its image path is
required. Guided matching is unsupported. Use a fresh database or clear its
existing matches and two-view geometries when switching matchers.

The models download automatically. The offline model helpers now include the
FlexGlue descriptor and both early-stop matchers, with SHA256 verification.
The automatic preset also uses LoMa extraction models, downloaded separately.

See the [FlexGlue integration](https://github.com/colmap/colmap/pull/4908) and
[usage documentation](https://colmap.github.io/features.html#flexglue).

## Compatibility

- Upstream now requires Boost >= 1.84 and always uses Boost hash maps. The old
  `COLMAP_HASH_MAP_BACKEND=STD` setting has been removed. Where the system Boost
  is too old, upstream fetches and installs a pinned copy automatically.
- C++ consumers must rebuild against these libraries and use the Boost
  dependency exported by the installed COLMAP configuration.
- ONNX Runtime remains at 1.30.0. Caspar GPU bundle adjustment and optional
  cuDSS and Windows GUI variants remain available.

## Package matrix

### COLMAP archives (11)

| Platform | Variants |
| --- | --- |
| Ubuntu 22.04 | `CPU`, `CUDA-Caspar`, `CUDA-cuDSS-Caspar` |
| Ubuntu 24.04 | `CPU`, `CUDA-Caspar`, `CUDA-cuDSS-Caspar` |
| Windows 2022 | `CPU`, `CUDA-Caspar`, `CUDA-cuDSS-Caspar`, `CUDA-Caspar-GUI`, `CUDA-cuDSS-Caspar-GUI` |

### pycolmap wheels (55)

Python 3.10 through 3.14 on Windows (`win_amd64`) and Linux
(`manylinux_2_35_x86_64`). Windows has CPU, CUDA, and CUDA+cuDSS wheels.
Linux additionally offers self-contained CUDA 12.8, 13.0, and 13.1 wheels,
with and without cuDSS. Linux wheels support Ubuntu 22.04 and 24.04.

## Runtime requirements

- CPU packages do not require an NVIDIA GPU; FlexGlue is substantially faster
  with a CUDA GPU.
- CUDA packages require a driver compatible with the packaged CUDA runtime.
- Windows CUDA archives bundle the required runtime DLLs.
- Linux CUDA archives require compatible NVIDIA runtime support on the host.

## Validation

CI checks for FlexGlue CLI options and Python bindings in addition to the
existing binary import and Caspar API smoke checks.

Use the deterministic Caspar sample to validate a built binary and,
optionally, a pycolmap wheel on a compatible GPU:

```bash
python scripts/validate_caspar_sample.py --colmap /path/to/colmap --require-pycolmap
```
