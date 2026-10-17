module platform

fn test_system_font_matching_selects_chromium_macos_faces() {
	$if macos {
		regular := &Font{ family: 'SystemUi', point_size: 16, weight: 400, font_rendering_policy: .chromium }
		face := regular.system_face() or { panic('system-ui has no face') }
		assert face.path == '/System/Library/Fonts/SFNS.ttf'
		assert face.face_index == 0
		assert face.variations == [FontVariationAxis{tag: 0x6f70737a, value: 17}]
		bold := (&Font{ family: 'SystemUi', point_size: 16, weight: 700, font_rendering_policy: .chromium }).system_face() or { panic('bold') }
		assert FontVariationAxis{tag: 0x77676874, value: 700} in bold.variations
		helvetica := (&Font{ family: 'SansSerif', point_size: 16, weight: 700, font_rendering_policy: .chromium }).system_face() or { panic('sans') }
		assert helvetica.path == '/System/Library/Fonts/Helvetica.ttc' && helvetica.face_index == 1
		times := (&Font{ family: 'Default', point_size: 16, weight: 400, font_rendering_policy: .chromium }).system_face() or { panic('default') }
		assert times.path == '/System/Library/Fonts/Times.ttc' && times.face_index == 0
		black := (&Font{ family: 'Hoefler Text', point_size: 32, weight: 700, font_rendering_policy: .chromium }).system_face() or { panic('hoefler') }
		assert black.postscript_name == 'HoeflerText-Black'
		assert chromium_system_font_family_available('Georgia')
		assert !chromium_system_font_family_available('-apple-system')
		assert !chromium_system_font_family_available('Linux Libertine')
		assert !chromium_system_font_family_available('.SF NS')
		// Documents without the Chromium policy keep the configured faces.
		assert (&Font{ family: 'SystemUi', point_size: 16, weight: 400 }).system_face() == none
		assert system_fallback_font(0x65e5, 'ja', &Font{ family: 'SystemUi', point_size: 16, weight: 400 }) == none
	}
}

fn test_system_fallback_uses_language_specific_cjk_faces() {
	$if macos {
		base := &Font{ family: 'SystemUi', point_size: 16, weight: 700, font_rendering_policy: .chromium }
		assert !base.contains_glyph(0x65e5)
		japanese := system_fallback_font(0x65e5, 'ja', base) or { panic('ja') }
		assert japanese.system_face()?.postscript_name == 'HiraKakuProN-W6'
		simplified := system_fallback_font(0x4e2d, 'zh-Hans', base) or { panic('zh') }
		assert simplified.system_face()?.postscript_name == 'PingFangSC-Semibold'
		// PingFang has no GPOS; its AAT 'trak' tracking still widens each glyph,
		// as Brave measures (32.640625px for 中文 at 16px).
		assert shaped_text_width(0, 0, '中文', simplified, .ltr) == f32(32.640015)
		regular := &Font{ family: 'SystemUi', point_size: 13, weight: 400, font_rendering_policy: .chromium }
		traditional := system_fallback_font(0x689d, 'nan', regular) or { panic('nan') }
		assert traditional.system_face()?.postscript_name == 'PingFangTC-Regular'
		korean := system_fallback_font(0xd55c, 'ko', regular) or { panic('ko') }
		assert korean.system_face()?.postscript_name == 'AppleSDGothicNeo-Regular'
		// Scripts without a preference use CoreText's language-aware cascade.
		bengali := system_fallback_font(0x09ac, 'bn', regular) or { panic('bn') }
		assert bengali.contains_glyph(0x09ac)
		assert system_fallback_font(u32(`A`), 'en', regular) == none
	}
}

fn test_browser_spacing_never_makes_advances_negative() {
	$if macos {
		font := &Font{ family: 'SystemUi', point_size: 14, weight: 400, font_rendering_policy: .chromium }
		// SF's 14px space is 3.787px; Brave closes a -4px word-spaced gap to zero.
		assert shaped_text_width(0, -4, ' ', font, .ltr) == 0
		assert shaped_text_width(0, -2, ' ', font, .ltr) == f32(1.787109375)
		libweb := &Font{ ...font, font_rendering_policy: .libweb }
		assert shaped_text_width(0, -40, ' ', libweb, .ltr) < 0
	}
}

fn test_system_face_typeface_bounds_use_the_coretext_face_box() {
	$if macos {
		for font in [&Font{ family: 'SansSerif', point_size: 16, weight: 400, font_rendering_policy: .chromium },
			&Font{ family: 'SystemUi', point_size: 13, weight: 700, font_rendering_policy: .chromium }] {
			face := font.system_face() or { panic('missing system face') }
			bounds := font.typeface_bounds() or { panic('missing typeface bounds') }
			assert bounds.x_min == f32(face.metrics.bbox_x_min) && bounds.x_max == f32(face.metrics.bbox_x_max)
			assert bounds.y_min == f32(face.metrics.bbox_y_min) && bounds.y_max == f32(face.metrics.bbox_y_max)
			// The face box contains the ascent and descent at the matched size.
			assert bounds.y_max >= f32(face.metrics.ascent) * 0.8 && bounds.y_min < 0
			assert bounds.x_max - bounds.x_min > font.point_size * 0.5
			_, glyph_index := font.glyph_advance_and_index(u32(`W`))
			glyph := font.glyph_bounds(glyph_index)
			assert bounds.x_min <= glyph.x_min && bounds.x_max >= glyph.x_max
			assert bounds.y_min <= glyph.y_min && bounds.y_max >= glyph.y_max
		}
	}
}

fn test_chromium_devanagari_falls_back_to_kohinoor() {
	$if macos {
		base := &Font{ family: 'SystemUi', point_size: 14, weight: 400, font_rendering_policy: .chromium }
		for language in ['mr', 'hi', ''] {
			font := system_fallback_font(0x092e, language, base) or { panic('no Devanagari fallback') }
			assert font.system_face()?.postscript_name == 'KohinoorDevanagari-Regular'
		}
		// Brave measures 29.421875px for मराठी at 14px.
		font := system_fallback_font(0x092e, 'mr', base) or { panic('no fallback') }
		width := shaped_text_width(0, 0, 'मराठी', font, .ltr)
		assert width > 29.40 && width <= 29.421875
	}
}

// Code points that fall back to the same face share one Font, so the chunk
// iterator keeps them in one shaped run.
fn test_system_fallback_fonts_are_shared_by_face() {
	$if macos {
		base := &Font{ family: 'SystemUi', point_size: 13, weight: 400, font_rendering_policy: .chromium }
		first := system_fallback_font(0x0b95, 'ta', base) or { panic('no Tamil fallback') }
		second := system_fallback_font(0x0bae, 'ta', base) or { panic('no Tamil fallback') }
		assert voidptr(first) == voidptr(second)
	}
}
