# GLOMAP and COLMAP Version Management

## Problem

GLOMAP depends on a specific version of COLMAP (commit 78f1eefa from COLMAP 3.11), but users may also want to use the latest COLMAP version for general development and standalone use.

## Solution: Dual COLMAP Build

This repository builds **TWO separate versions of COLMAP**:

### 1. Latest COLMAP
- **Location**: `third_party/colmap/`
- **Purpose**: Standalone use, general development, latest features
- **Version**: Tracks latest main branch
- **Built when**: `BUILD_COLMAP=ON` (default)

### 2. COLMAP for GLOMAP
- **Location**: `third_party/colmap-for-glomap/`
- **Purpose**: GLOMAP dependency only
- **Version**: Pinned to commit 78f1eefa (COLMAP 3.11)
- **Built when**: `BUILD_GLOMAP=ON` (default)
- **CMake flag**: Built as `EXCLUDE_FROM_ALL` (only built when needed by GLOMAP)

## Automatic Version Synchronization

The build system includes automatic version synchronization scripts that ensure COLMAP-for-GLOMAP is always at the correct version:

### How It Works

1. **During Build**: When GLOMAP is being built, the build script automatically runs `sync_colmap_for_glomap` script
2. **Version Detection**: The sync script reads GLOMAP's `cmake/FindDependencies.cmake` to find the expected COLMAP commit
3. **Auto-Checkout**: If `colmap-for-glomap` is not at the correct version, it automatically checks out the correct commit
4. **Verification**: Verifies the update was successful before proceeding with the build

### Build Scripts Behavior

**Windows (`build.ps1`):**
```powershell
# Default behavior - builds GLOMAP with auto-sync
.\scripts_windows\build.ps1 -Configuration Release

# Skip GLOMAP build and sync
.\scripts_windows\build.ps1 -Configuration Release -NoGlomap
```

**Linux (`build.sh`):**
```bash
# Default behavior - builds GLOMAP with auto-sync
./scripts_linux/build.sh Release

# Skip GLOMAP build and sync
./scripts_linux/build.sh Release --no-glomap
```

### Sync Scripts

You can manually run the sync scripts if needed:

**Windows:**
```powershell
.\scripts_windows\sync_colmap_for_glomap.ps1

# Force update even if already at correct version
.\scripts_windows\sync_colmap_for_glomap.ps1 -Force
```

**Linux:**
```bash
./scripts_linux/sync_colmap_for_glomap.sh

# Force update even if already at correct version
./scripts_linux/sync_colmap_for_glomap.sh --force
```

## Build Order

The CMakeLists.txt builds components in this order:

```
1. Ceres Solver (base dependency)
   |
   +-> 2. PoseLib (depends on Ceres)
   |
   +-> 3. COLMAP Latest (depends on Ceres)
   |
   +-> 4. COLMAP for GLOMAP 3.11 (depends on Ceres, EXCLUDE_FROM_ALL)
   |
   +-> 5. GLOMAP (depends on COLMAP-for-GLOMAP and PoseLib)
   |
   +-> 6. PyCeres (depends on Ceres)
```

## CMake Configuration

The CMakeLists.txt includes special handling for the dual COLMAP setup:

```cmake
# Step 3: Build COLMAP (latest version - depends on Ceres)
if(BUILD_COLMAP)
    message(STATUS "Building COLMAP (latest)...")
    add_subdirectory(third_party/colmap)
endif()

# Step 4: Build COLMAP for GLOMAP (pinned to commit 78f1eefa - COLMAP 3.11)
# This is built separately to ensure GLOMAP compatibility
if(BUILD_GLOMAP)
    message(STATUS "Building COLMAP for GLOMAP (v3.11 - commit 78f1eefa)...")
    set(FETCH_COLMAP OFF CACHE BOOL "Disable COLMAP fetch in GLOMAP")
    add_subdirectory(third_party/colmap-for-glomap EXCLUDE_FROM_ALL)
endif()

# Step 5: Build GLOMAP (depends on COLMAP-for-GLOMAP and PoseLib)
if(BUILD_GLOMAP)
    message(STATUS "Building GLOMAP...")
    add_subdirectory(third_party/glomap)
endif()
```

**Key Points:**
- `FETCH_COLMAP=OFF` prevents GLOMAP from trying to fetch its own COLMAP
- `EXCLUDE_FROM_ALL` means COLMAP-for-GLOMAP is only built when needed by GLOMAP
- Latest COLMAP can be built independently without GLOMAP

## Sync Script Details

### What the Sync Script Does

