#!/usr/bin/env python3
"""Emit a build_info.json provenance record for a COLMAP / pycolmap build.

Every released artifact ships one of these so it is fully self-describing and
reproducible: the exact COLMAP commit, the stamped version, the toolchain
(CUDA, cuDSS, host compiler + Windows SDK), and the feature flags it was built
with. Matrix-specific values are passed as flags; the rest (commit, compiler,
build date) are detected at runtime. Best-effort: anything that can't be
detected is recorded as null rather than failing the build.

Usage:
  python scripts/emit_build_info.py --output build/install/colmap/build_info.json \
      --colmap-dir third_party/colmap --os windows-2022 --variant "Windows CUDA12.8" \
      --cuda-version 12.8.1 --cudss-version 0.7.1.4 \
      --caspar true --cudss true --gui false --cuda-arch "75;80;86;89;90"
"""
import argparse
import json
import os
import platform
import re
import subprocess
import sys
from datetime import datetime, timezone


def _run(cmd):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return (p.stdout or "") + (p.stderr or "")
    except Exception:
        return ""


def _git_commit(repo_dir):
    return _run(["git", "-C", repo_dir, "rev-parse", "HEAD"]).strip() or None


def _read_release_version(cmakelists):
    try:
        with open(cmakelists, encoding="utf-8") as f:
            m = re.search(r'set\(COLMAP_RELEASE_VERSION "([^"]+)"', f.read())
            return m.group(1) if m else None
    except Exception:
        return None


def _host_compiler():
    info = {}
    if platform.system() == "Windows":
        # Prefer the toolset version vcvars exports; fall back to the cl banner.
        toolset = os.environ.get("VCToolsVersion")
        if not toolset:
            m = re.search(r"Version (\d+\.\d+\.\d+)", _run(["cl"]))
            toolset = m.group(1) if m else None
        info["msvc_toolset"] = toolset
        info["windows_sdk"] = (os.environ.get("WindowsSDKVersion") or "").strip("\\") or None
    else:
        info["gcc"] = (
            _run(["gcc", "-dumpfullversion"]).strip()
            or _run(["gcc", "-dumpversion"]).strip()
            or None
        )
    return info


def _bool(value):
    return str(value).lower() in ("1", "true", "on", "yes")


def main():
    ap = argparse.ArgumentParser(description="Emit build_info.json provenance metadata.")
    ap.add_argument("--output", required=True)
    ap.add_argument("--colmap-dir", default="third_party/colmap")
    ap.add_argument("--cmakelists", default="CMakeLists.txt")
    ap.add_argument("--os", default="")
    ap.add_argument("--variant", default="")
    ap.add_argument("--cuda-version", default="")
    ap.add_argument("--cudss-version", default="")
    ap.add_argument("--caspar", default="false")
    ap.add_argument("--cudss", default="false")
    ap.add_argument("--gui", default="false")
    ap.add_argument("--cuda-arch", default="")
    args = ap.parse_args()

    cuda_on = bool(args.cuda_version) and args.cuda_version.lower() != "none"
    info = {
        "schema": "build_info/v1",
        "build_date": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "colmap_commit": _git_commit(args.colmap_dir),
        "colmap_version": _read_release_version(args.cmakelists),
        "pcl_tools_commit": os.environ.get("GITHUB_SHA") or _git_commit("."),
        "os": args.os or None,
        "runner_image": os.environ.get("ImageVersion") or None,
        "variant": args.variant or None,
        "cuda": {
            "enabled": cuda_on,
            "version": args.cuda_version if cuda_on else None,
            "arch": (args.cuda_arch or None) if cuda_on else None,
        },
        "cudss": {
            "enabled": _bool(args.cudss),
            "version": args.cudss_version or None,
        },
        "features": {
            "caspar": _bool(args.caspar),
            "gui": _bool(args.gui),
        },
        "host_compiler": _host_compiler(),
    }

    out_dir = os.path.dirname(os.path.abspath(args.output))
    os.makedirs(out_dir, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2)
        f.write("\n")
    print(json.dumps(info, indent=2))


if __name__ == "__main__":
    sys.exit(main())
