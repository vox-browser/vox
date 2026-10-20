module platform

import os
import time

// Under -prealloc, font caches first filled while an arena is entered must
// keep their data in the base arena: the arena is reset and reused afterwards.
fn test_font_caches_filled_inside_an_arena_survive_its_reset() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	// A path no other test decodes, so the first decode happens in the arena.
	path := os.join_path(os.temp_dir(), 'vox-arena-font-${os.getpid()}-${time.sys_mono_now()}.ttf')
	os.cp(source, path)!
	defer { os.rm(path) or {} }
	font := &Font{family: 'ArenaCacheTestFace', point_size: 16, source_path: path,
		font_rendering_policy: .chromium}
	text := 'arena ${time.sys_mono_now()}'
	mut arena := new_arena('test')
	defer { arena.release() }
	entry := arena.enter()
	face := font_face(font) or { panic('missing face') }
	width := font.glyph_width(u32(`A`))
	shaped := shape_text_cached(0, 0, 0, text, font, .ltr)
	arena.leave(entry)
	glyph_count := shaped.glyph_run.glyphs().len
	$if prealloc {
		assert !arena.contains(voidptr(shared_shaping_cache()))
		assert !arena.contains(voidptr(face))
		assert !arena.contains(voidptr(face.buf.data))
	}
	// Reuse the arena's memory so stale cache references read other data.
	arena.reset()
	again := arena.enter()
	junk := []u8{len: 1024 * 1024, init: 0xaa}
	arena.leave(again)
	assert junk.len > 0
	assert voidptr(font_face(font) or { panic('lost face') }) == voidptr(face)
	assert font.glyph_width(u32(`A`)) == width
	assert shape_text_cached(0, 0, 0, text, font, .ltr).glyph_run.glyphs().len == glyph_count
	assert glyph_count == text.len
	// Miss the shape cache after retirement to exercise the retained HarfBuzz
	// bitmap-face classification rather than just the original glyph-run hit.
	assert shape_text_cached(0, 0, 0, text + ' again', font, .ltr).glyph_run.glyphs().len == text.len + 6
}
