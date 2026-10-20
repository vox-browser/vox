module platform

fn test_idle_shaping_release_preserves_live_runs_and_refills_exactly() {
	font := &Font{family: 'sans-serif', point_size: 16}
	text := 'Live shaped text remains owned after idle cleanup'
	first := shape_text_cached(0, 0, 0, text, font, .common)
	glyphs := first.glyph_run.glyphs().clone()
	width := first.glyph_run.width()
	assert platform_shaping_cache != unsafe { nil }
	assert platform_shaping_cache.fonts.len > 0
	release_unused_text_shaping()
	assert platform_shaping_cache == unsafe { nil }
	gc_collect()
	assert first.glyph_run.glyphs() == glyphs
	assert first.glyph_run.width() == width
	assert shaped_text_width(0, 0, text, font, .common) == width
	assert platform_shaping_cache.fonts.len > 0
	second := shape_text_cached(0, 0, 0, text, font, .common)
	assert second.glyph_run.glyphs() == glyphs
	assert second.glyph_run.glyphs().data != first.glyph_run.glyphs().data
	release_unused_text_shaping()
	release_unused_text_shaping()
	assert second.glyph_run.glyphs() == glyphs
}
