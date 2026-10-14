module platform

import os
import time

fn test_glyph_units_follow_the_decoded_face_after_an_explicit_source_appears() {
	source := bundled_font_path('NotoEmoji.ttf') or { panic('missing test font') }
	path := os.join_path(os.temp_dir(), 'vox-late-glyphs-${os.getpid()}-${time.sys_mono_now()}.ttf')
	defer { os.rm(path) or {} }
	font := &Font{
		family:      'LateGlyphFixture'
		point_size:  16.5
		source_path: path
	}
	fallback_advance, _ := font.glyph_metrics(u32(`0`))
	os.cp(source, path)!
	loaded_advance, loaded_index := font.glyph_metrics(u32(`0`))
	expected := Font{
		family:      'LateGlyphFixture'
		point_size:  16.5
		source_path: source
	}
	expected_advance, expected_index := expected.glyph_metrics(u32(`0`))
	assert loaded_advance == expected_advance
	assert loaded_index == expected_index
	assert loaded_advance != fallback_advance
}

fn test_glyph_units_preserve_advances_and_indices_across_aliases_and_sizes() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	first := Font{
		family:      'FirstFaceAlias'
		point_size:  12
		source_path: source
	}
	second := Font{
		family:      'SecondFaceAlias'
		point_size:  24
		weight:      700
		source_path: source
	}
	first_advance, first_index := first.glyph_metrics(u32(`M`))
	second_advance, second_index := second.glyph_metrics(u32(`M`))
	assert second_advance == first_advance * 2
	assert second_index == first_index
}
