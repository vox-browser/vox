module jpegxl

import crypto.sha256
import os

fn test_complete_modular_xyb_rgba_matches_native_filters_upsampling_and_orientation() {
	mut count := 0
	mut total := 0
	for line in $embed_file('testdata/modular-color-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/modular-color', f[0]))!
		assert sha256.sum(bytes).hex() == f[3]
		for paint in [false,true] {
			image := decode_opaque_rgba(bytes, paint)!
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width*4
			assert sha256.sum(image.pixels).hex() == f[4], 'Modular XYB RGBA ${f[0]}, paint=${paint}'
		}
		if _ := decode_vardct_rgba(bytes, false) { assert false }
		count++
		total += f[1].int()*f[2].int()*4
	}
	assert count == 20 && total == 269336
}

fn test_opaque_entry_point_preserves_all_existing_vardct_native_images() {
	mut count := 0
	for manifest in ['vardct-files.tsv','vardct-patterns.tsv','upsampled-files.tsv','lf-reference-files.tsv','preview-files.tsv'] {
		folder := match manifest {
			'upsampled-files.tsv' { 'jpegxl/testdata/upsampled' }
			'lf-reference-files.tsv' { 'Tests/Browser/Brave/resources/jpegxl' }
			'preview-files.tsv' { 'jpegxl/testdata/previews' }
			else { 'jpegxl/testdata/vardct' }
		}
		for line in os.read_lines(os.join_path(@VMODROOT,'jpegxl/testdata',manifest))! {
			if line == '' || line.starts_with('#') { continue }
			f := line.split('\t')
			bytes := os.read_bytes(os.join_path(@VMODROOT,folder,f[0]))!
			assert sha256.sum(bytes).hex() == f[3]
			image := decode_opaque_rgba(bytes, false)!
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width*4
			assert sha256.sum(image.pixels).hex() == f[4], 'Opaque VarDCT ${f[0]}'
			count++
		}
	}
	assert count == 42
}

fn test_opaque_modular_decoder_rejects_truncation_trailing_bytes_and_unsupported_color_services() {
	bytes := os.read_bytes(os.join_path(@VMODROOT,'jpegxl/testdata/modular-color/xyb-1x-g0-epf0.jxl'))!
	for end in [0,1,2,5,10,bytes.len-1] {
		if _ := decode_opaque_rgba(bytes[..end], false) { assert false }
	}
	mut trailing := bytes.clone()
	trailing << u8(0)
	if _ := decode_opaque_rgba(trailing, false) { assert false }
	for name in ['rgba.jxl','gray.jxl','animated.jxl','wide-gamut.jxl'] {
		data := os.read_bytes(os.join_path(@VMODROOT,'Tests/Browser/Brave/resources/jpegxl',name))!
		if _ := decode_opaque_rgba(data, false) { assert false }
	}
}
