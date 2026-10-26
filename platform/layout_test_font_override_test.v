module platform

import os

fn test_layout_test_font_overrides_installed_faces_and_fallbacks() {
	regular := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	// The upstream test assets contain only the regular face. A second file
	// checks that the explicit bold override wins without needing a system font.
	bold := os.join_path(os.temp_dir(), 'vox-layout-test-bold-${os.getpid()}.ttf')
	os.cp(regular, bold)!
	defer { os.rm(bold) or {} }
	previous := os.getenv_opt('LADYBIRD_LAYOUT_TEST_FONT')
	previous_bold := os.getenv_opt('LADYBIRD_LAYOUT_TEST_BOLD_FONT')
	previous_paths := harfbuzz_family_paths.clone()
	previous_attempts := harfbuzz_family_attempted.clone()
	for weight in [400, 700] {
		key := 'gill sans|${weight}'
		harfbuzz_family_paths.delete(key)
		harfbuzz_family_attempted.delete(key)
	}
	defer {
		harfbuzz_family_paths = previous_paths.clone()
		harfbuzz_family_attempted = previous_attempts.clone()
		if value := previous {
			os.setenv('LADYBIRD_LAYOUT_TEST_FONT', value, true)
		} else {
			os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
		}
		if value := previous_bold {
			os.setenv('LADYBIRD_LAYOUT_TEST_BOLD_FONT', value, true)
		} else {
			os.unsetenv('LADYBIRD_LAYOUT_TEST_BOLD_FONT')
		}
	}
	os.setenv('LADYBIRD_LAYOUT_TEST_FONT', regular, true)
	os.setenv('LADYBIRD_LAYOUT_TEST_BOLD_FONT', bold, true)
	for weight in [400, 700] {
		// Gill Sans normally selects a collection member for bold. The configured
		// layout-test fonts are separate files with a single face each.
		font := &Font{ family: 'Gill Sans', point_size: 16, weight: weight, font_rendering_policy: .chromium }
		assert font.system_face() == none
		assert font.font_path()? == if weight == 700 { bold } else { regular }
		assert font.face_index() == 0
		assert system_fallback_font(0x65e5, 'ja', font) == none
		assert font.contains_glyph(u32(`A`))
	}
	assert !chromium_system_font_family_available('Georgia')
	assert !chromium_system_font_family_available('system-ui')
}
