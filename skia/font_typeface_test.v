module skia

import os

fn test_source_skia_font_decoder_rejects_magic_without_tables() {
	assert !font_typeface_is_valid([u8(0), 1, 0, 0], 0)
	assert !font_typeface_is_valid('OTTO'.bytes(), 0)
}

fn test_source_skia_font_decoder_loads_real_truetype_data() {
	$if !darwin { return }
	bytes := os.read_bytes('/System/Library/Fonts/Supplemental/Arial.ttf')!
	assert font_typeface_is_valid(bytes, 0)
}
