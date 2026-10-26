import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from prepare_font_runtime import glyph_index_initializer, prepare


DIRECTORY = """fn (mut tf TTF_File) read_offset_tables() {
    tf.pos = 0
    num_tables := tf.get_u16()
    for _ in 0 .. num_tables {
        tag := tf.get_string(4)
        tf.tables[tag] = Offset_Table{
            checksum: tf.get_u32()
            offset: tf.get_u32()
            length: tf.get_u32()
        }
        if tag != 'head' {
            assert tf.calc_checksum(tf.tables[tag].offset, tf.tables[tag].length) == tf.tables[tag].checksum
        }
    }
}
"""


class GlyphIndexFontRuntimeTest(unittest.TestCase):
    def test_preserves_initialization_order_and_all_non_cmap_work(self):
        source = """module ttf
pub fn (mut tf TTF_File) init() {
    tf.read_offset_tables()
    tf.read_head_table()
    tf.read_name_table()
    tf.read_cmap_table()
    tf.read_hhea_table()
    tf.read_kern_table()
    tf.read_panose_table()
    tf.length = tf.glyph_count()
}
"""
        result = glyph_index_initializer(source + DIRECTORY)
        self.assertIn("pub fn (mut tf TTF_File) init_for_glyph_indices()", result)
        self.assertNotIn("tf.read_cmap_table()", result)
        before = [row.strip() for row in source.splitlines() if row.strip().startswith("tf.")]
        initializer = result.split("fn (mut tf TTF_File) read_normalized_offset_tables()", 1)[0]
        after = [row.strip() for row in initializer.splitlines() if row.strip().startswith("tf.")]
        self.assertEqual(after, [row.replace("read_offset_tables()", "read_normalized_offset_tables()")
                                 for row in before if row != "tf.read_cmap_table()"])

    def test_directory_preserves_every_byte_except_duplicate_checksum_assertion(self):
        source = ("pub fn (mut tf TTF_File) init() {\n"
                  "tf.read_offset_tables()\ntf.read_cmap_table()\n}\n")
        generated = glyph_index_initializer(source + DIRECTORY)
        directory = generated[generated.index("fn (mut tf TTF_File) read_normalized_offset_tables()") :]
        expected = DIRECTORY.replace("read_offset_tables()", "read_normalized_offset_tables()")
        expected = expected.replace("        if tag != 'head' {\n"
                                    "            assert tf.calc_checksum(tf.tables[tag].offset, tf.tables[tag].length) == tf.tables[tag].checksum\n"
                                    "        }\n", "")
        self.assertEqual(directory, expected)

    def test_rejects_missing_ambiguous_or_changed_checksum_validation(self):
        source = ("pub fn (mut tf TTF_File) init() {\n"
                  "tf.read_offset_tables()\ntf.read_cmap_table()\n}\n")
        for directory in ["", DIRECTORY * 2, DIRECTORY.replace("==", "!="),
                          DIRECTORY.replace("tf.pos = 0", "tf.calc_checksum(0, 0)")]:
            with self.assertRaisesRegex(RuntimeError, "Unsupported x.ttf directory"):
                glyph_index_initializer(source + directory)

    def test_rejects_unknown_or_ambiguous_initializer_layouts(self):
        for source in ["", "pub fn (mut tf TTF_File) init() {}",
                       "pub fn (mut tf TTF_File) init() {\ntf.read_cmap_table()\n"
                       "tf.read_cmap_table()\n}\n"]:
            with self.assertRaisesRegex(RuntimeError, "Unsupported x.ttf"):
                glyph_index_initializer(source)

    def test_active_library_is_copied_and_original_init_is_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            source = work / "vlib/x/ttf"
            source.mkdir(parents=True)
            original = ("module ttf\npub fn (mut tf TTF_File) init() {\n"
                        "tf.read_offset_tables()\ntf.read_cmap_table()\n}\n" + DIRECTORY)
            (source / "ttf.v").write_text(original)
            (source / "common.v").write_text("module ttf\n")
            with patch("prepare_font_runtime.compiler_vlib", return_value=work / "vlib"):
                root = prepare("/moved/compiler/v", work / "output")
                self.assertEqual(root, prepare("/moved/compiler/v", work / "output"))
                self.assertEqual((source / "ttf.v").read_text(), original)
                self.assertEqual((root / "x/ttf/ttf.v").read_text(), original)
                self.assertTrue((root / "x/ttf/vox_glyph_index_init.v").is_file())
                (source / "common.v").write_text("module ttf\n// revised upstream\n")
                revised = prepare("/moved/compiler/v", work / "output")
                self.assertNotEqual(root, revised)
                self.assertEqual((root / "x/ttf/common.v").read_text(), "module ttf\n")


if __name__ == "__main__":
    unittest.main()
