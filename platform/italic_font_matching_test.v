module platform

fn test_browser_italic_fonts_select_the_actual_face_and_keep_shape_caches_distinct() {
	$if macos {
		regular := &Font{family: 'Times', point_size: 16, font_rendering_policy: .chromium}
		italic := &Font{...regular, italic: true}
		assert !regular.system_face()?.italic
		assert italic.system_face()?.italic
		assert italic.system_face()?.postscript_name == 'Times-Italic'
		assert !regular.has_same_identity(italic)
		assert shaping_cache_font_key(regular) != shaping_cache_font_key(italic)
		for _ in 0 .. 3 {
			assert shaped_text_width(0, 0, 'teleport in town - optional', regular, .ltr)
				!= shaped_text_width(0, 0, 'teleport in town - optional', italic, .ltr)
		}
		bold_italic := &Font{family: 'Times', point_size: 16, weight: 700, italic: true,
			font_rendering_policy: .chromium}
		assert bold_italic.system_face()?.italic
		assert bold_italic.system_face()?.weight >= 600
	}
	// An explicit web font has the same file for synthetic oblique, but the
	// retained run must still keep its own requested style through cache hits.
	source := bundled_font_path('SerenitySans-Regular.ttf')?
	plain := &Font{family: 'WebFont', source_path: source, point_size: 16}
	oblique := &Font{...plain, italic: true}
	assert plain.font_path()? == oblique.font_path()?
	assert shaping_cache_font_key(plain) != shaping_cache_font_key(oblique)
	assert !plain.has_same_identity(oblique)
}
