#!/usr/bin/env python3
"""Build the pinned, isolated libdeflate snapshot compressor."""
import fcntl
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import urllib.request

VERSION = "1.24"
SHA256 = "ad8d3723d0065c4723ab738be9723f2ff1cb0f1571e8bfcf0301ff9661f475e8"
URL = f"https://codeload.github.com/ebiggers/libdeflate/tar.gz/refs/tags/v{VERSION}"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build():
    root = Path(__file__).resolve().parents[1] / f"Build/deps/libdeflate-{VERSION}"
    root.mkdir(parents=True, exist_ok=True)
    with (root / "snapshot-build.lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        archive = root / "source.tar.gz"
        if not archive.exists():
            temporary = root / "source.download"
            urllib.request.urlretrieve(URL, temporary)
            if digest(temporary) != SHA256:
                raise RuntimeError("libdeflate archive checksum mismatch")
            temporary.replace(archive)
        if digest(archive) != SHA256:
            raise RuntimeError("libdeflate archive checksum mismatch")
        inputs = {}
        with tarfile.open(archive) as bundle:
            for member in bundle.getmembers():
                path = Path(member.name)
                if path.is_absolute() or ".." in path.parts or path.parts[0] != f"libdeflate-{VERSION}":
                    raise RuntimeError("Invalid libdeflate archive path")
                if member.isdir():
                    continue
                if not member.isfile():
                    raise RuntimeError("Unsupported libdeflate archive entry")
                data = bundle.extractfile(member).read()
                target = root / path
                if target.exists() and target.read_bytes() != data:
                    raise RuntimeError(f"Modified dependency source: {target}")
                if not target.exists():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(data)
                    target.chmod(member.mode & 0o777)
                inputs[path.as_posix()] = hashlib.sha256(data).hexdigest()
        source = root / f"libdeflate-{VERSION}"
        output = root / "snapshot-build"
        library = output / "libdeflate.a"
        receipt = root / "snapshot-build.json"
        cmake = shutil.which("cmake")
        compiler = shutil.which("clang")
        if not cmake or not compiler:
            raise RuntimeError("Snapshot compression requires CMake and Clang")
        identity = dict(version=VERSION, url=URL, archive_sha256=SHA256, inputs=inputs,
                        builder_sha256=digest(Path(__file__)), compiler=compiler,
                        compiler_version=subprocess.check_output([compiler, "--version"], text=True),
                        cmake_version=subprocess.check_output([cmake, "--version"], text=True))
        if receipt.exists() and library.exists():
            previous = json.loads(receipt.read_text())
            if previous.get("inputs") == identity and previous.get("library_sha256") == digest(library):
                return root
        command = [cmake, "-S", str(source), "-B", str(output),
                   "-DCMAKE_BUILD_TYPE=Release", f"-DCMAKE_C_COMPILER={compiler}",
                   "-DCMAKE_C_FLAGS=-fvisibility=hidden", "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
                   "-DLIBDEFLATE_BUILD_STATIC_LIB=ON", "-DLIBDEFLATE_BUILD_SHARED_LIB=OFF",
                   "-DLIBDEFLATE_BUILD_GZIP=OFF", "-DLIBDEFLATE_BUILD_TESTS=OFF",
                   "-DLIBDEFLATE_DECOMPRESSION_SUPPORT=OFF", "-DLIBDEFLATE_GZIP_SUPPORT=OFF"]
        subprocess.run(command, check=True, stdout=sys.stderr, stderr=sys.stderr)
        subprocess.run([cmake, "--build", str(output), "--parallel", "2"], check=True,
                       stdout=sys.stderr, stderr=sys.stderr)
        receipt.write_text(json.dumps(dict(inputs=identity, library_sha256=digest(library),
                                           configure_command=command), indent=2) + "\n")
        return root


if __name__ == "__main__":
    print(build())
