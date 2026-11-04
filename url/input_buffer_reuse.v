module url

import os

const retain_url_input_copy = os.getenv('VOX_RETAIN_URL_INPUT_COPY') != ''
const url_input_reuse_diagnostics = os.getenv('VOX_URL_INPUT_REUSE_DIAGNOSTICS') != ''

__global url_input_reuse_reported bool

// Both callers derive these bounds from their freshly decoded, owned array.
// The destination never advances beyond the source, so compaction cannot
// overwrite an unread code point. Keep the existing UTF-8 decoder unchanged.
@[direct_array_access]
fn compact_url_input(mut input []rune, start int, end int) int {
	mut written := 0
	for index := start; index < end; index++ {
		point := input[index]
		if point == `\t` || point == `\n` || point == `\r` { continue }
		input[written] = point
		written++
	}
	if url_input_reuse_diagnostics && !url_input_reuse_reported && input.len >= 32 {
		url_input_reuse_reported = true
		eprintln('Vox URL input: reused rune buffer input=${input.len} output=${written}')
	}
	return written
}
