#!/usr/bin/env python3
"""Build the isolated Chromium-compatible Skia Metal pixel backend."""

import argparse
import hashlib
import os
from pathlib import Path
import platform
import posixpath
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request

# Chromium 155.0.8059.80 DEPS. Keep this separate from LibWeb's Skia ABI.
REVISION = "29ed1e87a0a50f3d8347e988842d9d59e7573efa"
SHA512 = ("ba6e08942dcdd36a49f2a91d724c8e7be35d4ced30f259e3259ad1d3b24c4c140"
          "a3da1a1dd44170b985975fa5fca2871a147684e8f20ce7572bc334f3a024458")
PATCH_INPUTS = {
    "src/gpu/graphite/UniformManager.h": (
        "9556b5330a6b40c38ce8db502322c0f173b20f4f76536b3f5e2c0d437b220281",
        "1570dc4bb9152b1325ebd6c805e42da2b957a19cb6221dece487df486b05cfe6"),
    "src/sksl/SkSLMemoryLayout.h": (
        "a25abc8b2fe1e9ab3e382d73f97fef486d05f3e46d578f6310fd71161a3aa577",
        "fa91fe6d9e448e04c136fc0756710105bfe9e91c880a67d07ca6f79da0a10a72"),
    "src/gpu/graphite/mtl/MtlGraphiteUtils.mm": (
        "dbf4db49c1a09e7c80a3107cec108b1c76e8d99551d429c5f268b45a8096f76d",
        "f8e0e89321a5877e35e5ef7a9427299c91cd5a1999c40a64fc06025e13a00ec7"),
}
LEGACY_MSL_SHA256 = "761dc0b22373b425120adda011b9d74c40ca572ec7c179bfd3979c5c09554a23"
HOST_STATIC_SOURCE = "src/gpu/graphite/BufferManager.cpp"
HOST_STATIC_ORIGINAL = "f81fc38e9865febc986b57d60931315e89a4c610db068c35b32d3a9a7fa27065"
HOST_STATIC_PATCHED = "91bd83a86b06e0930b2d09895650946b2e3f5513c9b97f229a1b6df89f59fbc6"


def extract_skia_archive(archive, destination):
    """Extract the pinned archive, allowing links confined to its single root."""
    with tarfile.open(archive) as bundle:
        for member in bundle.getmembers():
            path = Path(member.name)
            if (path.is_absolute() or ".." in path.parts
                    or not path.parts or path.parts[0] != f"skia-{REVISION}"):
                raise SystemExit("Unexpected Skia archive member")
            if member.issym() or member.islnk():
                target = (posixpath.join(str(path.parent), member.linkname)
                          if member.issym() else member.linkname)
                normalized = Path(posixpath.normpath(target))
                if (normalized.is_absolute() or not normalized.parts
                        or normalized.parts[0] != f"skia-{REVISION}"):
                    raise SystemExit("Unexpected Skia archive link")
        bundle.extractall(destination)


def prepare_precision_patch(source, archive, patch):
    """Apply the pinned patch or upgrade the previous, authenticated patch."""
    actual = {name: hashlib.sha256((source / name).read_bytes()).hexdigest()
              for name in PATCH_INPUTS}
    original = {name: hashes[0] for name, hashes in PATCH_INPUTS.items()}
    patched = {name: hashes[1] for name, hashes in PATCH_INPUTS.items()}
    legacy = dict(patched)
    legacy["src/gpu/graphite/mtl/MtlGraphiteUtils.mm"] = LEGACY_MSL_SHA256
    if actual == patched:
        return
    if actual != original and actual != legacy:
        raise SystemExit("Unexpected or partially patched Skia dependency")
    # Stage and authenticate every result before modifying the private checkout.
    with tempfile.TemporaryDirectory(prefix="vox-skia-precision-") as temporary:
        staged = Path(temporary)
        with tarfile.open(archive) as bundle:
            for name, digest in original.items():
                contents = bundle.extractfile(f"skia-{REVISION}/{name}").read()
                if hashlib.sha256(contents).hexdigest() != digest:
                    raise SystemExit(f"Unexpected original Skia source: {name}")
                target = staged / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(contents)
        subprocess.run(["patch", "--batch", "--fuzz=0", "-p1", "-i", str(patch)],
                       cwd=staged, check=True)
        for name, digest in patched.items():
            if hashlib.sha256((staged / name).read_bytes()).hexdigest() != digest:
                raise SystemExit(f"Unexpected patched Skia source: {name}")
        for name in PATCH_INPUTS:
            (source / name).write_bytes((staged / name).read_bytes())


