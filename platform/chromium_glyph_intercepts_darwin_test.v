// vtest build: macos
module platform

fn test_skip_ink_spaces_keep_the_cookie_link_variable_outlines() {
	font := &Font{
		family:                'system-ui'
		point_size:            28
		font_rendering_policy: .chromium
		system_face_override:  SystemFontFace{
			path:            '/System/Library/Fonts/SFNS.ttf'
			postscript_name: '.SFNS-Regular'
			variations:      [FontVariationAxis{ tag: 1869640570, value: 17 }]
		}
	}
	run := shape_text(0, 0, 'cookie policy', font, .ltr)
	// Recorded from the pre-migration native path-intersection oracle. A
	// pathless space must not send the whole run to default TrueType contours.
	assert run.glyph_intercepts(1, 1.5, 2.5) == [f32(99.640625), 102.01953, 167.90184, 170.9291]
}

fn test_variable_glyph_intercepts_use_the_replayed_optical_instance() {
	font := &Font{ family: 'system-ui', point_size: 14, font_rendering_policy: .chromium }
	assert font.variations().len > 0
	run := shape_text(0, 0, 'g y p', font, .ltr)
	intervals := chromium_variable_glyph_intercepts(run, 2, 1, 3) or { panic('missing variable outlines') }
	assert intervals.len == 6
	for i := 0; i < intervals.len; i += 2 {
		assert intervals[i] < intervals[i + 1]
		assert intervals[i] >= 0 && intervals[i + 1] <= run.width() * 2
	}
	assert run.glyph_intercepts(2, 1, 3) == intervals
	assert chromium_variable_glyph_intercepts(run, 2, 3, 1) == none
}

fn test_cubic_ink_intercepts_follow_the_curve_inside_the_band() {
	mut extent := GlyphInkExtent{ band_top: 1, band_bottom: 2 }
	extent.add_cubic(FontGlyphOutlinePoint{ x: 0, y: 0 }, FontGlyphOutlinePoint{ x: 0, y: -4 },
		FontGlyphOutlinePoint{ x: 4, y: -4 }, FontGlyphOutlinePoint{ x: 4, y: 0 })
	assert extent.left > 0 && extent.left < 1
	assert extent.right > 3 && extent.right < 4
}
