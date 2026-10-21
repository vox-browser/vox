module platform

fn test_idle_release_retires_cache_payloads_without_retiring_published_glyphs() {
	$if prealloc {
		release_unused_text_shaping()
		font := &Font{ family: 'sans-serif', point_size: 16 }
		first := shape_text_cached(3, 0.25, 1, 'Published glyph storage survives cache retirement', font, .ltr)
		original := first.glyph_run.glyphs().clone()
		mut storage := platform_shaping_cache_storage
		assert storage != unsafe { nil }
		assert storage.usage().used > 0
		assert storage.contains(voidptr(platform_shaping_cache.fonts.data))
		assert !storage.contains(voidptr(first.glyph_run.glyphs().data))
		before := storage.reset_count()
		release_unused_text_shaping()
		assert storage.reset_count() == before + 1
		assert storage.usage().used == 0
		assert first.glyph_run.glyphs() == original
		// Hit the same shared storage again after it has been made unreadable in
		// poison mode; both the new miss and the subsequent hit must own outputs.
		second := shape_text_cached(3, 0.25, 1, 'Published glyph storage survives cache retirement', font, .ltr)
		third := shape_text_cached(3, 0.25, 1, 'Published glyph storage survives cache retirement', font, .ltr)
		assert voidptr(platform_shaping_cache_storage) == voidptr(storage)
		assert second.glyph_run.glyphs() == original
		assert third.glyph_run.glyphs() == original
		assert !storage.contains(voidptr(second.glyph_run.glyphs().data))
		assert !storage.contains(voidptr(third.glyph_run.glyphs().data))
		release_unused_text_shaping()
		assert storage.usage().used == 0
		assert second.glyph_run.glyphs() == original
		assert third.glyph_run.glyphs() == original
	}
}
