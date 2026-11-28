import ctypes
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from threading import Barrier
import unittest
from unittest.mock import patch

from libjs_capture_native_compiler import C_FLAGS, capture_compile
from libjs_pack_native_cache import (compile_captured_batch, digest, libraries_from_trace,
                                    link_group, pack_cache, pack_from_benchmark)


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
        both_started = Barrier(2, timeout=5)

        def compile_together(*batch):
            both_started.wait()
            return compile_captured_batch(*batch)

        with patch("libjs_pack_native_cache.compile_captured_batch", side_effect=compile_together):
            report = pack_cache(self.cache, self.abi, None, None, selected, self.output,
                                captures=self.root / "captures", jobs=2)
        self.assertEqual(report["compiler_jobs"], 2)
        directory = self.output / self.abi
        library = directory / report["library"]
        self.assertEqual(digest(library), report["group_sha256"])
        loaded = ctypes.CDLL(str(library))
        for value in (4, 5):
            key = f"{value:064x}"
            record = json.loads((directory / (key + ".json")).read_bytes())
            self.assertEqual(record["key"], key)
            self.assertEqual(record["library"], library.name)
            self.assertEqual(getattr(loaded, f"vox_native_{record['symbol']}")(), value)
            self.assertEqual(record["symbol"], sorted(selected).index(selected[value - 4]) + 1)
        self.assertEqual(report["grouped_records"], 2)

    def test_parallel_compile_failure_leaves_no_cache_or_scratch(self):
        selected = [self.build_captured_library(value)[0] for value in (4, 5)]
        both_started = Barrier(2, timeout=5)

        def fail_one(input_c, mapping, name):
            both_started.wait()
            if name == selected[0]:
                raise subprocess.CalledProcessError(1, ["clang", str(input_c)])
            return compile_captured_batch(input_c, mapping, name)

        with patch("libjs_pack_native_cache.compile_captured_batch", side_effect=fail_one):
            with self.assertRaises(subprocess.CalledProcessError):
                pack_cache(self.cache, self.abi, None, None, selected, self.output,
                           captures=self.root / "captures", jobs=2)
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.root.glob(".libjs-pack-*")), [])

    def test_checkpoint_reuses_objects_from_interrupted_packing(self):
        selected = sorted(self.build_captured_library(value)[0] for value in (4, 5))
        checkpoint = self.root / "checkpoint"

        def interrupted(input_c, mapping, name):
            if name == selected[1]:
                raise subprocess.CalledProcessError(1, ["clang", str(input_c)])
            return compile_captured_batch(input_c, mapping, name)

        with patch("libjs_pack_native_cache.compile_captured_batch", side_effect=interrupted):
            with self.assertRaises(subprocess.CalledProcessError):
                pack_cache(self.cache, self.abi, None, None, selected, self.output,
                           captures=self.root / "captures", object_checkpoint=checkpoint)
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.root.glob(".libjs-pack-*")), [])
        saved = json.loads((checkpoint / "objects.json").read_bytes())["verified_objects"]
        self.assertEqual(set(saved), {selected[0]})

        with patch("libjs_pack_native_cache.compile_captured_batch", wraps=compile_captured_batch) as compile_batch:
            report = pack_cache(self.cache, self.abi, None, None, selected, self.output,
                                captures=self.root / "captures", jobs=2, object_checkpoint=checkpoint)
        compile_batch.assert_called_once()
        self.assertEqual(compile_batch.call_args.args[-1], selected[1])
        self.assertEqual((report["compiled_objects"], report["reused_objects"]), (1, 1))

        with (checkpoint / saved[selected[0]]["object"]).open("ab") as obj:
            obj.write(b"changed")
        another_output = self.root / "another-output"
        with self.assertRaisesRegex(ValueError, "Checkpoint object or captured C digest mismatch"):
            pack_cache(self.cache, self.abi, None, None, selected, another_output,
                       captures=self.root / "captures", object_checkpoint=checkpoint)
        self.assertFalse(another_output.exists())

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

    def benchmark_pair(self):
        captures = self.root / "captures"
        batches = {}
        for value in (4, 5):
            name, source = self.build_captured_library(value)
            batches[name] = dict(library_sha256=digest(self.directory / name), source_sha256=digest(source))
        seed = self.root / "seed-results.json"
        trace = self.root / "trace-results.json"
        old_folder = self.root / "original-report" / "0-libjs-native"
        folder = self.root / old_folder.name
        folder.mkdir()
        log = folder / "native-library-trace.log"
        log.write_text("".join(f"dyld[42]: <uuid> {self.directory / name}\n" for name in batches))
        base = dict(engine="libjs-native", valid=True, exit=0,
                    browser_overrides={"VOX_LIBJS_NATIVE_CACHE": str(self.cache)})
        prepared = dict(base, compiler_captures=dict(abi=self.abi, directory=str(captures), batches=batches))
        reopened = dict(base, pid=42, folder=str(old_folder), native_library_trace=dict(
            abi=self.abi, pid=42, path=str(old_folder / log.name), sha256=digest(log), libraries=sorted(batches)))
        seed.write_text(json.dumps(dict(complete=True, prepare_native_cache=True, attempts=[prepared])))
        pins = {str(path.resolve()): digest(path) for path in self.directory.iterdir()}
        trace.write_text(json.dumps(dict(complete=True, trace_native_libraries=True, attempts=[reopened], inputs=pins)))
        return seed, trace, log

    def test_cli_packs_verified_benchmark_results_after_relocation(self):
        seed, trace, log = self.benchmark_pair()
        tool = Path(__file__).with_name("libjs_pack_native_cache.py")
        report = json.loads(subprocess.check_output([
            sys.executable, str(tool), "--seed-results", str(seed), "--trace-results", str(trace),
            "--jobs", "2", "--object-checkpoint", str(self.root / "checkpoint"),
            "--output", str(self.output),
        ]))
        self.assertEqual(report["benchmark"]["seed"]["sha256"], digest(seed))
        self.assertEqual(report["benchmark"]["trace"]["sha256"], digest(trace))
        self.assertEqual(report["trace"], dict(pid=42, path=str(log.resolve()), sha256=digest(log)))
        self.assertEqual((report["records"], report["grouped_records"]), (5, 2))
        self.assertEqual(report["compiler_jobs"], 2)
        directory = self.output / self.abi
        output = ctypes.CDLL(str(directory / report["library"]))
        for value in (4, 5):
            record = json.loads((directory / f"{value:064x}.json").read_bytes())
            self.assertEqual(getattr(output, f"vox_native_{record['symbol']}")(), value)

    def test_benchmark_results_reject_a_changed_loader_log(self):
        seed, trace, log = self.benchmark_pair()
        log.write_bytes(log.read_bytes() + b"later log entry\n")
        with self.assertRaisesRegex(ValueError, "Loader log differs"):
            pack_from_benchmark(seed, trace, self.output)
        self.assertFalse(self.output.exists())

    def test_benchmark_results_reject_new_cache_record_bytes(self):
        seed, trace, _ = self.benchmark_pair()
        entry = self.directory / f"{1:064x}.json"
        entry.write_bytes(entry.read_bytes() + b"\n")
        with self.assertRaisesRegex(ValueError, "Native cache differs"):
            pack_from_benchmark(seed, trace, self.output)
        self.assertFalse(self.output.exists())

    def test_benchmark_results_reject_rewritten_capture_and_receipt(self):
        seed, trace, _ = self.benchmark_pair()
        batch = next((self.root / "captures").iterdir())
        source, receipt = batch / "code.c", batch / "receipt.json"
        source.write_text("int vox_native_0(void) { return 100; }\n")
        checks = json.loads(receipt.read_bytes())
        checks["source_sha256"] = digest(source)
        receipt.write_text(json.dumps(checks))
        with self.assertRaisesRegex(ValueError, "Compiler capture differs"):
            pack_from_benchmark(seed, trace, self.output)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