1. **Reads GLOMAP's Expected Version**:
   - Parses `third_party/glomap/cmake/FindDependencies.cmake`
   - Extracts the `GIT_TAG` from the `FetchContent_Declare(COLMAP ...)` block
   - Expected format: 40-character commit hash

2. **Checks Current Version**:
   - Gets the current commit hash in `third_party/colmap-for-glomap/`
   - Compares with expected version

3. **Updates If Needed**:
   - Fetches latest commits from COLMAP repository
   - Checks out the expected commit
   - Verifies the update was successful

4. **Reports Status**:
   - Shows expected commit, current commit, and commit message
   - Provides clear success/failure feedback

### Error Handling

The sync script handles several error conditions:

- **Missing submodules**: Suggests running `git submodule update --init --recursive`
- **Commit not found**: Reports if the expected commit doesn't exist in the repository
- **Checkout failure**: Reports failure and suggests manual intervention
- **Verification mismatch**: Reports if final commit doesn't match expected

If the sync fails, the build continues with a warning, but GLOMAP compatibility is not guaranteed.

## Manual Version Management

If you need to manually manage versions:

### Check Current Versions

```bash
# Check COLMAP latest version
cd third_party/colmap
git log -1 --oneline

# Check COLMAP for GLOMAP version
cd third_party/colmap-for-glomap
git log -1 --oneline

# Check what GLOMAP expects
grep -A 5 "FetchContent_Declare(COLMAP" third_party/glomap/cmake/FindDependencies.cmake
```

### Manually Update COLMAP for GLOMAP

```bash
cd third_party/colmap-for-glomap
git fetch origin
git checkout 78f1eefacae542d753c2e4f6a26771a0d976227d
cd ../..
```

### Update to Different GLOMAP Version

If you update GLOMAP to a newer version that expects a different COLMAP commit:

1. Update GLOMAP:
   ```bash
   cd third_party/glomap
   git pull origin main
   cd ../..
   ```

2. Run sync script (it will auto-detect the new expected version):
   ```bash
   # Windows
   .\scripts_windows\sync_colmap_for_glomap.ps1

   # Linux
   ./scripts_linux/sync_colmap_for_glomap.sh
   ```

3. Build:
   ```bash
   # Windows
   .\scripts_windows\build.ps1 -Clean -Configuration Release

   # Linux
   ./scripts_linux/build.sh --clean Release
   ```

## Troubleshooting

### GLOMAP Build Fails with COLMAP Version Mismatch

**Symptom**: GLOMAP fails to build with errors about missing COLMAP functions or incompatible APIs

**Solution**:
1. Run the sync script manually:
   ```bash
   # Windows
   .\scripts_windows\sync_colmap_for_glomap.ps1 -Force

   # Linux
   ./scripts_linux/sync_colmap_for_glomap.sh --force
   ```

2. Clean and rebuild:
   ```bash
   # Windows
   .\scripts_windows\build.ps1 -Clean -Configuration Release

   # Linux
   ./scripts_linux/build.sh --clean Release
   ```

### Sync Script Reports "Commit Not Found"

**Symptom**: Sync script says the expected commit doesn't exist

**Possible Causes**:
- COLMAP-for-GLOMAP submodule is not fully cloned
- GLOMAP expects a very new or very old COLMAP version

**Solution**:
1. Update submodules:
   ```bash
   git submodule update --init --recursive
   ```

2. Fetch all COLMAP history:
   ```bash
   cd third_party/colmap-for-glomap
   git fetch --unshallow origin
   cd ../..
   ```

3. Re-run sync script

### Building Without GLOMAP

If you only want to build COLMAP (latest) without GLOMAP:

```bash
# Windows
.\scripts_windows\build.ps1 -Configuration Release -NoGlomap

# Linux
./scripts_linux/build.sh Release --no-glomap
```

This skips:
- COLMAP-for-GLOMAP build
- GLOMAP build
- Version synchronization (faster)

## Benefits of This Approach

1. **No Manual Intervention**: Version sync is automatic during build
2. **Always Compatible**: GLOMAP always gets the COLMAP version it expects
3. **Latest Features Available**: Users can use the latest COLMAP for standalone work
4. **No Conflicts**: Two separate builds mean no version conflicts
5. **Future-Proof**: If GLOMAP updates to expect a newer COLMAP, sync script auto-detects and updates

## References

- GLOMAP COLMAP dependency: `third_party/glomap/cmake/FindDependencies.cmake`
- COLMAP 3.11 release: https://github.com/colmap/colmap/releases/tag/3.11
- Build order documentation: `docs/BUILD_ANALYSIS.md`
