module main

import os

const retain_incremental_webp_paint_policy = os.getenv('VOX_RETAIN_INCREMENTAL_WEBP_PAINT_POLICY') == '1'

// Historical frozen-page comparisons retain the paint policy they captured.
// Current completed-resource decoding remains the default. This explicit
// control preserves the former transport-based RGB selection without changing
// completed images, references or tolerances during a matched comparison.
fn (app &BrowserApp) webp_complete_yuv_allowed(address string, bytes []u8) bool {
	if !retain_incremental_webp_paint_policy { return true }
	resource := app.resource_cache[address] or { return true }
	return !(resource.body.len == bytes.len && resource.body == bytes.bytestr()
		&& resource.bytes_available_before_completion >= 30 && bytes.len >= 30
		&& bytes[..4].bytestr() == 'RIFF' && bytes[8..16].bytestr() == 'WEBPVP8 ')
}
