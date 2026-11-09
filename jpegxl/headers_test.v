module jpegxl

import crypto.sha256
import encoding.hex
import math
import os

fn header_bit(value bool) int { return if value { 1 } else { 0 } }

fn header_float_words(values []f32) string { return values.map(math.f32_bits(it).str()).join(',') }

fn header_color_text(color ColorEncoding) string {
	points := color.custom_primaries[..].map('${it.x}:${it.y}').join(';')
	return '${header_bit(color.want_icc)},${int(color.color_space)},${int(color.white_point)},${color.white.x},${color.white.y},${int(color.primaries)},${points},${header_bit(color.have_gamma)},${color.gamma},${int(color.transfer_function)},${int(color.rendering_intent)},'
}

fn header_extra_text(extra ExtraChannelInfo) string {
	depth := extra.bit_depth
	spot := if values := extra.spot_color { header_float_words(values[..]) } else { '-' }
	return '${int(extra.kind)},${header_bit(depth.floating_point)},${depth.bits_per_sample},${depth.exponent_bits},${extra.dimension_shift},${header_bit(extra.alpha_associated)},${spot}'
}

fn header_metadata_text(metadata ImageMetadata) string {
	intrinsic := if size := metadata.intrinsic_size { '${size.width},${size.height}' } else { '-' }
	preview := if size := metadata.preview { '${size.width},${size.height}' } else { '-' }
	animation := if a := metadata.animation {
		'${a.ticks_numerator},${a.ticks_denominator},${a.loops},${header_bit(a.have_timecodes)}'
	} else {
		'-'
	}
	depth := metadata.bit_depth
	tone := metadata.tone_mapping
	tone_text := '${header_bit(tone.all_default)},${math.f32_bits(tone.intensity_target)},${math.f32_bits(tone.min_nits)},${header_bit(tone.relative_to_max_display)},${math.f32_bits(tone.linear_below)}'
	return '${int(metadata.orientation)}|${intrinsic}|${preview}|${animation}|${header_bit(depth.floating_point)},${depth.bits_per_sample},${depth.exponent_bits},${header_bit(metadata.modular_16bit_sufficient)}|${metadata.extra_channels.map(header_extra_text(it)).join('/')}|${header_bit(metadata.xyb_encoded)}|${header_color_text(metadata.color_encoding)}|${tone_text}'
}

fn header_transform_text(transform CustomTransformData) string {
	mut values := []f32{}
	values << transform.opsin.inverse_matrix[..]
	values << transform.opsin.opsin_biases[..]
	values << transform.opsin.quant_biases[..]
	values << transform.weights2[..]
	values << transform.weights4[..]
	values << transform.weights8[..]
	return header_float_words(values)
}

fn header_file_text(header FileHeader) string {
	return '${header.size.width},${header.size.height}|${header_metadata_text(header.metadata)}|${header_transform_text(header.transform)}'
}

fn header_fixture_result(operation string, mut reader BitReader) !string {
	return match operation.all_before(':') {
		'color' { header_color_text(reader.read_color_encoding()!) }
		'extra' { header_extra_text(reader.read_extra_channel()!) }
		'metadata' { header_metadata_text(reader.read_image_metadata()!) }
		'transform0', 'transform1' {
			header_transform_text(reader.read_transform_data(operation == 'transform1')!)
		}
		else { header_file_text(reader.read_file_header()!) }
	}
}

