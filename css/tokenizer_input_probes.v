module css

import os

const disable_bulk_css_input_probes = os.getenv('VOX_DISABLE_BULK_CSS_INPUT_PROBES') != ''
const bulk_css_input_probe_diagnostics = os.getenv('VOX_BULK_CSS_INPUT_PROBES_DIAGNOSTICS') != ''

__global css_bulk_ascii_probe_reported bool
__global css_bulk_filter_probe_reported bool
__global css_ascii_decoder_bypass_reported bool

fn report_css_ascii_decoder_bypass() {
	if bulk_css_input_probe_diagnostics && !css_ascii_decoder_bypass_reported {
		css_ascii_decoder_bypass_reported = true
		eprintln('Vox CSS input: exact UTF-8 ASCII cloned without decoder construction')
	}
}

// Tokenizer input can be an unterminated, unaligned string view. Load only
// complete words through memcpy; this avoids alignment and aliasing assumptions.
fn css_input_is_ascii(input string) bool {
	mut offset := 0
	if !disable_bulk_css_input_probes {
		if bulk_css_input_probe_diagnostics && input.len >= 32 && !css_bulk_ascii_probe_reported {
			css_bulk_ascii_probe_reported = true
			eprintln('Vox CSS input: bounded ASCII word probe')
		}
		for offset <= input.len - 32 {
			mut a := u64(0)
			mut b := u64(0)
			mut c := u64(0)
			mut d := u64(0)
			unsafe {
				C.memcpy(&a, input.str + offset, 8)
				C.memcpy(&b, input.str + offset + 8, 8)
				C.memcpy(&c, input.str + offset + 16, 8)
				C.memcpy(&d, input.str + offset + 24, 8)
			}
			if (a | b | c | d) & u64(0x8080808080808080) != 0 { return false }
			offset += 32
		}
	}
	for offset < input.len {
		if input[offset] >= 0x80 { return false }
		offset++
	}
	return true
}

fn css_input_needs_filtering(input string) bool {
	if !disable_bulk_css_input_probes && input.len >= 32 {
		if bulk_css_input_probe_diagnostics && !css_bulk_filter_probe_reported {
			css_bulk_filter_probe_reported = true
			eprintln('Vox CSS input: bounded native filter-byte search')
		}
		return unsafe { C.memchr(input.str, 0, uint(input.len)) != nil
			|| C.memchr(input.str, i32(`\r`), uint(input.len)) != nil
			|| C.memchr(input.str, i32(`\f`), uint(input.len)) != nil }
	}
	for byte in input {
		if byte == `\r` || byte == `\f` || byte == 0 { return true }
	}
	return false
}
