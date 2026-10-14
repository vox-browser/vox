module layout

import css
import dom
import platform

fn test_utf16_length_counts_code_units_instead_of_bytes_or_graphemes() {
	values := ['', 'ascii\x00text', 'é', '漢字', 'a\u0301', 'A😀B', '👩‍💻', '\U0010ffff']
	expected := [0, 10, 1, 2, 2, 4, 5, 2]
	for index, value in values {
		assert utf16_length_for_line_box(value) == expected[index]
	}
}

fn test_utf16_length_matches_materialized_units_for_every_two_byte_input() {
	for first in 0 .. 256 {
		for second in 0 .. 256 {
			value := [u8(first), u8(second)].bytestr()
			assert utf16_length_for_line_box(value) == utf16_code_units_for_line_box(value).len
		}
	}
}

fn test_utf16_length_matches_decoder_for_mixed_and_truncated_input() {
	valid := 'aé漢😀\U0010ffff'.bytes()
	for start in 0 .. valid.len {
		for end in start .. valid.len + 1 {
			value := valid[start..end].bytestr()
			assert utf16_length_for_line_box(value) == utf16_code_units_for_line_box(value).len
		}
	}
	mut bits := u64(0x742e47fd91e5b6e3)
	for _ in 0 .. 4096 {
		mut bytes := []u8{cap: 32}
		for _ in 0 .. 32 {
			bits = bits * u64(6364136223846793005) + u64(1442695040888963407)
			bytes << u8(bits >> 56)
		}
		value := bytes.bytestr()
		assert utf16_length_for_line_box(value) == utf16_code_units_for_line_box(value).len
	}
}

fn test_text_offset_clamps_follow_live_rendered_utf16_length() {
	document := dom.Document.create(dom.url_about_blank())
	parent := BlockContainer.new(document, none, css.ComputedProperties.new())
	mut text := TextNode.new_generated(document, 'A😀B')
	mut parent_node := unsafe { &Node(parent) }
	parent_node.append_child(unsafe { &Node(text) })
	for boundary in [platform.TextMappingBoundary.start, .end] {
		assert text.source_offset_for_rendered_text_offset(-1, boundary) == 0
		assert text.source_offset_for_rendered_text_offset(2, boundary) == 2
		assert text.source_offset_for_rendered_text_offset(99, boundary) == 4
		assert text.rendered_text_offset_for_source_offset(-1, boundary) == 0
		assert text.rendered_text_offset_for_source_offset(2, boundary) == 2
		assert text.rendered_text_offset_for_source_offset(99, boundary) == 4
	}
	text.source_text_ = 'é'
	text.invalidate_text_for_rendering()
	assert text.source_offset_for_rendered_text_offset(99, .end) == 1
	assert text.rendered_text_offset_for_source_offset(99, .end) == 1
	text.source_text_ = ''
	text.invalidate_text_for_rendering()
	assert text.source_offset_for_rendered_text_offset(99, .end) == 0
	assert text.rendered_text_offset_for_source_offset(99, .end) == 0
}
