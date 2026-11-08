module jpegxl

import crypto.sha256
import encoding.hex
import math
import os

fn frame_bit(value bool) int { return if value { 1 } else { 0 } }

fn frame_float_words(values []f32) string { return values.map(math.f32_bits(it).str()).join(',') }

fn frame_u32_list(values []u32) string { return values.map(it.str()).join(',') }

fn frame_size_text(size Size) string { return '${size.width},${size.height}' }

fn frame_blend_text(info BlendingInfo) string {
	return '${int(info.mode)},${info.alpha_channel},${frame_bit(info.clamp)},${info.source}'
}

fn frame_passes_text(passes Passes) !string {
	mut brackets := []string{}
	for i in 0 .. int(passes.count) {
		minimum, maximum := passes.downsampling_bracket(i)!
		brackets << '${minimum},${maximum}'
	}
	return 'Passes { num_passes: ${passes.count}, num_ds: ${passes.downsample.len}, shift: [${passes.shifts.map(it.str()).join(', ')}], downsample: [${passes.downsample.map(it.str()).join(', ')}], last_pass: [${passes.last_pass.map(it.str()).join(', ')}] }|${brackets.join(';')}'
}

fn frame_reference_text(frame FrameHeader) !string {
	scalar := '${int(frame.frame_type)},${int(frame.encoding)},${frame.flags},${frame_bit(frame.do_ycbcr)},${frame.upsampling},${frame.x_qm_scale},${frame.b_qm_scale},${frame.lf_level},${frame.x0},${frame.y0},${frame.duration_ticks},${frame.timecode},${frame_bit(frame.is_last)},${frame.save_as_reference},${frame_bit(frame.can_be_referenced)},${frame_bit(frame.save_before_color_transform)},${frame.width},${frame.height},${frame.max_hshift},${frame.max_vshift},${frame.extra_upsampling.len},${frame.have_crop}'
	passes := frame_passes_text(frame.passes)!
	name := hex.encode(frame.name.bytes())
	scales := '${frame_u32_list(frame.extra_upsampling)}|${frame_blend_text(frame.blending)}|${frame.extra_blending.map(frame_blend_text(it)).join(';')}'
	r := frame.restoration
	mut floats := []f32{}
	floats << r.gab_weights[..]
	floats << r.epf_sharp_lut[..]
	floats << r.epf_channel_scale[..]
	floats << [r.epf_pass1_zeroflush, r.epf_pass2_zeroflush, r.epf_quant_multiplier,
		r.epf_pass0_sigma_scale, r.epf_pass2_sigma_scale, r.epf_border_sad_multiplier,
		r.epf_sigma_for_modular]
	filter := '${frame_bit(r.gab)},${r.epf_iterations},${frame_float_words(floats)}'
	flags := '${frame_bit(frame.has_noise())}${frame_bit(frame.has_patches())}${frame_bit(frame.has_splines())}${frame_bit(frame.has_lf_frame())}${frame_bit(frame.should_do_adaptive_lf_smoothing())}${frame_bit(frame.is_visible())}${frame_bit(frame.needs_blending())}${frame_bit(frame.is444())}${frame_bit(frame.is420())}${frame_bit(frame.is422())}${frame_bit(frame.is440())}'
	dimensions := [frame.size(), frame.size_blocks(), frame.size_padded(), frame.size_upsampled(),
		frame.size_padded_upsampled(), frame.size_groups(), frame.size_lf_groups()].map(frame_size_text(it)).join(';')
	stats := '${frame.log_group_dimension()},${frame.group_dimension()},${frame.lf_group_dimension()},${frame.num_groups()},${frame.num_lf_groups()},${frame.num_toc_entries()},${math.f64_bits(frame.duration_milliseconds(Animation{ ticks_numerator: 1000, ticks_denominator: 1001 }))}'
	mut rectangles := []string{}
	for group in [u64(0), frame.num_groups() / 2, frame.num_groups() - 1] {
		for rect in [frame.group_rect(group)!, frame.block_group_rect(group)!] {
			rectangles << '${rect.x},${rect.y},${rect.width},${rect.height}'
		}
	}
	for group in [u64(0), frame.num_lf_groups() / 2, frame.num_lf_groups() - 1] {
		rect := frame.lf_group_rect(group)!
		rectangles << '${rect.x},${rect.y},${rect.width},${rect.height}'
	}
	return '${scalar}|${passes}|${name}|${scales}|${filter}|${flags}|${dimensions}|${stats}|${rectangles.join(';')}'
}

