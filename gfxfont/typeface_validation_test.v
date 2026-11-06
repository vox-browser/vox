module gfxfont

import os

fn test_typeface_validation_rejects_magic_without_tables() {
	assert !typeface_data_is_valid([u8(0), 1, 0, 0], 0)
	assert !typeface_data_is_valid('OTTO'.bytes(), 0)
	assert !typeface_data_is_valid([]u8{}, 0)
}

fn test_typeface_validation_loads_real_truetype_data() {
	$if !darwin {
		return
	}
	bytes := os.read_bytes('/System/Library/Fonts/Supplemental/Arial.ttf')!
	assert typeface_data_is_valid(bytes, 0)
	// LibWeb's CoreText font manager cannot select another collection member.
	assert !typeface_data_is_valid(bytes, 1)
}
