module platform

import math

fn test_inline_metrics_round_on_the_device_grid_without_changing_the_font_instance() {
	raw := FontPixelMetrics{
		size:                  17
		ascent:                16.435547
		descent:               3.5859375
		line_gap:              0.625
		x_height:              8.5
		cap_height:            12.25
		advance_of_ascii_zero: 8.75
	}
	font := &Font{
		family:                'Fixture'
		point_size:            17
		font_rendering_policy: .chromium
		resolved_system_face_: SystemFontFace{ family_name: 'Fixture' }
		system_face_resolved_: true
		pixel_metrics_:        raw
		has_pixel_metrics_:    true
	}
	css := font.inline_metrics()
	assert css.ascent == 16 && css.descent == 4 && css.line_gap == 1
	device := font.inline_metrics_at_scale(2)
	assert device.ascent == 16.5 && device.descent == 3.5 && device.line_gap == 0.5
	assert device.inline_leading_scale == 2 && device.floor_inline_leading
	assert device.x_height == raw.x_height && device.cap_height == raw.cap_height
	assert device.advance_of_ascii_zero == raw.advance_of_ascii_zero
	assert device.size == raw.size && font.pixel_metrics() == raw
	assert font.inline_metrics() == css
	libweb := &Font{ ...font, font_rendering_policy: .libweb }
	assert libweb.inline_metrics_at_scale(2) == raw
	for scale in [f64(0), -1, math.nan(), math.inf(1)] {
		assert font.inline_metrics_at_scale(scale) == css
	}
}

fn test_legacy_ascent_adjustment_uses_rounded_device_metrics() {
	for family in ['Times', 'Helvetica', 'Courier'] {
		font := &Font{
			family:                family
			point_size:            13.25
			font_rendering_policy: .chromium
			resolved_system_face_: SystemFontFace{ family_name: family }
			system_face_resolved_: true
			pixel_metrics_:        FontPixelMetrics{ ascent: 10.49, descent: 3.51 }
			has_pixel_metrics_:    true
		}
		assert font.inline_metrics().ascent == 12
		assert font.inline_metrics_at_scale(2).ascent == 12.5
		assert font.inline_metrics_at_scale(2).descent == 3.5
	}
}

fn test_zero_sized_font_keeps_an_empty_strut_at_every_density() {
	for scale in [f64(1), 1.5, 2, 3] {
		font := &Font{
			family:                'Fixture'
			point_size:            0
			font_rendering_policy: .chromium
			pixel_metrics_:        FontPixelMetrics{ ascent: 1 }
			has_pixel_metrics_:    true
		}
		assert font.inline_metrics_at_scale(scale) == FontPixelMetrics{ floor_inline_leading: true }
	}
}