fn frame_reference_context(fields []string) FrameHeaderContext {
	values := fields[1].split(',')
	mut channels := []ExtraChannelInfo{}
	if fields[2] != '-' {
		for value in fields[2].split(',') {
			channels << ExtraChannelInfo{ dimension_shift: u32(value.u64()) }
		}
	}
	return FrameHeaderContext{
		xyb_encoded:    values[0] == '1'
		have_animation: values[1] == '1'
		have_timecode:  values[2] == '1'
		extra_channels: channels
		image_size:     Size{ width: u32(values[3].u64()), height: u32(values[4].u64()) }
	}
}

fn test_frame_headers_postprocessing_and_geometry_match_source() {
	mut count := 0
	mut successful := 0
	for line in $embed_file('testdata/frames.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 6
		mut context := frame_reference_context(fields)
		mut input := new_bit_reader(hex.decode(fields[3])!)
		if fields[0].starts_with('fixture:') {
			parts := fields[0].split(':')
			header := input.read_file_header()!
			assert input.position == parts[2].int()
			actual_context := header.frame_header_context()
			assert actual_context.image_size == context.image_size
			assert actual_context.xyb_encoded == context.xyb_encoded
			assert actual_context.have_animation == context.have_animation
			assert actual_context.have_timecode == context.have_timecode
			assert actual_context.extra_channels.len == context.extra_channels.len
			for i, channel in actual_context.extra_channels {
				assert channel.dimension_shift == context.extra_channels[i].dimension_shift
			}
			context = actual_context
		}
		mut diagnostic := ''
		actual := if mut frame := input.read_frame_header(context) {
			raw := frame_reference_text(frame)!
			frame.postprocess(context)!
			processed := frame_reference_text(frame)!
			'sha256:' + sha256.hexhash('${raw}~${processed}')
		} else {
			diagnostic = err.msg()
			'err'
		}
		assert actual == fields[5], 'Frame ${count}, ${fields[0]}: ${actual}, expected ${fields[5]}, ${diagnostic}'
		assert input.position == fields[4].int(), 'Frame ${count}: position ${input.position}, expected ${fields[4]}, ${diagnostic}'
		if actual != 'err' { successful++ }
		count++
	}
	assert count == 4134
	assert successful > 2000
}

fn test_passes_and_every_downsampling_bracket_match_source() {
	mut count := 0
	for line in $embed_file('testdata/passes.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 3
		mut input := new_bit_reader(hex.decode(fields[0])!)
		actual := if passes := input.read_passes() { frame_passes_text(passes)! } else { 'err' }
		assert actual == fields[2], 'Passes case ${count}'
		assert input.position == fields[1].int(), 'Passes position ${count}'
		count++
	}
	assert count == 1024
}

fn test_real_frame_headers_handle_modular_and_lf_frames() {
	root := os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/jpegxl')
	for name in ['rgba.jxl', 'gray.jxl', 'guardian-photo.jxl'] {
		data := extract_codestream(os.read_bytes(os.join_path(root, name))!)!
		mut input := new_bit_reader(data)
		header := input.read_file_header()!
		context := header.frame_header_context()
		mut frame := input.read_frame_header(context)!
		frame.postprocess(context)!
		assert frame.encoding == .modular
		if name == 'guardian-photo.jxl' {
			assert frame.frame_type == .lf && frame.lf_level == 1
			assert !frame.is_visible() && frame.save_before_color_transform
		} else {
			assert frame.is_visible()
		}
		assert frame.num_toc_entries() > 0
		if _ := frame.group_rect(frame.num_groups()) {
			assert false
		}
		if _ := frame.hshift(3) {
			assert false
		}
	}
	mut invalid_padding := new_bit_reader([u8(0x80), 1])
	invalid_padding.read(1)!
	if _ := invalid_padding.read_frame_header(FrameHeaderContext{ image_size: Size{ width: 1, height: 1 } }) {
		assert false
	}
}
