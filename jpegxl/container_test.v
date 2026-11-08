module jpegxl

import os

fn be32(value u32) []u8 {
	return [u8(value >> 24), u8(value >> 16), u8(value >> 8), u8(value)]
}

fn box(kind string, body []u8, extended bool, unbounded bool) []u8 {
	mut result := be32(if unbounded {
		0
	} else if extended {
		1
	} else {
		u32(8 + body.len)
	})
	result << kind.bytes()
	if extended {
		result << be32(0)
		result << be32(u32(16 + body.len))
	}
	result << body
	return result
}

fn container_prefix(version u32) []u8 {
	mut header := 'jxl '.bytes()
	header << be32(version)
	header << 'jxl '.bytes()
	mut result := container_signature.clone()
	result << box('ftyp', header, false, false)
	return result
}

fn container_part(index u32, last bool, data []u8) []u8 {
	mut body := be32(index | if last { u32(0x80000000) } else { u32(0) })
	body << data
	return box('jxlp', body, false, false)
}

fn assert_container_rejected(bytes []u8) {
	if _ := extract_codestream(bytes) {
		assert false, 'Malformed container was accepted'
	}
}

fn test_signatures_every_prefix_and_single_bit_corruption() {
	assert check_signature([]u8{}) == SignatureProbe{ status: .incomplete, missing: 2 }
	for signature in [codestream_signature, container_signature] {
		for length in 1 .. signature.len {
			assert check_signature(signature[..length]) == SignatureProbe{ status: .incomplete, missing: signature.len - length }
		}
		for index in 0 .. signature.len {
			for bit in 0 .. 8 {
				mut corrupt := signature.clone()
				corrupt[index] ^= u8(1) << bit
				assert check_signature(corrupt).status == .invalid
			}
		}
	}
	assert check_signature([u8(0xff), 0x0a, 0]).status == .codestream
	assert check_signature(container_prefix(0)).status == .container
}

fn test_whole_codestream_extended_sizes_unknown_boxes_and_terminal_boxes() {
	stream := [u8(0xff), 0x0a, 0x80, 0x35]
	assert extract_codestream(stream)! == stream
	for extended in [false, true] {
		for unbounded in [false, true] {
			if extended && unbounded { continue }
			mut bytes := container_prefix(0)
			bytes << box('free', []u8{}, extended, false)
			bytes << box('brob', 'Exif'.bytes(), false, false)
			bytes << box('jxlc', stream, extended, unbounded)
			if !unbounded { bytes << box('xml ', '<meta/>'.bytes(), false, true) }
			assert extract_codestream(bytes)! == stream
		}
	}
}

fn test_codestream_parts_reassemble_in_order_and_version_one_permutations() {
	stream := [u8(0xff), 0x0a, 0x80, 0x35]
	chunks := [container_part(0, false, stream[..1]), container_part(1, false, []u8{}), container_part(2, false, stream[1..3]),
		container_part(3, true, stream[3..])]
	for order in [[0, 1, 2, 3], [3, 2, 1, 0], [1, 0, 3, 2], [2, 3, 0, 1]] {
		mut bytes := container_prefix(1)
		for index in order {
			bytes << chunks[index]
			bytes << box('xml ', []u8{}, false, false)
		}
		assert extract_codestream(bytes)! == stream
	}
	mut ordered := container_prefix(0)
	for chunk in chunks { ordered << chunk }
	assert extract_codestream(ordered)! == stream
}

fn test_container_rejects_overflow_truncation_invalid_order_and_metadata_types() {
	stream := [u8(0xff), 0x0a]
	mut complete := container_prefix(0)
	complete << box('jxlc', stream, false, false)
	for length in 0 .. complete.len { assert_container_rejected(complete[..length]) }
	assert_container_rejected(container_prefix(2))
	assert_container_rejected(container_signature)
	mut no_type := container_signature.clone()
	no_type << box('jxlc', stream, false, false)
	assert_container_rejected(no_type)
	for kind in ['brob', 'jxlc', 'jxlp', 'jbrd'] {
		mut bytes := container_prefix(0)
		bytes << box('brob', kind.bytes(), false, false)
		bytes << box('jxlc', stream, false, false)
		assert_container_rejected(bytes)
	}
	for suffix in [box('jxlc', stream, false, false), container_part(0, true, stream), container_prefix(0)[12..]] {
		mut bytes := complete.clone()
		bytes << suffix
		assert_container_rejected(bytes)
	}
	for header in [[u8(0xff), 0xff, 0xff, 0xff, `j`, `x`, `l`, `c`],
		[u8(0), 0, 0, 1, `j`, `x`, `l`, `c`, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff],
		[u8(0), 0, 0, 1, `j`, `x`, `l`, `c`, 0, 0, 0, 0, 0, 0, 0, 8]] {
		mut bytes := container_prefix(0)
		bytes << header
		assert_container_rejected(bytes)
	}
	for chunks in [[container_part(1, true, stream)], [container_part(0, false, stream)],
		[container_part(0, false, stream), container_part(0, true, []u8{})],
		[container_part(2, true, []u8{}), container_part(0, false, stream)],
		[container_part(2, false, []u8{}), container_part(1, true, []u8{}), container_part(0, false, stream)]] {
		mut bytes := container_prefix(1)
		for chunk in chunks { bytes << chunk }
		assert_container_rejected(bytes)
	}
	mut unordered_v0 := container_prefix(0)
	unordered_v0 << container_part(1, true, stream)
	unordered_v0 << container_part(0, false, []u8{})
	assert_container_rejected(unordered_v0)
}

fn test_existing_rgba_container_extracts_exact_existing_bare_codestream() {
	root := os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/jpegxl')
	bare := os.read_bytes(os.join_path(root, 'rgba.jxl'))!
	container := os.read_bytes(os.join_path(root, 'rgba-container.jxl'))!
	assert extract_codestream(container)! == bare
	mut bits := new_bit_reader(bare)
	assert bits.read(16)! == 0x0aff
	assert bits.read_size(false)! == Size{ width: 3, height: 2 }
}
