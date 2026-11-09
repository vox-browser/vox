module jpegxl

import crypto.sha256
import os

fn test_lossless_preview_files_preserve_native_alpha_orientation_and_gray_output() {
	mut count := 0
	for line in $embed_file('testdata/lossless-preview-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/lossless-previews', f[0]))!
		assert sha256.sum(bytes).hex() == f[3]
		for paint in [false,true] {
			for small in [false,true] {
				image := if small { decode_small_lossless_rgba(bytes, paint)! } else { decode_lossless_rgba(bytes, paint)! }
				assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width*4
				assert sha256.sum(image.pixels).hex() == f[if paint { 5 } else { 4 }], 'Lossless preview ${f[0]}, paint=${paint}, small=${small}'
			}
		}
		count++
	}
	assert count == 6
}

fn test_lossless_preview_truncations_cannot_fall_through_to_main_image() {
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/lossless-previews/poison-rgba.jxl'))!
	mut reader := new_bit_reader(bytes)
	file := reader.read_file_header()!
	reader.skip_preview(file)!
	for end in 0 .. reader.position/8+1 {
		if _ := decode_lossless_rgba(bytes[..end], false) { assert false }
		if _ := decode_small_lossless_rgba(bytes[..end], true) { assert false }
	}
}
