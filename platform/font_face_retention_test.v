module platform

import os
import time

fn test_font_retains_its_loaded_face_after_source_file_removal() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	path := os.join_path(os.temp_dir(), 'vox-retained-face-${os.getpid()}-${time.sys_mono_now()}.ttf')
	os.cp(source, path)!
	defer { os.rm(path) or {} }
	font := &Font{
		family: 'RetainedTestFace'
		point_size: 16
		source_path: path
	}
	face := font_face(font) or { panic('font did not load') }
	assert font.contains_glyph(u32(`A`))
	_, glyph_index := font.glyph_advance_and_index(u32(`A`))
	before := font.glyph_bounds(glyph_index)
	os.rm(path)!
	assert font.font_path()? == path
	assert voidptr(font_face(font)?) == voidptr(face)
	assert font.contains_glyph(u32(`A`))
	assert font.glyph_bounds(glyph_index) == before
	assert font.typeface_bounds() != none
}

fn test_missing_font_source_does_not_pin_its_fallback_face() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	path := os.join_path(os.temp_dir(), 'vox-late-face-${os.getpid()}-${time.sys_mono_now()}.ttf')
	defer { os.rm(path) or {} }
	font := &Font{
		family: 'UnavailableTestFace'
		point_size: 16
		source_path: path
	}
	fallback := font_face(font) or { panic('missing fallback') }
	assert font.font_path()? != path
	os.cp(source, path)!
	assert font.font_path()? == path
	assert voidptr(font_face(font)?) != voidptr(fallback)
	assert font.contains_glyph(u32(`A`))
}
