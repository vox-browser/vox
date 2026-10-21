import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from prepare_font_runtime import glyph_index_initializer, prepare


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
        result = glyph_index_initializer(source)
        self.assertIn("pub fn (mut tf TTF_File) init_for_glyph_indices()", result)
        self.assertNotIn("tf.read_cmap_table()", result)
        before = [row.strip() for row in source.splitlines() if row.strip().startswith("tf.")]
        after = [row.strip() for row in result.splitlines() if row.strip().startswith("tf.")]
        self.assertEqual(after, [row for row in before if row != "tf.read_cmap_table()"])

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
                        "tf.read_offset_tables()\ntf.read_cmap_table()\n}\n")
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