def executable(name, fallback=None):
    value = os.environ.get(name.upper()) or shutil.which(name)
    if not value and fallback and fallback.is_file():
        value = str(fallback)
    if not value:
        raise SystemExit(f"Missing {name}; install GN and Ninja to build the Metal backend")
    return value


def prepare_host_static_patch(source, archive, patch):
    """Authenticate the small Metal static-mesh upload patch before installing it."""
    target = source / HOST_STATIC_SOURCE
    actual = hashlib.sha256(target.read_bytes()).hexdigest()
    if actual == HOST_STATIC_PATCHED:
        return
    if actual != HOST_STATIC_ORIGINAL:
        raise SystemExit("Unexpected Skia static-buffer source")
    with tempfile.TemporaryDirectory(prefix="vox-skia-host-static-") as temporary:
        staged = Path(temporary)
        with tarfile.open(archive) as bundle:
            contents = bundle.extractfile(f"skia-{REVISION}/{HOST_STATIC_SOURCE}").read()
        if hashlib.sha256(contents).hexdigest() != HOST_STATIC_ORIGINAL:
            raise SystemExit("Unexpected original Skia static-buffer source")
        candidate = staged / HOST_STATIC_SOURCE
        candidate.parent.mkdir(parents=True)
        candidate.write_bytes(contents)
        subprocess.run(["patch", "--batch", "--fuzz=0", "-p1", "-i", str(patch)],
                       cwd=staged, check=True)
        contents = candidate.read_bytes()
        if hashlib.sha256(contents).hexdigest() != HOST_STATIC_PATCHED:
            raise SystemExit("Unexpected patched Skia static-buffer source")
        target.write_bytes(contents)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--skia-root", required=True, type=Path)
    args = parser.parse_args()
    if platform.system() != "Darwin":
        raise SystemExit("This backend requires macOS")
    repo = Path(__file__).resolve().parent.parent
    root = repo / "Build/deps/skia-brave"
    root.mkdir(parents=True, exist_ok=True)
    archive = root / f"{REVISION}.tar.gz"
    if not archive.is_file():
        temporary = archive.with_suffix(".tmp")
        urllib.request.urlretrieve(
            f"https://codeload.github.com/google/skia/tar.gz/{REVISION}", temporary)
        temporary.replace(archive)
    if hashlib.sha512(archive.read_bytes()).hexdigest() != SHA512:
        raise SystemExit(f"Skia archive checksum mismatch: {archive}")
    source = root / "source"
    stamp = source / ".vox-revision"
    if not source.exists():
        extract_skia_archive(archive, root)
        (root / f"skia-{REVISION}").rename(source)
        stamp.write_text(REVISION + "\n")
    elif not stamp.is_file() or stamp.read_text().strip() != REVISION:
        raise SystemExit(f"Unrecognized Skia source tree: {source}")

    # Dawn/Metal in Chromium disables ShaderF16. Native Metal otherwise uses
    # half uniforms and arithmetic. Promote both the uniforms and generated
    # MSL together; changing just one corrupts shader bindings. The patch is
    # confined to this private, revision-pinned dependency.
    prepare_precision_patch(source, archive, repo / "tools/skia_chromium_metal.patch")
    prepare_host_static_patch(source, archive, repo / "tools/skia_metal_host_static.patch")

    gn = executable("gn", args.skia_root / "tools/gn/gn")
    ninja = executable("ninja")
    cpu = {"arm64": "arm64", "x86_64": "x64"}.get(platform.machine())
    if not cpu:
        raise SystemExit(f"Unsupported macOS architecture: {platform.machine()}")
    disabled = ["tools", "ganesh", "pdf", "gpu_debug_layers"]
    unused = ["gl", "dawn", "vulkan", "icu", "harfbuzz", "freetype", "fontconfig",
              "wuffs", "piex", "dng_sdk", "expat", "libavif", "libjpeg_turbo_decode",
              "libjpeg_turbo_encode", "libpng_decode", "libpng_encode", "libwebp_decode",
              "libwebp_encode", "zlib", "lua", "perfetto", "fonthost_mac", "partition_alloc"]
    gn_args = ["is_official_build=true", "is_debug=false", f'target_cpu="{cpu}"',
               'cc="clang"', 'cxx="clang++"',
               "skia_enable_graphite=true", "skia_use_metal=true",
               'extra_cflags=["-fPIC","-fvisibility=hidden",'
               '"-DSK_GRAPHITE_USE_LEGACY_RRECT_CLIP_SHADER",'
               '"-DSK_SUPPORT_LEGACY_RRECT_TRANSFORM",'
               '"-DSK_SUPPORT_LEGACY_ANISOTROPIC_MIPMAP_SCALE"]']
    gn_args += [f"skia_enable_{name}=false" for name in disabled]
    gn_args += [f"skia_use_{name}=false" for name in unused]
    subprocess.run([gn, "gen", "out/Release", "--args=" + " ".join(gn_args)],
                   cwd=source, check=True)
    subprocess.run([ninja, "-C", "out/Release", "-j", os.environ.get("JOBS", "8"), "skia"],
                   cwd=source, check=True)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        "clang++", "-std=c++20", "-O2", "-fPIC", "-dynamiclib", "-fvisibility=hidden",
        "-fvisibility-inlines-hidden", "-mmacosx-version-min=14.0", "-DSK_GRAPHITE",
        "-DSK_GRAPHITE_USE_LEGACY_RRECT_CLIP_SHADER", "-I" + str(source),
        str(repo / "native_graphite_darwin.mm"), "-L" + str(source / "out/Release"),
        "-Wl,-hidden-lskia", "-Wl,-hidden-lskcms", "-framework", "Metal",
        "-framework", "CoreGraphics", "-framework", "Foundation", "-framework", "ImageIO",
        "-framework", "IOSurface",
        "-Wl,-exported_symbol,_vox_graphite_draw_shadow_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_image_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_direct_image_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_image_region_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_image_regions_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_image_tiles",
        "-Wl,-exported_symbol,_vox_graphite_resize_rgba_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_shape_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_shape_region_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_shape_regions_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_rounded_parts_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_path_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_dashed_path_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_path_region_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_shadow_region_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_path_parts_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_path_batch_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_svg_image_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_svg_image_region_pixels",
        "-Wl,-exported_symbol,_vox_graphite_draw_svg_pattern_pixels",
        "-Wl,-exported_symbol,_vox_graphite_prepare_webp_icc_rgba",
        "-Wl,-exported_symbol,_vox_graphite_supports_yuv422",
        "-Wl,-exported_symbol,_vox_graphite_release_unused_graphics_memory",
        "-Wl,-exported_symbol,_vox_graphite_release_idle_graphics_memory",
        "-Wl,-exported_symbol,_vox_graphite_retire_graphics_context",
        "-Wl,-exported_symbol,_vox_graphite_finish_frame",
        "-Wl,-exported_symbol,_vox_graphite_canvas_begin",
        "-Wl,-exported_symbol,_vox_graphite_canvas_begin_native_grid",
        "-Wl,-exported_symbol,_vox_graphite_canvas_upload",
        "-Wl,-exported_symbol,_vox_graphite_canvas_draw_shadow",
        "-Wl,-exported_symbol,_vox_graphite_canvas_draw_shape",
        "-Wl,-exported_symbol,_vox_graphite_canvas_read",
        "-Wl,-exported_symbol,_vox_graphite_canvas_read_direct",
        "-Wl,-exported_symbol,_vox_graphite_canvas_read_iosurface",
        "-Wl,-exported_symbol,_vox_graphite_canvas_draw_pixels",
        "-Wl,-exported_symbol,_vox_graphite_canvas_draw_layer_pixels",
        "-Wl,-exported_symbol,_vox_graphite_canvas_copy_pixels",
        "-Wl,-exported_symbol,_vox_graphite_canvas_draw_path",
        "-Wl,-exported_symbol,_vox_graphite_canvas_draw_image",
        "-Wl,-exported_symbol,_vox_graphite_canvas_draw_image_msaa",
        "-Wl,-exported_symbol,_vox_graphite_canvas_draw_shape_msaa",
        "-Wl,-exported_symbol,_vox_graphite_canvas_draw_shape_native_grid",
        "-Wl,-exported_symbol,_vox_graphite_canvas_draw_shape_isolated",
        "-Wl,-exported_symbol,_vox_graphite_canvas_draw_picture",
        "-Wl,-exported_symbol,_vox_graphite_canvas_end",
        "-Wl,-install_name,@rpath/libVoxGraphite.dylib", "-o", str(args.output)], check=True)
    print(f"Built isolated Skia Metal backend: {args.output}")


if __name__ == "__main__":
    main()
