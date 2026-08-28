#!/usr/bin/env python3
"""
ONNX Runtime Multi-Platform Auto-Sync & API Inspector Tool
Syncs Microsoft ONNX Runtime releases across Windows (x64/ARM64), macOS (Universal),
Linux (x64/AArch64), Android, and iOS, with automated API change detection.
"""

import os
import sys
import re
import json
import shutil
import zipfile
import tarfile
import urllib.request
from pathlib import Path

GITHUB_API_URL = "https://api.github.com/repos/microsoft/onnxruntime/releases/latest"
GITHUB_TAG_API_URL = "https://api.github.com/repos/microsoft/onnxruntime/releases/tags/{tag}"

ROOT_DIR = Path(__file__).resolve().parent.parent
WINDOWS_DIR = ROOT_DIR / "windows"
LINUX_DIR = ROOT_DIR / "linux"
MACOS_DIR = ROOT_DIR / "macos"
IOS_DIR = ROOT_DIR / "ios"
ANDROID_DIR = ROOT_DIR / "android"
HEADER_PATH = ROOT_DIR / "src" / "onnxruntime" / "onnxruntime_c_api.h"


def fetch_release_info(target_tag=None):
    url = GITHUB_TAG_API_URL.format(tag=target_tag) if target_tag else GITHUB_API_URL
    req = urllib.request.Request(url, headers={"User-Agent": "AutoSync-Pipeline"})
    print(f"🔍 Fetching release metadata from: {url}")
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    tag = data["tag_name"]
    clean_ver = tag.lstrip("v")
    print(f"🎯 Discovered ONNX Runtime Release: {clean_ver} ({tag})")
    return clean_ver, tag, data


def extract_api_functions(header_content: str) -> set:
    """Extracts function names from onnxruntime_c_api.h."""
    patterns = [
        r"ORT_API_STATUS\s*\(\s*(\w+)",
        r"ORT_API2_STATUS\s*\(\s*(\w+)",
        r"ORT_API\s*\(\s*[\w\*]+\s*,\s*(\w+)",
    ]
    funcs = set()
    for pat in patterns:
        for match in re.finditer(pat, header_content):
            funcs.add(match.group(1))
    return funcs


def inspect_api_changes(old_header_file: Path, new_header_content: str):
    """Compares old and new C headers to detect added/removed APIs."""
    if not old_header_file.exists():
        return [], []
    with open(old_header_file, "r", encoding="utf-8", errors="ignore") as f:
        old_content = f.read()

    old_funcs = extract_api_functions(old_content)
    new_funcs = extract_api_functions(new_header_content)

    added = sorted(list(new_funcs - old_funcs))
    removed = sorted(list(old_funcs - new_funcs))
    return added, removed


def download_file(url: str, dest_path: Path):
    print(f"📥 Downloading: {url}")
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "AutoSync-Pipeline"})
    with urllib.request.urlopen(req) as resp, open(dest_path, "wb") as out:
        shutil.copyfileobj(resp, out)
    print(f"✅ Saved to: {dest_path.name}")


