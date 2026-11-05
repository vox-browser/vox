module url

import encoding.utf8
import os
import sync.stdatomic

const retain_rune_percent_encoding = os.getenv('VOX_RETAIN_RUNE_PERCENT_ENCODING') != ''
const percent_encoding_bytes_diagnostics = os.getenv('VOX_PERCENT_ENCODING_BYTES_DIAGNOSTICS') != ''

__global percent_encoding_bytes_reported stdatomic.AtomicVal[bool]

fn percent_encode_bytes(input string, set PercentEncodeSet, space_as_plus bool) string {
	if input.len == 0 { return '' }
	mut expanded := 0
	mut has_non_ascii := false
	mut changed := false
	for b in input {
		if b >= 0x80 { has_non_ascii = true }
		if space_as_plus && b == ` ` {
			changed = true
		} else if code_point_is_in_percent_encode_set(u32(b), set) {
			expanded++
			changed = true
		}
	}
	// Every encode set escapes non-ASCII code points. Valid UTF-8 therefore
	// has the same escaped bytes without a rune array or per-code-point strings.
	// Keep the original decoder's replacement behavior for malformed input.
	if has_non_ascii && !utf8.validate_str(input) {
		return percent_encode_runes(input, set, space_as_plus)
	}
	if percent_encoding_bytes_diagnostics && percent_encoding_bytes_reported.compare_and_swap(false, true) {
		eprintln('Vox URL percent encoding: byte buffer executed')
	}
	if !changed {
		// The result must own its bytes even when input belongs to scratch storage.
		return input.clone()
	}
	mut output := []u8{len: input.len + expanded * 2 + 1}
	mut position := 0
	for b in input {
		if space_as_plus && b == ` ` {
			output[position] = `+`
			position++
		} else if code_point_is_in_percent_encode_set(u32(b), set) {
			output[position] = `%`
			output[position + 1] = '0123456789ABCDEF'[b >> 4]
			output[position + 2] = '0123456789ABCDEF'[b & 15]
			position += 3
		} else {
			output[position] = b
			position++
		}
	}
	return unsafe { tos(output.data, position) }
}
