# Point Cloud Tools

Pre-built COLMAP and pycolmap binaries with CUDA support for Windows and Linux.

**Note:** GLOMAP has been merged into COLMAP. Use `colmap global_mapper` for global Structure-from-Motion.

## Downloads

Download the latest release from [GitHub Releases](https://github.com/lyehe/build_gpu_colmap/releases).

### Available Packages

| Package | Description |
|---------|-------------|
| **COLMAP** | Structure-from-Motion and Multi-View Stereo (v4.0.2) |
| **pycolmap** | Python bindings for COLMAP |

### Release Variants

| Variant | Description | Use Case |
|---------|-------------|----------|
| `CPU` | CPU-only build | Systems without NVIDIA GPU |
| `CUDA` | GPU-accelerated with CUDA | NVIDIA GPU (CUDA Toolkit not required) |
| `CUDA-cuDSS` | CUDA + cuDSS sparse solver | Best performance (2-5x faster sparse solving) |
| `CUDA-GUI` | CUDA + Qt GUI | Interactive reconstruction with GPU |
| `CUDA-cuDSS-GUI` | CUDA + cuDSS + Qt GUI | Best performance with GUI |

## Installation

### COLMAP

**Windows:**
```powershell
# Extract the archive
Expand-Archive COLMAP-windows-latest-CUDA.zip -DestinationPath C:\Tools\COLMAP

# Add to PATH (optional)
$env:PATH = "C:\Tools\COLMAP\bin;$env:PATH"

# Run COLMAP
colmap gui
colmap automatic_reconstructor --workspace_path ./project --image_path ./images

# Global SfM (previously GLOMAP)
colmap global_mapper --database_path ./database.db --image_path ./images --output_path ./sparse

# ALIKED + LightGlue (learned features)
colmap feature_extractor --database_path ./database.db --image_path ./images --FeatureExtraction.type ALIKED_N16ROT
colmap exhaustive_matcher --database_path ./database.db --FeatureMatching.type ALIKED_LIGHTGLUE
colmap mapper --database_path ./database.db --image_path ./images --output_path ./sparse
```

**Linux:**
```bash
# Extract the archive
unzip COLMAP-ubuntu-22.04-CUDA.zip -d ~/tools/colmap

# Add to PATH (optional)
export PATH="$HOME/tools/colmap/bin:$PATH"

# Run COLMAP
colmap gui
colmap automatic_reconstructor --workspace_path ./project --image_path ./images

# Global SfM (previously GLOMAP)
colmap global_mapper --database_path ./database.db --image_path ./images --output_path ./sparse

# ALIKED + LightGlue (learned features)
colmap feature_extractor --database_path ./database.db --image_path ./images --FeatureExtraction.type ALIKED_N16ROT
colmap exhaustive_matcher --database_path ./database.db --FeatureMatching.type ALIKED_LIGHTGLUE
colmap mapper --database_path ./database.db --image_path ./images --output_path ./sparse
```

### pycolmap (Python Wheels)

**Install from wheel file:**
```bash
# Download the wheel for your Python version (e.g., cp312 = Python 3.12)
pip install pycolmap-4.0.2-cp312-cp312-win_amd64.whl      # Windows
pip install pycolmap-4.0.2-cp312-cp312-linux_x86_64.whl   # Linux

# Verify installation
python -c "import pycolmap; print(pycolmap.__version__)"
```

**Available Python versions:** 3.10, 3.11, 3.12, 3.13, 3.14

**Usage example:**
```python
import pycolmap

database_path = "./database.db"
image_path = "./images"
output_path = "./sparse"

# Extract features and match
pycolmap.extract_features(database_path, image_path)
pycolmap.match_exhaustive(database_path)

# Incremental SfM
maps = pycolmap.incremental_mapping(database_path, image_path, output_path)

# Or Global SfM (GLOMAP)
maps = pycolmap.global_mapping(database_path, image_path, output_path)
```

**ALIKED + LightGlue (learned features):**
```python
import pycolmap

database_path = "./database.db"
image_path = "./images"

# Extract ALIKED features
pycolmap.extract_features(database_path, image_path,
    options=pycolmap.FeatureExtractionOptions(
        type=pycolmap.FeatureExtractorType.ALIKED_N16ROT))

# Match with LightGlue
pycolmap.match_exhaustive(database_path)

# Reconstruct
maps = pycolmap.incremental_mapping(database_path, image_path, "./sparse")
```

## Package Size Differences

Linux packages are significantly smaller than Windows packages:

| Package | Linux | Windows | Reason |
|---------|-------|---------|--------|
| COLMAP CUDA | ~45 MB | ~1.3 GB | CUDA runtime bundling |
| pycolmap | ~26 MB | ~1 GB | CUDA runtime bundling |

**Why?**
- **Linux:** Dynamically links to system CUDA libraries. Requires CUDA Toolkit installed separately for GPU features.
- **Windows:** Bundles all CUDA runtime DLLs for self-contained operation. No separate CUDA installation needed.

### Linux CUDA Requirements

For GPU acceleration on Linux, install the CUDA Toolkit:
```bash
# Ubuntu/Debian
sudo apt-get install nvidia-cuda-toolkit

# Or download from NVIDIA
# https://developer.nvidia.com/cuda-downloads
```

## System Requirements

### Minimum
- **OS:** Windows 10/11 x64 or Ubuntu 22.04+ x64
- **RAM:** 8 GB (16 GB+ recommended for large datasets)
- **Storage:** 2 GB for COLMAP

### For CUDA builds
- **GPU:** NVIDIA GPU with Compute Capability 7.5+ (RTX 20 series or newer)
- **Driver:** NVIDIA driver 570+ (CUDA 12.8)
- **CUDA:** Not required on Windows (bundled). Required on Linux (CUDA 12.0+)

### Supported GPU Architectures
- Turing (RTX 20 series, GTX 16 series) - SM 7.5
- Ampere (RTX 30 series, A100) - SM 8.0, 8.6
- Ada Lovelace (RTX 40 series) - SM 8.9
- Hopper (H100) - SM 9.0
- Blackwell (RTX 50 series) - SM 12.0

## Migration from GLOMAP

If you were previously using the standalone GLOMAP binary, simply replace:

```bash
# Old (standalone GLOMAP)
glomap mapper --database_path db.db --image_path images --output_path sparse

# New (COLMAP 4.0+)
colmap global_mapper --database_path db.db --image_path images --output_path sparse
```

## CI / Release Workflow

Releases are fully automated via GitHub Actions:

```bash
# Create and push a tag — this builds everything and creates a GitHub release
git tag v4.0.2
git push origin v4.0.2
```

**What happens:** `release.yml` triggers → builds 8 COLMAP variants + 25 pycolmap wheels → packages → publishes GitHub release. Build steps auto-retry up to 3 times on transient failures (e.g., vcpkg HTTP 502).

**If a job still fails** (rare), retry only the failed jobs without restarting everything:
```bash
gh run rerun <run-id> --failed
```

**Manual builds** (without releasing):
```bash
# Trigger from GitHub Actions UI or:
gh workflow run build-colmap.yml
gh workflow run build-pycolmap.yml
```

## Building from Source

See [CLAUDE.md](.claude/CLAUDE.md) for detailed build instructions.

**Quick start:**
```powershell
# Windows
.\scripts_windows\build.ps1 -Configuration Release

# Linux
./scripts_linux/build.sh --config Release
```

## License

- **COLMAP:** BSD-3-Clause
- **This build system:** MIT

## Links

- [COLMAP Documentation](https://colmap.github.io/)
- [pycolmap Documentation](https://colmap.github.io/pycolmap.html)
