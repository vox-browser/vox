module platform

fn test_context_metrics_keep_exact_sums_origins_and_cluster_boundaries() {
	shape := CachedShape{
		glyphs: [
			Glyph{ advance: 999, offset_x: 8, length_in_code_units: 0 },
			Glyph{ advance: 16_777_216, offset_x: 0.25, length_in_code_units: 1 },
			Glyph{ advance: 1, length_in_code_units: 2 },
			Glyph{ advance: -16_777_216, length_in_code_units: 1 },
			Glyph{ advance: 0.125, length_in_code_units: 1 },
			Glyph{ advance: 777, offset_x: 0.5, length_in_code_units: 0 },
		]
		face:   .document
	}
	metrics := cached_shape_context_metrics(shape) or { panic('missing metrics') }
	assert metrics.width == 1.375
	assert metrics.length_in_code_units == 5
	assert metrics.face == .document
	assert cached_shape_context_metrics(CachedShape{}) == none
	assert cached_shape_context_metrics(CachedShape{ glyphs: [Glyph{ advance: 12, length_in_code_units: 0 }] }) == none
}

fn test_context_metrics_match_cold_and_warm_shapes_without_exposing_cached_glyphs() {
	font := &Font{ family: 'SerenitySans', point_size: 13.25, font_rendering_policy: .chromium }
	for kind in [GlyphRunTextType.common, .ltr, .rtl] {
		for spacing in [f32(0), -0.75, 2.25] {
			for text in ['AV word', 'a\u0301', 'Тест Т', '文😀', 'مرحبا'] {
				platform_shaping_cache = &ShapingCache{}
				cold := shaped_text_context_metrics(spacing, 1.25, text, font, kind) or { panic('cold metrics missing') }
				full := shape_text_with_spacing(0, spacing, 1.25, text, font, kind)
				expected := cached_shape_context_metrics(cached_shape_from(full)) or { panic('full metrics missing') }
				assert cold == expected
				mut covered := 0
				for glyph in full.glyph_run.glyphs_ {
					covered += glyph.length_in_code_units
				}
				assert cold.length_in_code_units == covered
				mut changed := full.glyph_run
				changed.glyphs_[0].advance = 999
				changed.glyphs_[0].offset_x = 999
				assert shaped_text_context_metrics(spacing, 1.25, text, font, kind) or { panic('warm metrics missing') } == expected
			}
		}
	}
}

fn context_metrics_cache_ticks(cache &ShapingCache) []u64 {
	mut result := [cache.tick, u64(cache.fonts.len)]
	for font in cache.fonts {
		result << font.last_used_tick
		result << u64(font.shapes_by_text.len)
		for text in font.shapes_by_text {
			result << text.last_used_tick
			result << u64(text.shapes.len)
		}
	}
	return result
}

fn test_context_metrics_share_full_shape_cache_keys_population_and_recency() {
	font := &Font{ family: 'SerenitySans', point_size: 16 }
	full := &ShapingCache{}
	metrics := &ShapingCache{}
	for text in ['A', 'word', 'A', 'word', 'other', 'word'] {
		for kind in [GlyphRunTextType.common, .ltr, .rtl] {
			for spacing in [f32(0), 0.25] {
				platform_shaping_cache = full
				_ = shape_text_with_spacing(0, spacing, 1, text, font, kind)
				platform_shaping_cache = metrics
				_ = shaped_text_context_metrics(spacing, 1, text, font, kind) or { panic('metrics missing') }
				assert context_metrics_cache_ticks(full) == context_metrics_cache_ticks(metrics)
			}
		}
	}
}

fn test_context_metrics_cache_survives_the_callers_retired_scratch_storage() {
	font := &Font{ family: 'SerenitySans', point_size: 16 }
	platform_shaping_cache = &ShapingCache{}
	scratch := begin_thread_scratch('context metrics caller')
	text := 'AV Y with combining a\u0301'.clone()
	metrics := shaped_text_context_metrics(0.25, 1, text, font, .ltr) or { panic('cold metrics missing') }
	scratch.finish()
	assert shaped_text_context_metrics(0.25, 1, 'AV Y with combining a\u0301', font, .ltr) or { panic('retained metrics missing') } == metrics
	full := shape_text_with_spacing(0, 0.25, 1, 'AV Y with combining a\u0301', font, .ltr)
	assert cached_shape_context_metrics(cached_shape_from(full)) or { panic('full metrics missing') } == metrics
}