fn test_headers_and_metadata_match_frozen_pinned_source() {
	mut count := 0
	mut accepted := 0
	for line in $embed_file('testdata/headers.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 4
		mut reader := new_bit_reader(hex.decode(fields[1])!)
		mut diagnosis := ''
		mut actual := header_fixture_result(fields[0], mut reader) or {
			diagnosis = err.msg()
			'err'
		}
		if fields[3].starts_with('sha256:') { actual = 'sha256:' + sha256.hexhash(actual) }
		assert actual == fields[3], 'Header case ${count}, ${fields[0]}: ${actual}, expected ${fields[3]}, ${diagnosis}'
		assert reader.position == fields[2].int(), 'Header case ${count}, ${fields[0]}: position ${reader.position}, expected ${fields[2]}, ${diagnosis}'
		if actual != 'err' { accepted++ }
		if fields[0].starts_with('extra:') {
			mut named_input := new_bit_reader(hex.decode(fields[1])!)
			extra := named_input.read_extra_channel()!
			assert extra.name == 'Aä\x00'
			assert int(extra.kind) == fields[0].all_after(':').int()
			assert extra.alpha_associated == (extra.kind == .alpha)
			if extra.kind == .cfa {
				assert extra.cfa_channel? == 27
			} else {
				assert extra.cfa_channel == none
			}
		}
		if fields[0].starts_with('file:') {
			bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/jpegxl', fields[0].all_after('file:')))!
			header := parse_file_header(bytes)!
			assert 'sha256:' + sha256.hexhash(header_file_text(header)) == fields[3]
		}
		count++
	}
	assert count == 6184
	assert accepted > 2000
}

fn test_orientations_map_all_pixels_rectangles_and_row_steps() {
	rows := ['ABCDEF', 'CBAFED', 'FEDCBA', 'DEFABC', 'ADBECF', 'DAEBFC', 'FCEBDA', 'CFBEAD']
	steps := [[1, 0], [-1, 0], [-1, 0], [1, 0], [0, 1], [0, 1], [0, -1], [0, -1]]
	for index, expected in rows {
		orientation := unsafe { Orientation(index + 1) }
		size := Size{ width: 3, height: 2 }
		mapped := orientation.map_size(size)
		mut actual := []u8{len: 6}
		for y in 0 .. 2 {
			for x in 0 .. 3 {
				px, py := orientation.display_pixel(u32(x), u32(y), size)!
				actual[int(py * mapped.width + px)] = u8(`A` + y * 3 + x)
				rect := orientation.display_rect(ImageRect{ x: u32(x), y: u32(y), width: 1, height: 1 }, size)!
				assert rect == ImageRect{ x: px, y: py, width: 1, height: 1 }
			}
		}
		assert actual.bytestr() == expected
		x, y := orientation.display_row_step()
		assert x == steps[index][0] && y == steps[index][1]
		if px, py := orientation.display_pixel(3, 0, size) {
			assert false, '${px},${py}'
		}
		if _ := orientation.display_rect(ImageRect{ x: 2, width: 2 }, size) {
			assert false
		}
	}
}

fn test_real_header_alpha_orientation_animation_and_profile_metadata() {
	root := os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/jpegxl')
	rgba := parse_file_header(os.read_bytes(os.join_path(root, 'rgba.jxl'))!)!
	assert rgba.size == Size{ width: 3, height: 2 }
	assert rgba.metadata.extra_channels.len == 1
	assert rgba.metadata.extra_channels[0].kind == .alpha
	assert !rgba.metadata.extra_channels[0].alpha_associated
	assert rgba.metadata.bit_depth.bits_per_sample == 8
	rotated := parse_file_header(os.read_bytes(os.join_path(root, 'orientation-6.jxl'))!)!
	assert rotated.metadata.orientation == .rotate90_cw
	assert rotated.metadata.orientation.map_size(rotated.size) == Size{ width: 2, height: 3 }
	animated := parse_file_header(os.read_bytes(os.join_path(root, 'animated.jxl'))!)!
	assert animated.metadata.animation != none
	wide := parse_file_header(os.read_bytes(os.join_path(root, 'wide-gamut.jxl'))!)!
	assert wide.metadata.color_encoding.primaries == .p3
	for bytes in [[]u8{}, [u8(255)], [u8(255), 10], 'not an image'.bytes()] {
		if _ := parse_file_header(bytes) {
			assert false
		}
	}
}
