module jpegxl

import crypto.sha256
import os

fn test_complete_vardct_rgba_matches_pinned_production_decoder_pixels() {
	mut count := 0
	fixtures := $embed_file('testdata/vardct-files.tsv').to_string() + '\n' + $embed_file('testdata/vardct-patterns.tsv').to_string()
	for line in fixtures.split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/vardct', f[0]))!
		assert sha256.sum(data).hex() == f[3]
		for premultiply in [false, true] {
			image := decode_vardct_rgba(data, premultiply)!
			assert image.width == f[1].int() && image.height == f[2].int()
			assert image.pitch == image.width * 4
			assert sha256.sum(image.pixels).hex() == f[4], 'Complete VarDCT RGBA ${f[0]}'
		}
		count++
	}
	assert count == 24
}

fn test_complete_vardct_output_rejects_bad_inputs_and_unhandled_trailing_bytes() {
	for data in [ []u8{}, [u8(255)], [u8(255),10], [u8(0),0] ] {
		if _ := decode_vardct_rgba(data, false) { assert false }
	}
	mut valid := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/vardct/constant-8x8-0.jxl'))!
	valid << u8(0)
	if _ := decode_vardct_rgba(valid, false) { assert false }
}
