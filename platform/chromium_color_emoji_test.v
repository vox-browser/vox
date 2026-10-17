module platform

// 4chan's announcement: Blink draws 🎉 with the Apple Color Emoji face CoreText
// selects as a fallback, rather than with the bundled monochrome Noto Emoji.
fn test_chromium_emoji_shapes_with_the_selected_color_emoji_face() {
	$if macos {
		base := &Font{
			family:                'Arial'
			point_size:            19.5
			weight:                700
			font_rendering_policy: .chromium
		}
		fallback := system_fallback_font(0x1f389, '', base) or { panic('no emoji fallback') }
		assert fallback.family.contains('Apple Color Emoji')
		assert font_supplies_chromium_emoji(fallback, '🎉')
		shaped := shape_text_with_harfbuzz(0, 0, 0, '🎉', fallback, .ltr) or { panic('shaping failed') }
		assert shaped.glyph_run.face() == .document
		face := document_harfbuzz_face(fallback) or { panic('no face') }
		assert harfbuzz_face_is_bitmap_face(face)
		libweb := &Font{
			...fallback
			font_rendering_policy: .libweb
		}
		assert !font_supplies_chromium_emoji(libweb, '🎉')
	}
	assert !font_supplies_chromium_emoji(&Font{ family: 'Arial', font_rendering_policy: .chromium },
		'plain')
}
