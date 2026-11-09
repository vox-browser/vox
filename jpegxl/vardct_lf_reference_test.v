module jpegxl

import math
import os

fn test_vardct_reference_group_crops_in_block_coordinates_and_zeros_contexts() {
	frame := FrameHeader{ width: 2656, height: 24, flags: 32, restoration: RestorationFilter.default() }
	mut planes := [3]FloatPlane{}
	for c in 0 .. 3 { planes[c] = FloatPlane{ width: 332, height: 3, samples: []f32{len: 332*3, init: f32(index+c*10000)} } }
	for group in u64(0) .. 2 {
		result := referenced_lf_group(frame, group, planes)!
		w := if group == 0 { 256 } else { 76 }
		assert result.width == w && result.height == 3
		assert result.quant_lf_contexts == []u8{len: w*3}
		for c in 0 .. 3 {
			for y in 0 .. 3 {
				for x in 0 .. w { assert result.planes[c].samples[y*w+x] == planes[c].samples[y*332+int(group)*256+x] }
			}
		}
	}
	assert !frame.should_do_adaptive_lf_smoothing()
	if _ := referenced_lf_group(frame, 2, planes) { assert false }
}

fn test_vardct_reference_validates_presence_shape_and_level_before_consuming_sections() {
	base := FrameHeader{ width: 8, height: 8, flags: 32, restoration: RestorationFilter.default() }
	p := FloatPlane{ width: 1, height: 1, samples: [f32(0)] }
	for reference in [[p,p,p]!, [FloatPlane{},p,p]!] {
		for frame in [FrameHeader{ ...base, flags: 0 }, FrameHeader{ ...base, width: 9 },
			FrameHeader{ ...base, frame_type: .lf, lf_level: 4 }] {
			mut sections := [new_bit_reader([u8(255)])]
			if _ := decode_vardct_frame_with_lf(FileHeader{}, frame, .signed16, reference, mut sections) { assert false }
			assert sections[0].position == 0
		}
	}
	mut sections := [new_bit_reader([u8(255)])]
	if _ := decode_vardct_frame_with_lf(FileHeader{}, base, .signed16, none, mut sections) { assert false }
	assert sections[0].position == 0
	if _ := decode_vardct_frame_with_lf(FileHeader{}, base, .signed16, [FloatPlane{},p,p]!, mut sections) { assert false }
	assert sections[0].position == 0
}

fn test_vardct_nonvisible_levels_keep_the_same_coded_geometry() {
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'jpegxl/testdata/vardct/constant-8x8-2.jxl'))!
	mut reader := new_bit_reader(bytes)
	file := reader.read_file_header()!
	ctx := file.frame_header_context()
	mut frame := reader.read_frame_header(ctx)!
	frame.postprocess(ctx)!
	toc := reader.read_toc(int(frame.num_toc_entries()))!
	sections := reader.read_sections(toc)!
	mut baseline_sections := sections.clone()
	baseline := decode_vardct_frame(file, frame, .signed16, mut baseline_sections)!
	for level in u32(1) .. 5 {
		scale := u32(1) << (level*3)
		lf := FrameHeader{ ...frame, frame_type: .lf, lf_level: level, width: frame.width*scale, height: frame.height*scale }
		mut inputs := sections.clone()
		actual := decode_vardct_frame_with_lf(file, lf, .signed16, none, mut inputs)!
		for c in 0 .. 3 { assert actual.planes[c].samples.map(math.f32_bits(it)) == baseline.planes[c].samples.map(math.f32_bits(it)) }
		for section in inputs { assert section.available_bits() == 0 }
	}
}

fn test_guardian_reference_skips_lf_entropy_and_decodes_all_nonzero_hf_sections() {
	bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/jpegxl/guardian-photo.jxl'))!
	mut reader := new_bit_reader(extract_codestream(bytes)!)
	file := reader.read_file_header()!
	ctx := file.frame_header_context()
	mut lf := reader.read_frame_header(ctx)!
	lf.postprocess(ctx)!
	toc := reader.read_toc(int(lf.num_toc_entries()))!
	mut sections := reader.read_sections(toc)!
	modular := decode_modular_frame(file, lf, .signed16, mut sections)!
	converted := modular_xyb_planes(modular.channels, modular.quantization, .signed16)!
	reference := restore_modular_frame(converted, lf)!
	mut frame := reader.read_frame_header(ctx)!
	frame.postprocess(ctx)!
	assert frame.has_lf_frame() && frame.lf_level == 0 && frame.is_last
	visible_toc := reader.read_toc(int(frame.num_toc_entries()))!
	mut visible := reader.read_sections(visible_toc)!
	actual := decode_vardct_frame_with_lf(file, frame, .signed16, reference, mut visible)!
	assert reader.available_bits() == 0
	for section in visible { assert section.available_bits() == 0 }
	assert actual.planes[0].width == 104 && actual.planes[0].height == 104
	assert actual.planes[1].samples.any(it != actual.planes[1].samples[0])
}
