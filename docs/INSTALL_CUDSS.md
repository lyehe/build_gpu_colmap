# Installing cuDSS (CUDA Direct Sparse Solver)

cuDSS provides significant GPU-accelerated performance improvements for sparse linear solvers used in COLMAP and GLOMAP.

## Why is cuDSS showing as NOT FOUND?

The verification script shows `[NOT FOUND]` because cuDSS is:
- **Optional** - COLMAP/GLOMAP work without it, but slower
- **Not installed by default** with CUDA Toolkit
- A **separate download** from NVIDIA

## Windows Installation

### Recommended: Using the Installer (Easiest)

1. Visit: https://developer.nvidia.com/cudss-downloads
2. **Sign in** with NVIDIA Developer account (free registration if you don't have one)
3. Download the **Windows Installer** (e.g., `cudss_windows_12.8_0.7.0.39.exe` for CUDA 12.8)
4. Run the installer
   - It will install to: `C:\Program Files\NVIDIA cuDSS\v0.7\`
   - No additional configuration needed

### Verification

```powershell
# Check installation directory exists
Test-Path "C:\Program Files\NVIDIA cuDSS"

# Re-run verification script
.\scripts_windows\verify_build_environment.ps1
```

You should now see:
```
cuDSS (CUDA Sparse Solver)    [OK] - Standalone installation (v0.7)
```

### Alternative: Manual Installation from ZIP/Archive

If you prefer to download the archive instead of using the installer:

**Step 1: Download and Extract**

Download the ZIP/archive version and extract. The structure will be:
```
cudss-windows-x86_64-0.7.0.39/
├── include/
│   ├── cudss.h
│   └── ... (other headers)
├── lib/
│   ├── 12/  (for CUDA 12.x)
│   │   ├── cudss.lib
│   │   └── cudss_mtlayer_vcomp140.lib
│   └── 13/  (for CUDA 13.x, if applicable)
├── bin/
│   ├── cudss64_0.dll
│   └── ... (other DLLs)
└── cmake/
```

**Step 2: Copy to CUDA Installation (Run PowerShell as Administrator)**

```powershell
# Set paths
$CudssExtractPath = "C:\path\to\extracted\cudss-windows-x86_64-0.7.0.39"
$CudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8"
$CudaMajorVersion = "12"  # Use "13" for CUDA 13.x

# Copy header files
Copy-Item "$CudssExtractPath\include\*" "$CudaPath\include\" -Force

# Copy library files (for your CUDA version)
Copy-Item "$CudssExtractPath\lib\$CudaMajorVersion\*" "$CudaPath\lib\x64\" -Force

# Copy DLL files
Copy-Item "$CudssExtractPath\bin\*" "$CudaPath\bin\" -Force
```

**Step 3: Verify**

```powershell
# Check files were copied
Test-Path "$env:CUDA_PATH\include\cudss.h"
Test-Path "$env:CUDA_PATH\lib\x64\cudss.lib"

# Re-run verification
.\scripts_windows\verify_build_environment.ps1
```

## Linux Installation

### Step 1: Download

1. Visit: https://developer.nvidia.com/cudss-downloads
2. **Sign in** with NVIDIA Developer account
3. Download the **Linux** version (e.g., `cudss-linux-x86_64-0.7.0.39.tar.xz`)

### Step 2: Extract and Install

```bash
# Extract the archive
tar -xf cudss-linux-x86_64-0.7.0.39.tar.xz
cd cudss-linux-x86_64-0.7.0.39

# Copy files to CUDA installation (requires sudo)
sudo cp -r include/* /usr/local/cuda/include/
sudo cp -r lib64/* /usr/local/cuda/lib64/

# Update library cache
sudo ldconfig
```

### Step 3: Verify Installation

```bash
# Check header file exists
ls /usr/local/cuda/include/cudss.h

# Check library exists
ls /usr/local/cuda/lib64/libcudss.so*

# Re-run verification script
./scripts_linux/verify_build_environment.sh
```

## How CMake/Build System Finds cuDSS

The build system will automatically detect cuDSS through:

1. **Standard cuDSS installation** (Installer): `C:\Program Files\NVIDIA cuDSS\v*\`
2. **CUDA Toolkit integration** (Manual install): `%CUDA_PATH%\include\` and `%CUDA_PATH%\lib\x64\`
3. **CMAKE cuDSS package** (if installed via installer, it includes CMake config files)

No additional CMake configuration is needed - COLMAP/GLOMAP will automatically detect and use cuDSS if available.

## Troubleshooting

### Permission Denied (Windows)

If you get "Access Denied" when copying files:
1. Run PowerShell **as Administrator**
2. Or use the installer instead (recommended)

### Wrong CUDA Version

Make sure to download cuDSS version that matches your CUDA version:
- cuDSS 0.7.x supports CUDA 12.x and 13.x
- Check compatibility matrix at: https://docs.nvidia.com/cuda/cudss/index.html

**Check your CUDA version:**
```powershell
# Windows
nvcc --version
$env:CUDA_PATH

# Linux
nvcc --version
echo $CUDA_PATH
```

### Library Not Found at Runtime

**Good News:** The build scripts automatically copy cuDSS DLLs/libraries to the installation directory, so **no PATH configuration is needed** for builds created with this project!

The build scripts (`build_colmap.ps1`, `build_glomap.ps1`, etc.) automatically:
- Detect cuDSS installation location
- Copy cuDSS DLLs (Windows) or shared libraries (Linux) to `build/install/*/bin` or `build/install/*/lib`
- Make the installation self-contained

**If you still encounter runtime errors:**

**Windows:**
Ensure CUDA bin directory is in PATH (rare, usually not needed):
```powershell
$env:PATH -split ';' | Select-String "CUDA"

# If missing, add it:
$env:PATH += ";C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.8\bin"
```

**Linux:**
Ensure CUDA lib64 is in LD_LIBRARY_PATH (rare, usually not needed):
```bash
echo $LD_LIBRARY_PATH | grep cuda

# If missing, add to ~/.bashrc:
echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

## Performance Impact

With cuDSS installed, you should see:
- **2-5x faster** sparse bundle adjustment in COLMAP/GLOMAP
- Better GPU utilization during reconstruction
- Reduced memory usage for large-scale reconstructions
- Significantly faster iterative refinement

## Do I Really Need This?

**You can skip cuDSS if:**
- You only need CPU-based reconstruction (using `-NoCuda` flag)
- You're working with small datasets (< 100 images)
- You're just testing/learning
- You don't have an NVIDIA GPU

**You should install cuDSS if:**
- You're doing large-scale 3D reconstructions (> 500 images)
- Performance is critical
- You want to maximize GPU utilization
- You're running production workloads
- You're processing datasets daily

## Next Steps

After installing cuDSS:

1. **Verify installation:**
   ```bash
   .\scripts_windows\verify_build_environment.ps1
   ```

2. **Rebuild project to use cuDSS:**
   ```bash
   # Windows
   .\scripts_windows\build.ps1 -Clean -Configuration Release

   # Linux
   ./scripts_linux/build.sh --clean Release
   ```

3. **COLMAP/GLOMAP will automatically detect and use cuDSS** at runtime - no additional configuration needed!

## References

- [cuDSS Downloads](https://developer.nvidia.com/cudss-downloads)
- [cuDSS Documentation](https://docs.nvidia.com/cuda/cudss/index.html)
- [COLMAP CUDA Support](https://colmap.github.io/install.html#cuda-support)
- [GLOMAP Documentation](https://github.com/colmap/glomap)
