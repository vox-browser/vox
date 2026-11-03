module platform

fn test_archived_font_grid_preserves_raw_metrics_and_zero_struts() {
	raw := FontPixelMetrics{size:17, ascent:16.435547, descent:3.5859375,
		line_gap:0.625, x_height:8.5, cap_height:12.25, advance_of_ascii_zero:8.75}
	font := &Font{
		family:'Fixture'
		point_size:17
		font_rendering_policy:.chromium
		resolved_system_face_:SystemFontFace{family_name:'Fixture'}
		system_face_resolved_:true
		pixel_metrics_:raw
		has_pixel_metrics_:true
	}
	device := font.inline_metrics_at_scale(2)
	assert device.ascent == if retain_logical_inline_font_grid { f32(16) } else { f32(16.5) }
	assert device.descent == if retain_logical_inline_font_grid { f32(4) } else { f32(3.5) }
	assert device.line_gap == if retain_logical_inline_font_grid { f32(1) } else { f32(0.5) }
	assert device.inline_leading_scale == if retain_logical_inline_font_grid { 1.0 } else { 2.0 }
	assert font.pixel_metrics() == raw
	assert device.x_height == raw.x_height && device.cap_height == raw.cap_height
	assert device.advance_of_ascii_zero == raw.advance_of_ascii_zero
	libweb := &Font{...font, font_rendering_policy:.libweb}
	assert libweb.inline_metrics_at_scale(2) == raw
	zero := &Font{...font, point_size:0}
	assert zero.inline_metrics_at_scale(2) == FontPixelMetrics{floor_inline_leading:true}
}
