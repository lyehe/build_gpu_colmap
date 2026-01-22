# Point Cloud Tools

Pre-built COLMAP, GLOMAP, and pycolmap binaries with CUDA support for Windows and Linux.

## Downloads

Download the latest release from [GitHub Releases](https://github.com/YOUR_USERNAME/build_gpu_colmap/releases).

### Available Packages

| Package | Description |
|---------|-------------|
| **COLMAP** | Structure-from-Motion and Multi-View Stereo (v3.13 dev) |
| **GLOMAP** | Fast global Structure-from-Motion |
| **pycolmap** | Python bindings for COLMAP |

### Release Variants

| Variant | Description | Use Case |
|---------|-------------|----------|
| `CPU` | CPU-only build | Systems without NVIDIA GPU |
| `CUDA` | GPU-accelerated with CUDA | NVIDIA GPU (CUDA Toolkit not required) |
| `CUDA-cuDSS` | CUDA + cuDSS sparse solver | Best performance (2-5x faster sparse solving) |

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
```

### GLOMAP

GLOMAP packages are self-contained and include their own COLMAP 3.11 for compatibility.

**Windows:**
```powershell
# Extract the archive
Expand-Archive GLOMAP-windows-latest-CUDA12.8.1.zip -DestinationPath C:\Tools\GLOMAP

# Add to PATH (optional)
$env:PATH = "C:\Tools\GLOMAP\bin;$env:PATH"

# Run GLOMAP
glomap mapper --database_path ./database.db --image_path ./images --output_path ./sparse
```

**Linux:**
```bash
# Extract the archive
unzip GLOMAP-ubuntu-22.04-CUDA12.8.1.zip -d ~/tools/glomap

# Add to PATH (optional)
export PATH="$HOME/tools/glomap/bin:$PATH"

# Run GLOMAP
glomap mapper --database_path ./database.db --image_path ./images --output_path ./sparse
```

### pycolmap (Python Wheels)

**Install from wheel file:**
```bash
# Download the wheel for your Python version (e.g., cp312 = Python 3.12)
pip install pycolmap-3.13.0.dev0-cp312-cp312-win_amd64.whl      # Windows
pip install pycolmap-3.13.0.dev0-cp312-cp312-linux_x86_64.whl   # Linux

# Verify installation
python -c "import pycolmap; print(pycolmap.__version__)"
```

**Available Python versions:** 3.10, 3.11, 3.12, 3.13

**Usage example:**
```python
import pycolmap

# Run automatic reconstruction
pycolmap.automatic_reconstructor(
    workspace_path="./project",
    image_path="./images"
)

# Or use individual components
database_path = "./database.db"
pycolmap.extract_features(database_path, "./images")
pycolmap.match_exhaustive(database_path)
maps = pycolmap.incremental_mapping(database_path, "./images", "./sparse")
```

## Package Size Differences

Linux packages are significantly smaller than Windows packages:

| Package | Linux | Windows | Reason |
|---------|-------|---------|--------|
| COLMAP CUDA | ~45 MB | ~1.3 GB | CUDA runtime bundling |
| GLOMAP CUDA | ~10 MB | ~1.2 GB | CUDA runtime bundling |
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
- **Storage:** 2 GB for COLMAP, 1.5 GB for GLOMAP

### For CUDA builds
- **GPU:** NVIDIA GPU with Compute Capability 7.5+ (RTX 20 series or newer)
- **Driver:** NVIDIA driver 520+ (Windows), 525+ (Linux)
- **CUDA:** Not required on Windows (bundled). Required on Linux (CUDA 11.0+)

### Supported GPU Architectures
- Turing (RTX 20 series, GTX 16 series) - SM 7.5
- Ampere (RTX 30 series, A100) - SM 8.0, 8.6
- Ada Lovelace (RTX 40 series) - SM 8.9
- Hopper (H100) - SM 9.0
- Blackwell (RTX 50 series) - SM 12.0

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
- **GLOMAP:** BSD-3-Clause
- **This build system:** MIT

## Links

- [COLMAP Documentation](https://colmap.github.io/)
- [GLOMAP Repository](https://github.com/colmap/glomap)
- [pycolmap Documentation](https://colmap.github.io/pycolmap.html)
