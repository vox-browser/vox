module layout

import html
import math
import painting
import platform

fn test_fractional_underline_thickness_and_offset_follow_the_live_device_grid() {
	mut document := html.parse_document('<!doctype html><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	result := document_layout_result(document) or { panic('layout') }
	fragment := TextFragment{
		x:                        10.25
		y:                        4.4
		width:                    20.25
		height:                   15
		font_size:                13.333333
		decoration:               'underline'
		decoration_skip_ink:      false
		font_metrics_set:         true
		font_ascent:              12.07
		font_descent:             2.83
		decoration_thickness:     2.6
		decoration_thickness_set: true
		text_underline_offset:    1.4
		chromium_decorations:     true
		layout_handle:            voidptr(result.root)
	}
	for density in [f64(1), 2, 1] {
		document.set_display_device_pixel_ratio(density)
		commands := paint_text_decoration(fragment, 0.75)
		assert commands.len == 1
		command := commands[0]
		assert command.x == 10.25 && command.width == 20.25
		assert command.y == if density == 2 { 18.0 } else { 17.0 }
		assert command.height == if density == 2 { 2.5 } else { 3.0 }
		assert command.opacity == 0.75 && command.clip_outs.len == 0
	}
}

fn test_auto_underlines_allow_one_device_pixel_for_small_fonts() {
	fragment := TextFragment{
		y:                          4.4
		width:                      50
		font_size:                  9
		text_underline_offset_auto: true
	}
	logical := chromium_underline_geometry(fragment, 8.15, 1)
	device := chromium_underline_geometry(fragment, 8.15, 2)
	assert logical.top == 13 && logical.height == 1
	assert device.top == 13 && device.height == 0.5
	assert device.thickness == 0.9 && device.line_offset == 8.5
	assert chromium_underline_geometry(TextFragment{
		y:                          20.25
		font_size:                  14
		text_underline_offset_auto: true
	}, 13.53515625, 2).top == 35
}

fn test_device_skip_ink_uses_the_actual_aligned_glyph_baseline() {
	mut document := html.parse_document('<!doctype html><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_display_device_pixel_ratio(2)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	result := document_layout_result(document) or { panic('layout') }
	font := &platform.Font{ family: 'Fixture', point_size: 14, font_rendering_policy: .chromium }
	run := platform.GlyphRun.new(font, .ltr, [platform.Glyph{ code_point: u32(`g`), advance: 6 }])
	fragment := TextFragment{
		y:                  20.75
		baseline:           13.5
		baseline_set:       true
		paint_line_top:     20.265625
		layout_handle:      voidptr(result.root)
		paintable_fragment: painting.PaintableFragment{ glyph_run: run }
	}
	stripe := chromium_device_skip_ink_stripe(fragment, 13.53515625, 14.5, 1.4, 2)
	assert stripe.upper == 1.015625
	assert math.abs(stripe.width - 0.9) < 1e-9
	assert stripe.clip_top == 35 && math.abs(stripe.clip_bottom - 36.9) < 1e-9
	shifted := chromium_device_skip_ink_stripe(TextFragment{ ...fragment, baseline: 12.5 },
		13.53515625, 14.5, 1.4, 2)
	assert shifted.upper == stripe.upper + 1
	assert shifted.clip_top == stripe.clip_top && shifted.clip_bottom == stripe.clip_bottom
	assert chromium_device_skip_ink_clips(TextFragment{ decoration_skip_ink: false },
		13.53515625, 14.5, 1.4, 2).len == 0
}

fn test_underlines_follow_the_fragment_baseline_with_positive_and_negative_leading() {
	for density in [f64(1), 2] {
		for baseline in [f64(9), 10, 11, 14] {
			fragment := TextFragment{
				y: 617.171875
				font_size: 13.008
				baseline: baseline
				baseline_set: true
				text_underline_offset_auto: true
			}
			geometry := chromium_underline_geometry(fragment, 10.4064, density)
			gap := math.max(1.0, math.ceil(fragment.font_size * density / 20)) / density
			assert geometry.line_offset == baseline + gap
			assert geometry.top == math.floor((fragment.y + baseline + gap) * density + 0.5) / density
		}
	}
}
