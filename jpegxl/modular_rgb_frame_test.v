module jpegxl

import crypto.sha256
import os

fn test_modular_rgb_and_gray_output_matches_native_filters_upsampling_and_alpha() {
	mut count := 0
	mut total := 0
	mut gray := 0
	mut gaborish := 0
	mut iterations := []int{len: 4}
	mut factors := []int{len: 4}
	for line in $embed_file('testdata/modular-rgb-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/modular-rgb', f[0]))!
		assert sha256.sum(data).hex() == f[3]
		for paint in [false, true] {
			image := decode_rgba(data, paint) or { panic('${f[0]}, paint=${paint}: ${err.msg()}') }
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width * 4
			assert sha256.sum(image.pixels).hex() == f[if paint { 5 } else { 4 }], 'Modular RGB ${f[0]}, paint=${paint}'
			total += image.pixels.len
		}
		mut reader := new_bit_reader(extract_codestream(data)!)
		file := reader.read_file_header()!
		ctx := file.frame_header_context()
		mut frame := reader.read_frame_header(ctx)!
		frame.postprocess(ctx)!
		assert !file.metadata.xyb_encoded && frame.encoding == .modular
		if file.metadata.color_encoding.color_space == .gray { gray++ }
		if frame.restoration.gab { gaborish++ }
		iterations[int(frame.restoration.epf_iterations)]++
		factors[ceil_log2(int(frame.upsampling))]++
		count++
	}
	assert count == 128 && total == 8564736 && gray == 64 && gaborish == 64
	assert iterations == [32, 32, 32, 32] && factors == [32, 32, 32, 32]
}

fn test_modular_rgb_output_rejects_truncated_payloads_and_preserves_opaque_contract() {
	data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/modular-rgb/rgb-0-u2-e1-33x25-2.jxl'))!
	for end in [0, 1, 2, 5, 10, data.len / 2, data.len - 1] {
		if _ := decode_rgba(data[..end], false) { assert false }
	}
	if _ := decode_opaque_rgba(data, false) { assert false }
	if _ := decode_vardct_rgba(data, false) { assert false }
	if _ := decode_lossless_rgba(data, false) { assert false }
}
