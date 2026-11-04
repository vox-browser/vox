module libjs

import os

const disable_utf16_ascii_prefix = os.getenv('VOX_DISABLE_UTF16_ASCII_PREFIX') != ''
const utf16_ascii_prefix_diagnostics = os.getenv('VOX_UTF16_ASCII_PREFIX_DIAGNOSTICS') != ''

__global utf16_ascii_prefix_reported bool

// The caller provides an equally sized byte buffer. Every read and write stays
// below that shared length; stop before the first unit requiring UTF-8 encoding.
// Inspect current units rather than relying on mutable storage metadata.
@[direct_array_access]
fn utf16_copy_ascii_prefix(data []u16, mut output []u8) int {
	mut index := 0
	for index < data.len {
		unit := data[index]
		if unit >= 0x80 { break }
		output[index] = u8(unit)
		index++
	}
	if utf16_ascii_prefix_diagnostics && !utf16_ascii_prefix_reported && index >= 32 {
		utf16_ascii_prefix_reported = true
		eprintln('Vox UTF16 ASCII prefix: copied=${index} input=${data.len}')
	}
	return index
}
