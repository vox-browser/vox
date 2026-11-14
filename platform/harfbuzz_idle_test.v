module platform

fn idle_harfbuzz_font() &Font {
	return &Font{family:'IdleHarfBuzzFace', point_size:16,
		source_path:bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }}
}

fn test_idle_native_font_retirement_preserves_retained_runs_and_refreshes_borrowed_faces() {
	assert harfbuzz_cache_generation == u64(1)
	font := idle_harfbuzz_font()
	old := shape_text_cached(0, 0, 0, 'Retained glyphs 123', font, .ltr)
	expected := old.glyph_run.glyphs().clone()
	old_generation := font.harfbuzz_face_generation_
	assert font.harfbuzz_face_ != unsafe { nil }
	release_unused_text_shaping()
	assert harfbuzz_cache_generation != old_generation
	for entry in harfbuzz_scaled_fonts { assert entry.font == unsafe { nil } }
	for _, face in harfbuzz_document_faces { assert face == unsafe { nil } }
	for _, blob in harfbuzz_document_blobs { assert blob == unsafe { nil } }
	assert harfbuzz_emoji_face == unsafe { nil }
	assert harfbuzz_emoji_blob == unsafe { nil }
	assert harfbuzz_bitmap_face_cache.faces.len == 0
	assert old.glyph_run.glyphs() == expected
	new := shape_text_cached(0, 0, 0, 'Retained glyphs 123', font, .ltr)
	assert new.glyph_run.glyphs() == expected
	assert font.harfbuzz_face_generation_ == harfbuzz_cache_generation
	assert harfbuzz_font_contains_glyph(font, u32(`A`))? == true
	assert old.glyph_run.glyphs() == expected
}

fn test_idle_native_font_retirement_is_idempotent_and_reuses_scaled_slots() {
	font := idle_harfbuzz_font()
	_ = shape_text_cached(0, 0, 0, 'warm face', font, .ltr)
	capacity := harfbuzz_scaled_fonts.len
	release_unused_text_shaping()
	generation := harfbuzz_cache_generation
	release_unused_text_shaping()
	assert harfbuzz_cache_generation == generation
	for _ in 0 .. 8 {
		_ = shape_text_cached(0, 0, 0, 'refilled face', font, .ltr)
		assert harfbuzz_scaled_fonts.len == capacity
		assert harfbuzz_font_contains_glyph(font, u32(`B`))? == true
		release_unused_text_shaping()
	}
}

fn test_retired_bitmap_classification_is_recomputed_from_the_new_face() {
	font := idle_harfbuzz_font()
	face := document_harfbuzz_face(font)?
	expected := harfbuzz_face_has_table(face, 0x73626978)
	assert harfbuzz_face_is_bitmap_face(face) == expected
	assert harfbuzz_bitmap_face_cache.faces.len > 0
	release_unused_text_shaping()
	assert harfbuzz_bitmap_face_cache.faces.len == 0
	next := document_harfbuzz_face(font)?
	assert harfbuzz_face_is_bitmap_face(next) == expected
}

fn test_idle_refill_keeps_native_cache_capacity_bounded() {
	font := idle_harfbuzz_font()
	axes := [FontVariationAxis{tag:0x77676874, value:400}]
	release_unused_text_shaping()
	face := document_harfbuzz_face(font)?
	_ = scaled_harfbuzz_font(face, 16, 1, axes)?
	reserved_slots := harfbuzz_scaled_fonts.len
	reserved_keys := harfbuzz_document_faces.len
	release_unused_text_shaping()
	before := thread_arena_usage().used
	for _ in 0 .. 64 {
		current := document_harfbuzz_face(font)?
		_ = scaled_harfbuzz_font(current, 16, 1, axes)?
		assert harfbuzz_scaled_fonts.len == reserved_slots
		assert harfbuzz_document_faces.len == reserved_keys
		release_unused_text_shaping()
	}
	$if prealloc { assert thread_arena_usage().used - before < 64 * 1024 }
	assert axes[0].value == 400
}
