module jpegxl

import crypto.sha256
import os

fn test_skipped_previews_match_native_complete_rgba_even_with_invalid_entropy() {
	mut count := 0
	for line in $embed_file('testdata/preview-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/previews', f[0]))!
		assert sha256.sum(bytes).hex() == f[3]
		for premultiply in [false,true] {
			image := decode_vardct_rgba(bytes, premultiply)!
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width*4
			assert sha256.sum(image.pixels).hex() == f[4], 'Preview RGBA ${f[0]}'
		}
		count++
	}
	assert count == 2
}

fn test_preview_skip_uses_preview_dimensions_and_leaves_main_frame_untouched() {
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/previews/poisoned-preview.jxl'))!
	mut reader := new_bit_reader(bytes)
	file := reader.read_file_header()!
	preview := file.metadata.preview or { panic('Missing preview metadata') }
	assert preview == Size{ width: 8, height: 8 }
	reader.skip_preview(file)!
	main_start := reader.position
	mut main := new_bit_reader(os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/vardct/gradient-33x25.jxl'))!)
	main.read_file_header()!
	main.align_to_byte()!
	assert bytes[main_start/8..] == main.data[main.position/8..]
	frame := reader.read_frame_header(file.frame_header_context())!
	assert frame.width == 33 && frame.height == 25 && frame.is_last
	for end in 0 .. main_start/8 + 1 {
		if _ := decode_vardct_rgba(bytes[..end], false) { assert false }
	}
}

fn test_preview_skip_is_noop_without_metadata_and_checks_sample_budget_before_toc() {
	mut reader := new_bit_reader([u8(255)])
	reader.skip_preview(FileHeader{})!
	assert reader.position == 0
	file := FileHeader{ size: Size{ width: 8, height: 8 }, metadata: ImageMetadata{ preview: Size{ width: 65536, height: 65536 } } }
	if _ := reader.skip_preview(file) { assert false }
	assert reader.position == 1
}
