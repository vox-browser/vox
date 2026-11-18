import ctypes
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from libjs_pack_native_cache import digest, link_group, pack_cache


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


if __name__ == "__main__":
    unittest.main()
