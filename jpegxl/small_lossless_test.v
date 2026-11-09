module jpegxl

import encoding.hex
import os

fn test_complete_small_lossless_images_match_production_source() {
	mut count := 0
	mut accepted := 0
	for line in $embed_file('testdata/small-lossless-pixels.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 7
		bytes := hex.decode(f[1])!
		result := if decoded := decode_small_lossless_rgba(bytes, f[2] == '1') {
			assert decoded.width == f[3].int() && decoded.height == f[4].int() && decoded.pitch == f[5].int(), 'Image geometry ${f[0]}'
			accepted++
			hex.encode(decoded.pixels)
		} else {
			'err'
		}
		assert result == f[6], 'Complete image ${f[0]}, paint=${f[2]}'
		count++
	}
	assert count == 498 && accepted == 24
}

fn test_small_lossless_decoder_rejects_pending_vardct_chain() {
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/jpegxl/guardian-photo.jxl'))!
	if _ := decode_small_lossless_rgba(bytes, false) {
		assert false
	}
}
