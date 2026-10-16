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
