module jpegxl

import crypto.sha256
import os

// Encoder- and fuzzer-produced files that the pinned native decoder accepts.
// Each must decode to exactly the native straight and paint RGBA8 bytes.
fn test_native_corpus_files_match_native_rgba() {
	mut count := 0
	for line in $embed_file('testdata/native-corpus-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/native-corpus', f[0]))!
		assert sha256.sum(data).hex() == f[3]
		for paint in [false, true] {
			image := decode_rgba(data, paint) or { panic('${f[0]}, paint=${paint}: ${err.msg()}') }
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width * 4
			assert sha256.sum(image.pixels).hex() == f[if paint { 5 } else { 4 }], '${f[0]}, paint=${paint}'
		}
		count++
	}
	assert count == native_corpus_expected_files
}

const native_corpus_expected_files = 2

// RLE-coded and plain modular streams of the same image leave trailing bits
// in their single combined section; like the source, they still decode.
fn test_modular_section_trailing_bits_are_ignored() {
	dir := os.join_path(@VMODROOT, 'jpegxl/testdata/native-corpus')
	rle := decode_rgba(os.read_bytes(os.join_path(dir, 'modular_rle_fast_path.jxl'))!, false)!
	plain := decode_rgba(os.read_bytes(os.join_path(dir, 'modular_rle_fast_path_without_lz77.jxl'))!, false)!
	assert rle.pixels == plain.pixels
}
