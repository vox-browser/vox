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

fn test_lazy_glyph_outlines_survive_paint_arena_retirement() {
	path := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	mut bytes := os.read_bytes(path)!
	face := decode_outline_face(mut bytes)
	font := &Font{family: 'GlyphArenaTestFace', point_size: 16, decoded_face_: face}
	// Use a separate face for the reference so the tested cache stays cold.
	mut reference_bytes := os.read_bytes(path)!
	reference := &Font{family: 'GlyphArenaReference', point_size: 16,
		decoded_face_: decode_outline_face(mut reference_bytes)}
	mut glyphs := []int{}
	mut expected := []FontGlyphOutline{}
	for character in [`A`, `Q`, `g`] {
		_, glyph := font.glyph_advance_and_index(u32(character))
		assert glyph > 0
		glyphs << glyph
		expected << reference.glyph_outline(glyph) or { panic('missing reference outline') }
	}
	mut arena := new_arena('display-list')
	defer { arena.release() }
	for pass in 0 .. 3 {
		entry := arena.enter()
		mut outlines := []FontGlyphOutline{}
		for glyph in glyphs {
			// First decode in an arena; later passes hit the surviving glyph map.
			outlines << font.glyph_outline(glyph) or { panic('missing cached outline') }
		}
		arena.leave(entry)
		for index, glyph in glyphs {
			outline := outlines[index]
			assert outline == expected[index]
			$if prealloc {
				// Scaled paint output remains temporary; only the font's cache persists.
				assert arena.contains(outline.contours.data)
				assert arena.contains(outline.contours[0].data)
				cached := face.glyph_cache[glyph] or { panic('glyph was not cached') }
				assert !arena.contains(cached.points.data)
				assert !arena.contains(cached.contour_ends.data)
			}
		}
		arena.reset()
		// Also exercise a cache miss after retirement.
		if pass == 0 {
			_, glyph := font.glyph_advance_and_index(u32(`y`))
			glyphs << glyph
			expected << reference.glyph_outline(glyph) or { panic('missing reference outline') }
		}
	}
}