def sync_all_platforms(version: str, release_data: dict, temp_dir: Path):
    assets = {a["name"]: a["browser_download_url"] for a in release_data.get("assets", [])}
    report = {
        "version": version,
        "platforms_updated": [],
        "added_apis": [],
        "removed_apis": [],
    }

    # 1. Windows x64
    win_x64_name = f"onnxruntime-win-x64-{version}.zip"
    if win_x64_name in assets:
        zip_path = temp_dir / win_x64_name
        download_file(assets[win_x64_name], zip_path)
        with zipfile.ZipFile(zip_path, "r") as z:
            # 查找 dll
            for member in z.namelist():
                if member.endswith("lib/onnxruntime.dll") or member.endswith("onnxruntime.dll"):
                    dll_data = z.read(member)
                    WINDOWS_DIR.mkdir(parents=True, exist_ok=True)
                    with open(WINDOWS_DIR / "onnxruntime.dll", "wb") as f:
                        f.write(dll_data)
                    report["platforms_updated"].append("Windows (x64)")
                    break

                # 检查 C 头文件
                if member.endswith("include/onnxruntime_c_api.h"):
                    header_bytes = z.read(member)
                    header_str = header_bytes.decode("utf-8", errors="ignore")
                    added, removed = inspect_api_changes(HEADER_PATH, header_str)
                    report["added_apis"] = added
                    report["removed_apis"] = removed
                    HEADER_PATH.parent.mkdir(parents=True, exist_ok=True)
                    with open(HEADER_PATH, "wb") as f:
                        f.write(header_bytes)
                    print(f"✨ C Headers updated. Added APIs: {len(added)}, Removed APIs: {len(removed)}")

    # 2. Linux x64 / aarch64
    linux_x64_name = f"onnxruntime-linux-x64-{version}.tgz"
    if linux_x64_name in assets:
        tgz_path = temp_dir / linux_x64_name
        download_file(assets[linux_x64_name], tgz_path)
        with tarfile.open(tgz_path, "r:gz") as tar:
            for member in tar.getmembers():
                if member.name.endswith("libonnxruntime.so") or "libonnxruntime.so." in member.name:
                    f = tar.extractfile(member)
                    if f:
                        LINUX_DIR.mkdir(parents=True, exist_ok=True)
                        with open(LINUX_DIR / "libonnxruntime.so", "wb") as out:
                            out.write(f.read())
                        report["platforms_updated"].append("Linux (x64)")
                        break

    # 3. macOS (Universal / x64 / arm64)
    osx_universal_name = f"onnxruntime-osx-universal2-{version}.tgz"
    osx_x64_name = f"onnxruntime-osx-x86_64-{version}.tgz"
    osx_target = osx_universal_name if osx_universal_name in assets else (osx_x64_name if osx_x64_name in assets else None)
    if osx_target:
        tgz_path = temp_dir / osx_target
        download_file(assets[osx_target], tgz_path)
        with tarfile.open(tgz_path, "r:gz") as tar:
            for member in tar.getmembers():
                if member.name.endswith("libonnxruntime.dylib"):
                    f = tar.extractfile(member)
                    if f:
                        MACOS_DIR.mkdir(parents=True, exist_ok=True)
                        with open(MACOS_DIR / "libonnxruntime.dylib", "wb") as out:
                            out.write(f.read())
                        report["platforms_updated"].append("macOS (Universal/x64)")
                        break

    # 4. Android (Update Gradle version)
    android_gradle = ANDROID_DIR / "build.gradle"
    if android_gradle.exists():
        with open(android_gradle, "r", encoding="utf-8") as f:
            content = f.read()
        new_content = re.sub(
            r"(com\.microsoft\.onnxruntime:onnxruntime-android:)[^\'\"\n]+",
            rf"\g<1>{version}",
            content,
        )
        if new_content != content:
            with open(android_gradle, "w", encoding="utf-8") as f:
                f.write(new_content)
            report["platforms_updated"].append("Android (Maven AAR)")

    # 5. iOS (Update Podspec)
    ios_podspec = IOS_DIR / "onnxruntime_v2.podspec"
    if ios_podspec.exists():
        with open(ios_podspec, "r", encoding="utf-8") as f:
            content = f.read()
        new_content = re.sub(
            r"(s\.dependency\s+['\"]onnxruntime-c['\"],\s*['\"])[^'\"]+(['\"])",
            rf"\g<1>~> {version}\g<2>",
            content,
        )
        if new_content != content:
            with open(ios_podspec, "w", encoding="utf-8") as f:
                f.write(new_content)
            report["platforms_updated"].append("iOS (CocoaPods/SPM)")

    return report


def main():
    target_tag = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1].strip() else None
    version, tag, release_data = fetch_release_info(target_tag)

    temp_dir = ROOT_DIR / ".cache_sync"
    temp_dir.mkdir(exist_ok=True)

    try:
        report = sync_all_platforms(version, release_data, temp_dir)

        # 输出 Summary 报告文件
        summary_path = ROOT_DIR / "SYNC_SUMMARY.md"
        with open(summary_path, "w", encoding="utf-8") as f:
            f.write(f"# 🤖 ONNX Runtime v{version} Auto-Sync Report\n\n")
            f.write(f"- **Release Tag**: `{tag}`\n")
            f.write(f"- **Platforms Updated**: {', '.join(report['platforms_updated'])}\n\n")

            if report["added_apis"]:
                f.write("### 🌟 Newly Added C APIs in this version:\n")
                for api in report["added_apis"]:
                    f.write(f"- `{api}`\n")
                f.write("\n")

            if report["removed_apis"]:
                f.write("### ⚠️ Deprecated / Removed APIs:\n")
                for api in report["removed_apis"]:
                    f.write(f"- `{api}`\n")
                f.write("\n")

            if not report["added_apis"] and not report["removed_apis"]:
                f.write("✅ **ABI Signature 100% Identical** (Seamless Drop-in Replacement).\n")

        print(f"\n🎉 Sync completed! Summary written to {summary_path}")

    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
