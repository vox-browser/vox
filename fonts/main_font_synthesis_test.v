module main

import platform

fn test_retained_font_synthesis_flags_preserve_face_matching_and_real_outlines() {
	base := &platform.Font{
		family:                'Arial'
		point_size:            16
		weight:                700
		italic:                true
		font_rendering_policy: .chromium
	}
	automatic := native_retained_font_smoothing(.antialiased, base)
	assert automatic & 64 != 0
	assert automatic & 128 == 0
	style := native_retained_font_smoothing(.antialiased,
		&platform.Font{ ...base, font_synthesis_disabled: platform.font_synthesis_style_disabled })
	assert style & 64 == 0 && style & 128 == 0
	all := native_retained_font_smoothing(.antialiased,
		&platform.Font{ ...base, font_synthesis_disabled: 15 })
	assert all & 64 == 0 && all & 128 != 0
	assert all & 15 == automatic & 15
}
