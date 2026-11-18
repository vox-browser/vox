import ctypes
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from libjs_capture_native_compiler import C_FLAGS, capture_compile
from libjs_pack_native_cache import digest, libraries_from_trace, link_group, pack_cache


class CacheTraceTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory(prefix="vox-native-trace-test-")
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        self.cache = self.root / "cache with spaces"
        self.abi = self.cache / ("a" * 64)
        self.abi.mkdir(parents=True)
        self.trace = self.root / "dyld.log"
        self.first, self.second = (f"{index:064x}.dylib" for index in (1, 2))

    def test_selects_only_images_in_the_requested_cache_abi(self):
        alias = self.root / "alias"
        alias.symlink_to(self.cache, target_is_directory=True)
        self.trace.write_text("\n".join((
            "dyld[90]: <uuid> /usr/lib/libSystem.B.dylib",
            f"dyld[90]: <uuid> {self.cache / ('b' * 64) / self.first}",
            f"dyld[90]: <uuid> {self.abi / 'nested' / self.first}",
            f"dyld[42]: <uuid> {self.abi / self.second}",
            f"dyld[42]: <uuid> {alias / self.abi.name / self.first}",
            f"dyld[42]: <uuid> {self.abi / self.first}",
        )))
        selected, receipt = libraries_from_trace(self.trace, self.abi)
        self.assertEqual(selected, [self.first, self.second])
        self.assertEqual(receipt, dict(pid=42, path=str(self.trace.resolve()), sha256=digest(self.trace)))

    def test_multiple_launches_require_the_target_pid(self):
        self.trace.write_text(
            f"dyld[42]: <uuid> {self.abi / self.first}\n"
            f"dyld[43]: <uuid> {self.abi / self.second}\n")
        with self.assertRaisesRegex(ValueError, "Use --trace-pid"):
            libraries_from_trace(self.trace, self.abi)
        self.assertEqual(libraries_from_trace(self.trace, self.abi, 43)[0], [self.second])
        with self.assertRaisesRegex(ValueError, "No native cache libraries"):
            libraries_from_trace(self.trace, self.abi, 44)


