module css

import os

const disable_mixed_ascii_token_input = os.getenv('VOX_DISABLE_MIXED_ASCII_TOKEN_INPUT') != ''

// Filtered CSS is valid UTF-8. A non-ASCII character need not send all the
// surrounding ASCII through the rune iterator and its optional return value.
// Both numeric tables keep the same scalar indices and original byte offsets.
fn fill_tokenizer_mixed_input(mut arena TokenizerInputArena, input string) {
	mut offset := 0
	for offset < input.len {
		for offset < input.len && input[offset] < 0x80 {
			unsafe {
				arena.code_points[arena.len] = u32(input.str[offset])
				arena.byte_offsets[arena.len] = offset
			}
			arena.len++
			offset++
		}
		if offset >= input.len { break }
		length := utf8_char_len(input[offset])
		mut iterator := input[offset..offset + length].runes_iterator()
		point := iterator.next() or { panic('Missing filtered CSS code point') }
		unsafe {
			arena.code_points[arena.len] = u32(point)
			arena.byte_offsets[arena.len] = offset
		}
		arena.len++
		offset += length
	}
}
