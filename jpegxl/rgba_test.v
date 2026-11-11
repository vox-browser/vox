module jpegxl

import crypto.sha256
import encoding.hex
import os

fn test_complete_vardct_alpha_matches_native_straight_and_paint_images() {
	mut count := 0
	mut bytes_compared := 0
	for line in $embed_file('testdata/vardct-alpha-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT,'jpegxl/testdata/vardct-alpha',f[0]))!
		assert sha256.sum(data).hex() == f[3]
		for paint in [false,true] {
			image := decode_rgba(data, paint)!
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width*4
			assert sha256.sum(image.pixels).hex() == f[if paint { 5 } else { 4 }], 'VarDCT alpha ${f[0]}, paint=${paint}'
			bytes_compared += image.pixels.len
		}
		if _ := decode_opaque_rgba(data, false) { assert false }
		if _ := decode_vardct_rgba(data, false) { assert false }
		count++
	}
	assert count == 20 && bytes_compared == 1800640
}

fn test_rgba_entry_point_preserves_frozen_small_lossless_results_and_rejections() {
	mut count := 0
	for line in $embed_file('testdata/small-lossless-pixels.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := hex.decode(f[1])!
		result := if image := decode_rgba(data, f[2]=='1') {
			assert image.width == f[3].int() && image.height == f[4].int() && image.pitch == f[5].int()
			hex.encode(image.pixels)
		} else { 'err' }
		assert result == f[6], 'Combined RGBA ${f[0]}, paint=${f[2]}'
		count++
	}
	assert count == 498
}

fn test_rgba_entry_point_rejects_truncated_and_trailing_alpha_payloads() {
	data := os.read_bytes(os.join_path(@VMODROOT,'jpegxl/testdata/vardct-alpha/alpha-17x13-2.jxl'))!
	for end in [0,1,2,5,10,data.len/2,data.len-1] {
		if _ := decode_rgba(data[..end], false) { assert false }
	}
	mut trailing := data.clone()
	trailing << u8(0)
	if _ := decode_rgba(trailing, true) { assert false }
}

fn test_rgba_entry_point_preserves_all_opaque_native_image_references() {
	mut count := 0
	for manifest in ['modular-color-files.tsv', 'vardct-files.tsv', 'vardct-patterns.tsv',
		'upsampled-files.tsv', 'lf-reference-files.tsv', 'preview-files.tsv'] {
		folder := match manifest {
			'modular-color-files.tsv' { 'jpegxl/testdata/modular-color' }
			'upsampled-files.tsv' { 'jpegxl/testdata/upsampled' }
			'lf-reference-files.tsv' { 'Tests/Browser/Brave/resources/jpegxl' }
			'preview-files.tsv' { 'jpegxl/testdata/previews' }
			else { 'jpegxl/testdata/vardct' }
		}
		for line in os.read_lines(os.join_path(@VMODROOT, 'jpegxl/testdata', manifest))! {
			if line == '' || line.starts_with('#') { continue }
			f := line.split('\t')
			data := os.read_bytes(os.join_path(@VMODROOT, folder, f[0]))!
			assert sha256.sum(data).hex() == f[3]
			image := decode_rgba(data, false)!
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width * 4
			assert sha256.sum(image.pixels).hex() == f[4], 'Combined opaque RGBA ${f[0]}'
			count++
		}
	}
	assert count == 62
}

fn test_rgba_entry_point_preserves_grouped_lossless_and_preview_references() {
	mut count := 0
	for line in $embed_file('testdata/grouped-pixels.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/grouped', f[0]))!
		image := decode_rgba(data, f[1] == '1')!
		assert image.width == f[2].int() && image.height == f[3].int() && image.pitch == f[4].int()
		assert sha256.sum(image.pixels).hex() == f[5], 'Combined grouped RGBA ${f[0]}'
		count++
	}
	assert count == 26
	count = 0
	for line in $embed_file('testdata/lossless-preview-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		data := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/lossless-previews', f[0]))!
		assert sha256.sum(data).hex() == f[3]
		for paint in [false, true] {
			image := decode_rgba(data, paint)!
			assert image.width == f[1].int() && image.height == f[2].int() && image.pitch == image.width * 4
			assert sha256.sum(image.pixels).hex() == f[if paint { 5 } else { 4 }], 'Combined preview RGBA ${f[0]}'
		}
		count++
	}
	assert count == 6
}
