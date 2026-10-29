#!/usr/bin/env python3
"""Build the pinned Chromium Dawn/Metal picture rasterizer, independently of LibWeb's Skia."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import os
from pathlib import Path
import subprocess
import sys

from build_mac_graphite import REVISION, SHA512, executable, extract_skia_archive

DAWN_REVISION = '42d0e90fe3552a2a8e95ca8e506bc19bbda12729'
DEPENDENCIES = [
    ('dawn', 'https://dawn.googlesource.com/dawn.git', DAWN_REVISION),
    ('abseil-cpp', 'https://chromium.googlesource.com/chromium/src/third_party/abseil-cpp',
     '2d78d7ce09549caca58fc28b442bbad3a19da432'),
    ('spirv-headers', 'https://chromium.googlesource.com/external/github.com/KhronosGroup/SPIRV-Headers',
     '04fd3caa1e8267e4d95c806cad901181728e1006'),
    ('webgpu-headers', 'https://chromium.googlesource.com/external/github.com/webgpu-native/webgpu-headers',
     'b5ff182caa90e53293f47939716281342c0812ba'),
]


def checkout(item, external):
    name, url, revision = item
    target = external / name
    if (target / '.git').exists():
        actual = subprocess.check_output(['git', '-C', str(target), 'rev-parse', 'HEAD'], text=True).strip()
        if actual != revision:
            raise RuntimeError(f'Unexpected {name} revision: {actual}')
        if subprocess.run(['git', '-C', str(target), 'diff', '--quiet'], check=False).returncode:
            raise RuntimeError(f'Unexpected tracked changes in dependency: {name}')
        return
    if target.exists():
        raise RuntimeError(f'Unrecognized dependency directory: {target}')
    subprocess.run(['git', 'init', str(target)], check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['git', '-C', str(target), 'fetch', '--depth=1', url, revision], check=True)
    subprocess.run(['git', '-C', str(target), 'checkout', '--detach', 'FETCH_HEAD'], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--skia-root', required=True, type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parent.parent
    root = (repo / 'Build/deps/skia-brave-dawn').resolve()
    root.mkdir(parents=True, exist_ok=True)
    source = root / 'source'
    if not source.exists():
        archive = repo / 'Build/deps/skia-brave' / f'{REVISION}.tar.gz'
        if not archive.is_file() or hashlib.sha512(archive.read_bytes()).hexdigest() != SHA512:
            raise RuntimeError('Build the pinned native Metal backend before the Dawn backend')
        extract_skia_archive(archive, root)
        (root / f'skia-{REVISION}').rename(source)
    external = source / 'third_party/externals'
    external.mkdir(exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(lambda item: checkout(item, external), DEPENDENCIES))

    python = root / 'python/bin/python3'
    if not python.is_file():
        subprocess.run([sys.executable, '-m', 'venv', str(root / 'python')], check=True)
    installed = subprocess.run([str(python), '-c', 'import jinja2, markupsafe'], capture_output=True)
    if installed.returncode:
        subprocess.run([str(python), '-m', 'pip', 'install', 'Jinja2==3.1.6', 'MarkupSafe==3.0.3'], check=True)
    site = subprocess.check_output([str(python), '-c', 'import site; print(site.getsitepackages()[0])'], text=True).strip()
    build = root / 'dawn-build'
    cmake_args = [
        'cmake', '-S', str(external / 'dawn'), '-B', str(build), '-G', 'Ninja',
        '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_CXX_STANDARD=20',
        '-DCMAKE_CXX_COMPILER=clang++', '-DCMAKE_C_COMPILER=clang',
        '-DCMAKE_OSX_DEPLOYMENT_TARGET=14.0', '-DCMAKE_POSITION_INDEPENDENT_CODE=ON',
        '-DCMAKE_CXX_FLAGS=-fvisibility=hidden -fvisibility-inlines-hidden',
        '-DCMAKE_C_FLAGS=-fvisibility=hidden', '-DPython3_EXECUTABLE=' + str(python),
        '-DDAWN_BUILD_MONOLITHIC_LIBRARY=STATIC', '-DDAWN_ENABLE_METAL=ON',
        '-DDAWN_ABSEIL_DIR=' + str(external / 'abseil-cpp'),
        '-DDAWN_SPIRV_HEADERS_DIR=' + str(external / 'spirv-headers'),
        '-DDAWN_WEBGPU_HEADERS_DIR=' + str(external / 'webgpu-headers'),
        '-DDAWN_JINJA2_DIR=' + site, '-DDAWN_MARKUPSAFE_DIR=' + site,
    ]
    disabled = ['DAWN_FETCH_DEPENDENCIES', 'DAWN_ENABLE_D3D11', 'DAWN_ENABLE_D3D12',
                'DAWN_ENABLE_DESKTOP_GL', 'DAWN_ENABLE_OPENGLES', 'DAWN_ENABLE_VULKAN',
                'DAWN_ENABLE_NULL', 'DAWN_ENABLE_SPIRV_VALIDATION', 'DAWN_BUILD_TESTS',
                'DAWN_BUILD_SAMPLES', 'DAWN_BUILD_BENCHMARKS', 'DAWN_BUILD_PROTOBUF',
                'DAWN_USE_GLFW', 'DAWN_ENABLE_INSTALL', 'TINT_ENABLE_INSTALL',
                'TINT_BUILD_TESTS', 'TINT_BUILD_CMD_TOOLS', 'TINT_BUILD_IR_BINARY',
                'TINT_BUILD_GLSL_WRITER', 'TINT_BUILD_GLSL_VALIDATOR',
                'TINT_BUILD_HLSL_WRITER', 'TINT_BUILD_SPV_WRITER', 'TINT_BUILD_SPV_READER']
    subprocess.run(cmake_args + ['-D' + item + '=OFF' for item in disabled], check=True)
    ninja = executable('ninja')
    jobs = os.environ.get('JOBS', '8')
    subprocess.run([ninja, '-C', str(build), '-j', jobs, 'webgpu_dawn'], check=True)

    # Link Skia to the monolithic Dawn library instead of building a second Dawn
    # dependency graph through GN. All other optional image/font backends stay off.
    (source / 'third_party/dawn/BUILD.gn').write_text(f'''config("dawn_api_config") {{
  include_dirs = ["../externals/dawn", "../externals/dawn/include", "{build}/gen/include", "{build}/gen"]
  libs = ["{build}/src/dawn/native/libwebgpu_dawn.a"]
  frameworks = ["Foundation.framework", "IOSurface.framework", "IOKit.framework", "Metal.framework", "QuartzCore.framework", "Cocoa.framework"]
}}
group("dawn") {{ public_configs = [":dawn_api_config"] }}
group("tint") {{ public_configs = [":dawn_api_config"] }}
''')
    gn_args = ['is_official_build=true', 'is_debug=false',
               'target_cpu="' + ('arm64' if os.uname().machine == 'arm64' else 'x64') + '"',
               'cc="clang"', 'cxx="clang++"', 'skia_enable_graphite=true',
               'skia_use_dawn=true', 'skia_use_metal=false', 'skia_use_fonthost_mac=true',
               # Chromium's macOS skia/BUILD.gn omits the standalone GN
               # build's A8 gamma adjustment and uses zero text contrast.
               # The adjustment also changes distance-field glyph coverage.
               'extra_cflags=["-fPIC","-fvisibility=hidden","-USK_GAMMA_APPLY_TO_A8","-DSK_GAMMA_CONTRAST=0.0f","-DSK_GRAPHITE_USE_LEGACY_RRECT_CLIP_SHADER","-DSK_SUPPORT_LEGACY_ANISOTROPIC_MIPMAP_SCALE"]']
    gn_args += ['skia_enable_' + item + '=false' for item in ['tools', 'ganesh', 'pdf', 'gpu_debug_layers']]
    unused = ['gl', 'vulkan', 'icu', 'harfbuzz', 'freetype', 'fontconfig', 'wuffs', 'piex',
              'dng_sdk', 'expat', 'libavif', 'libjpeg_turbo_decode', 'libjpeg_turbo_encode',
              'libpng_decode', 'libpng_encode', 'libwebp_decode', 'libwebp_encode', 'zlib',
              'lua', 'perfetto', 'partition_alloc']
    gn_args += ['skia_use_' + item + '=false' for item in unused]
    gn = executable('gn', args.skia_root / 'tools/gn/gn')
    subprocess.run([gn, 'gen', 'out/Release', '--args=' + ' '.join(gn_args)], cwd=source, check=True)
    subprocess.run([ninja, '-C', 'out/Release', '-j', jobs, 'skia'], cwd=source, check=True)
    release = source / 'out/Release'
    args.output.parent.mkdir(parents=True, exist_ok=True)
    command = ['clang++', '-std=c++20', '-O2', '-DNDEBUG', '-fno-rtti', '-fPIC', '-dynamiclib',
               '-fvisibility=hidden', '-fvisibility-inlines-hidden', '-mmacosx-version-min=14.0',
               '-DSK_GRAPHITE', '-DSK_DAWN', '-DSK_GRAPHITE_USE_LEGACY_RRECT_CLIP_SHADER',
               '-I' + str(repo), '-I' + str(source), '-I' + str(external / 'dawn/include'),
               '-I' + str(build / 'gen/include'), str(repo / 'native_graphite_dawn_darwin.mm'),
               '-L' + str(release), '-L' + str(build / 'src/dawn/native'),
               '-Wl,-hidden-lskia', '-Wl,-hidden-lskcms', '-Wl,-hidden-lwebgpu_dawn']
    for framework in ['CoreText', 'Metal', 'CoreGraphics', 'Foundation', 'ImageIO', 'IOSurface', 'IOKit', 'QuartzCore', 'Cocoa']:
        command += ['-framework', framework]
    command += ['-Wl,-exported_symbol,_vox_graphite_draw_picture_pixels',
                '-Wl,-exported_symbol,_vox_graphite_picture_release_unused_graphics_memory',
                '-Wl,-exported_symbol,_vox_graphite_picture_release_idle_graphics_memory',
                '-Wl,-install_name,@rpath/libVoxGraphiteDawn.dylib', '-o', str(args.output)]
    subprocess.run(command, check=True)


if __name__ == '__main__':
    main()