@unittest.skipUnless(sys.platform == "darwin", "requires the macOS linker")
class PackNativeCacheTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory(prefix="vox-native-cache-test-")
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        self.cache = self.root / "source"
        self.abi = "a" * 64
        self.directory = self.cache / self.abi
        self.directory.mkdir(parents=True)
        self.objects = self.root / "objects"
        self.objects.mkdir()
        self.output = self.root / "output"
        self.receipt = self.root / "link-receipt.json"
        self.rows = [self.build_library(index + 1, index) for index in range(3)]
        self.selected = [Path(row["separate"]).name for row in self.rows[:2]]
        self.write_receipt()

    def build_library(self, value, index):
        source = self.objects / f"entry-{value}.c"
        object_file = source.with_suffix(".o")
        source.write_text(f"int vox_native_{index}(void) {{ return {value}; }}\n")
        subprocess.run(["/usr/bin/clang", "-c", str(source), "-o", str(object_file)], check=True)
        staging = source.with_suffix(".dylib")
        subprocess.run(["/usr/bin/clang", "-dynamiclib", str(object_file), "-o", str(staging)], check=True)
        sha = digest(staging)
        library = self.directory / f"{sha}.dylib"
        staging.rename(library)
        key = f"{value:064x}"
        record = dict(key=key, abi=self.abi, library=library.name, library_sha256=sha, symbol=index)
        (self.directory / (key + ".json")).write_text(json.dumps(record))
        return dict(object=str(object_file), object_sha256=digest(object_file),
                    separate=str(library), separate_sha256=sha)

    def write_receipt(self):
        self.receipt.write_text(json.dumps(dict(abi=self.abi, object_files=self.rows)))

    def pack(self):
        return pack_cache(self.cache, self.abi, self.objects, self.receipt, self.selected, self.output)

    def test_reopens_all_entries_with_preserved_keys_and_digests(self):
        initial = {file.name: digest(file) for file in self.directory.iterdir()}
        report = self.pack()
        output = self.output / self.abi
        self.assertEqual((report["records"], report["grouped_records"], report["libraries"]), (3, 2, 2))
        self.assertEqual(report["library"], report["group_sha256"] + ".dylib")
        self.assertFalse(any((output / name).exists() for name in self.selected))
        for index in range(3):
            name = f"{index + 1:064x}.json"
            old = json.loads((self.directory / name).read_text())
            record = json.loads((output / name).read_text())
            if index < 2:
                old.update(library=report["library"], library_sha256=report["group_sha256"])
            self.assertEqual(record, old)
            library = output / record["library"]
            self.assertEqual(digest(library), record["library_sha256"])
            loaded = ctypes.CDLL(str(library))
            self.assertEqual(getattr(loaded, f"vox_native_{record['symbol']}")(), index + 1)
        self.assertEqual((output / f"{3:064x}.json").read_bytes(),
                         (self.directory / f"{3:064x}.json").read_bytes())
        self.assertEqual({file.name: digest(file) for file in self.directory.iterdir()}, initial)

    def test_rejects_changed_object_and_leaves_no_output(self):
        self.rows[0]["object_sha256"] = "0" * 64
        self.write_receipt()
        with self.assertRaisesRegex(ValueError, "Object digest mismatch"):
            self.pack()
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.root.glob(".libjs-pack-*")), [])

    def test_rejects_duplicate_symbols_across_selected_libraries(self):
        other = self.build_library(4, 0)
        self.rows.append(other)
        self.selected[1] = Path(other["separate"]).name
        self.write_receipt()
        with self.assertRaisesRegex(ValueError, "share LibJS entry symbols"):
            self.pack()
        self.assertFalse(self.output.exists())

    def test_rejects_source_changes_during_link(self):
        def change_source(*args):
            image = link_group(*args)
            (self.directory / f"{3:064x}.json").unlink()
            return image

        with patch("libjs_pack_native_cache.link_group", side_effect=change_source):
            with self.assertRaisesRegex(ValueError, "Source cache changed"):
                self.pack()
        self.assertFalse(self.output.exists())

    def test_refuses_to_replace_an_existing_output(self):
        self.output.mkdir()
        sentinel = self.output / "keep"
        sentinel.write_text("already here")
        with self.assertRaises(FileExistsError):
            self.pack()
        self.assertEqual(sentinel.read_text(), "already here")

    def test_cli_packs_the_traced_libraries(self):
        trace = self.root / "dyld.log"
        trace.write_text("".join(f"dyld[42]: <uuid> {self.directory / name}\n" for name in self.selected))
        tool = Path(__file__).with_name("libjs_pack_native_cache.py")
        result = subprocess.check_output([
            sys.executable, str(tool), "--cache", str(self.cache), "--abi", self.abi,
            "--objects", str(self.objects), "--receipt", str(self.receipt),
            "--trace", str(trace), "--output", str(self.output),
        ])
        report = json.loads(result)
        self.assertEqual(report["group_libraries"], sorted(self.selected))
        self.assertEqual(report["trace"]["pid"], 42)
        self.assertEqual(report["trace"]["sha256"], digest(trace))
        self.assertEqual(report["grouped_records"], 2)
        self.assertTrue((self.output / self.abi / report["library"]).is_file())

    def test_trace_of_a_removed_library_cannot_publish(self):
        trace = self.root / "dyld.log"
        missing = self.directory / ("f" * 64 + ".dylib")
        trace.write_text(f"dyld[42]: <uuid> {self.directory / self.selected[0]}\n"
                         f"dyld[42]: <uuid> {missing}\n")
        with self.assertRaisesRegex(ValueError, "Selected libraries lack cache records"):
            pack_cache(self.cache, self.abi, self.objects, self.receipt, None, self.output, trace=trace)
        self.assertFalse(self.output.exists())

    def build_captured_library(self, value):
        staging = self.root / f"batch-{value}"
        staging.mkdir()
        source, output = staging / "code.c", staging / "code.dylib"
        source.write_text(f"int vox_native_0(void) {{ return {value}; }}\n")
        captures = self.root / "captures"
        capture_compile([*C_FLAGS, "-dynamiclib", str(source), "-o", str(output)], captures)
        sha = digest(output)
        saved = captures / sha / "code.c"
        self.assertEqual(saved.read_bytes(), source.read_bytes())
        library = self.directory / f"{sha}.dylib"
        output.rename(library)
        key = f"{value:064x}"
        record = dict(key=key, abi=self.abi, library=library.name, library_sha256=sha, symbol=0)
        (self.directory / (key + ".json")).write_text(json.dumps(record))
        return library.name, saved

    def test_captured_batches_reopen_with_distinct_symbols(self):
        selected = [self.build_captured_library(value)[0] for value in (4, 5)]
        report = pack_cache(self.cache, self.abi, None, None, selected, self.output,
                            captures=self.root / "captures")
        directory = self.output / self.abi
        library = directory / report["library"]
        self.assertEqual(digest(library), report["group_sha256"])
        loaded = ctypes.CDLL(str(library))
        symbols = set()
        for value in (4, 5):
            key = f"{value:064x}"
            record = json.loads((directory / (key + ".json")).read_bytes())
            self.assertEqual(record["key"], key)
            self.assertEqual(record["library"], library.name)
            self.assertEqual(getattr(loaded, f"vox_native_{record['symbol']}")(), value)
            symbols.add(record["symbol"])
        self.assertEqual(symbols, {1, 2})
        self.assertEqual(report["grouped_records"], 2)

    def test_rejects_mutated_captured_source(self):
        first, source = self.build_captured_library(4)
        second, _ = self.build_captured_library(5)
        source.write_text("int vox_native_0(void) { return 9; }\n")
        with self.assertRaisesRegex(ValueError, "Captured C digest mismatch"):
            pack_cache(self.cache, self.abi, None, None, [first, second], self.output,
                       captures=self.root / "captures")
        self.assertFalse(self.output.exists())

    def test_failed_compiler_leaves_capture_directory_empty(self):
        source, output = self.root / "code.c", self.root / "code.dylib"
        source.write_text("#error expected failed compiler run\n")
        captures = self.root / "captures"
        with self.assertRaises(subprocess.CalledProcessError):
            capture_compile([*C_FLAGS, "-dynamiclib", str(source), "-o", str(output)], captures)
        self.assertEqual(list(captures.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
