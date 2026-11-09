module jpegxl

import crypto.sha256
import math
import os

fn test_vardct_frame_decodes_native_accepted_constant_files_and_all_section_cursors() {
	mut count := 0
	mut split := 0
	mut multiple_lf := 0
	for line in $embed_file('testdata/vardct-files.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/vardct', f[0]))!
		assert sha256.sum(bytes).hex() == f[3]
		mut input := new_bit_reader(bytes)
		file := input.read_file_header()!
		ctx := file.frame_header_context()
		mut frame := input.read_frame_header(ctx)!
		frame.postprocess(ctx)!
		assert int(frame.width) == f[1].int() && int(frame.height) == f[2].int()
		toc := input.read_toc(int(frame.num_toc_entries()))!
		mut sections := input.read_sections(toc)!
		assert input.available_bits() == 0
		result := decode_vardct_frame(file, frame, .signed16, mut sections)!
		value := f[0].all_after_last('-').all_before('.').int()
		for c in 0 .. 3 {
			plane := result.planes[c]
			assert plane.width == int(frame.size_padded().width) && plane.height == int(frame.size_padded().height)
			expected := [f32(value) / 2048, f32(value) / 256, f32(value) * 3 / 256][c]
			// Smoothing and inverse transforms can round a constant by an ulp.
			assert plane.samples.all(math.abs(it - expected) <= f32(1e-7))
		}
		assert result.epf_maps.transform_ids.all(it == u8(value) | 128)
		assert result.epf_maps.raw_quant.all(it == value + 1)
		assert result.epf_maps.sharpness.all(it == u8(value))
		for section in sections { assert section.available_bits() == 0 }
		if sections.len > 1 { split++ }
		if frame.num_lf_groups() > 1 { multiple_lf++ }
		count++
	}
	assert count == 20 && split == 8 && multiple_lf == 4
}

fn test_vardct_frame_rejects_unimplemented_services_and_bad_section_counts() {
	file := FileHeader{}
	base := FrameHeader{ width: 8, height: 8, restoration: RestorationFilter.default() }
	for frame in [FrameHeader{ ...base, flags: 32 }, FrameHeader{ ...base, upsampling: 2 },
		FrameHeader{ ...base, lf_level: 1 }, FrameHeader{ ...base, width: 65536, height: 65536 },
		FrameHeader{ ...base, jpeg_upsampling: [u32(0), 1, 0]!, max_hshift: 1, max_vshift: 1 }] {
		mut sections := [new_bit_reader([u8(255)])]
		if _ := decode_vardct_frame(file, frame, .signed32, mut sections) { assert false }
		assert sections[0].position == 0
	}
	mut empty := []BitReader{}
	if _ := decode_vardct_frame(file, base, .signed32, mut empty) { assert false }
}
