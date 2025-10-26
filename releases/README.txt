================================================================================
                    COLMAP GPU Builder - Release Package
================================================================================

This directory contains packaged builds ready for GitHub release.

CONTENTS:
---------
1. COLMAP-3.13-dev-Windows-x64-CUDA.zip (79 MB)
   - COLMAP 3.13.0.dev0 (latest development) with CUDA support
   - All dependencies bundled
   - Latest features and improvements

2. GLOMAP-Windows-x64-CUDA.zip (13 MB)
   - GLOMAP fast global SfM with CUDA support
   - Self-contained with all dependencies (COLMAP 3.11, Ceres, PoseLib)
   - No additional dependencies required

3. pycolmap-3.13.0.dev0-cp310-cp310-win_amd64.whl (571 MB)
   - Python 3.10 wheel with all dependencies

4. pycolmap-3.13.0.dev0-cp311-cp311-win_amd64.whl (571 MB)
   - Python 3.11 wheel with all dependencies

5. pycolmap-3.13.0.dev0-cp312-cp312-win_amd64.whl (571 MB)
   - Python 3.12 wheel with all dependencies

TOTAL SIZE: ~1.8 GB

CREATING THE RELEASE:
--------------------

Option 1: Automated (Recommended)
----------------------------------
1. Authenticate with GitHub CLI:
   > "C:\Program Files\GitHub CLI\gh.exe" auth login

2. Run the release script from project root:
   > .\scripts_windows\create_github_release.ps1

3. Follow the prompts


Option 2: Manual Upload
------------------------
1. Go to: https://github.com/lyehe/build_gpu_colmap/releases/new

2. Create a new tag: v1.0.0

3. Set release title: COLMAP GPU Builder v1.0.0 - Windows CUDA Build

4. Copy the content from RELEASE_NOTES.md into the description

5. Upload all files:
   - COLMAP-3.13-dev-Windows-x64-CUDA.zip
   - GLOMAP-Windows-x64-CUDA.zip
   - pycolmap-3.13.0.dev0-cp310-cp310-win_amd64.whl
   - pycolmap-3.13.0.dev0-cp311-cp311-win_amd64.whl
   - pycolmap-3.13.0.dev0-cp312-cp312-win_amd64.whl

6. Click "Publish release"


Option 3: Command Line (One-liner)
-----------------------------------
After authenticating with gh CLI:

"C:\Program Files\GitHub CLI\gh.exe" release create v1.0.0 ^
  --title "COLMAP GPU Builder v1.0.0 - Windows CUDA Build" ^
  --notes-file RELEASE_NOTES.md ^
  --repo YOUR-USERNAME/colmap-gpu-builder ^
  COLMAP-3.13-dev-Windows-x64-CUDA.zip ^
  GLOMAP-Windows-x64-CUDA.zip ^
  pycolmap-3.13.0.dev0-cp310-cp310-win_amd64.whl ^
  pycolmap-3.13.0.dev0-cp311-cp311-win_amd64.whl ^
  pycolmap-3.13.0.dev0-cp312-cp312-win_amd64.whl


NOTES:
------
- The upload may take several minutes due to file size
- Ensure you have a stable internet connection
- The release will be publicly visible on GitHub
- You can edit the release later if needed

================================================================================
