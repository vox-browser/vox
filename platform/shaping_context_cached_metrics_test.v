module platform

import math

fn assert_retained_context_metrics_equal(actual ?ShapedTextContextMetrics, expected ?ShapedTextContextMetrics) {
	if oracle := expected {
		value := actual or { panic('cached metrics rejected a measured context') }
		assert math.f32_bits(value.width) == math.f32_bits(oracle.width)
		assert value.length_in_code_units == oracle.length_in_code_units
		assert value.face == oracle.face
	} else {
		assert actual == none
	}
}

fn test_retained_context_metrics_preserve_cluster_edges_and_local_f64_sums() {
	for advances in [[f32(5), 3, 7, 2], [f32(16_777_216), 1, -16_777_216, 0.125],
		[f32(-0.75), -40, 0, 1.25], [math.f32_from_bits(u32(0x7f800000)), f32(1), 2, 3]] {
		for lengths in [[1, 2, 1, 1], [0, 1, 1, 0], [1, 0, 0, 0], [0, 0, 0, 0], [2, 1, 0, 1]] {
			for face in [GlyphRunFace.document, .emoji] {
				mut glyphs := []Glyph{}
				for index in 0 .. 4 {
					glyphs << Glyph{
						advance:              advances[index]
						offset_x:             f32(index) * 0.25
						length_in_code_units: lengths[index]
						shaping_break_safety: 1
					}
				}
				shape := CachedShape{ glyphs: glyphs, face: face }
				cloned := clone_cached_shape(shape)
				assert_retained_context_metrics_equal(cached_shape_context_metrics(cloned), cached_shape_context_metrics(shape))
			}
		}
	}
	assert_retained_context_metrics_equal(cached_shape_context_metrics(clone_cached_shape(CachedShape{})), none)
}

fn test_retained_context_metrics_are_recomputed_from_the_owned_glyph_snapshot() {
	// Never trust optional metadata supplied with an incoming borrowed shape.
	mut glyphs := [Glyph{ advance: 7.25, offset_x: 0.5, length_in_code_units: 1, shaping_break_safety: 1 }]
	borrowed := CachedShape{ glyphs: glyphs, context_metrics_valid: true, context_width: 999, context_length: 999 }
	owned := clone_cached_shape(borrowed)
	glyphs[0] = Glyph{ advance: 100, length_in_code_units: 9 }
	value := cached_shape_context_metrics(owned) or { panic('owned metrics missing') }
	assert value.width == 6.75
	assert value.length_in_code_units == 1
	assert owned.glyphs[0].advance == 7.25
}

fn test_retained_context_metrics_survive_caller_scratch_and_reuse_real_shaping() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
	for text in ['AVATAR ffi To Wa Y word', 'A  B ', 'Latin punctuation — words', 'Кириллица'] {
		for spacing in [f32(0), 0.25, -0.75, -40] {
			scratch := begin_thread_scratch('retained scalar context metrics caller')
			shape := shape_text_with_spacing(0, spacing, 1.25, text.clone(), font, .ltr)
			oracle := cached_shape_context_metrics(cached_shape_from(shape))
			scratch.finish()
			mut cache := shared_shaping_cache()
			cached := cache.lookup(shaping_cache_font_key(font), text, ShapeParams.new(.ltr, spacing, 1.25)) or { panic('cached shape missing') }
			assert cached.context_metrics_valid
			assert_retained_context_metrics_equal(cached_shape_context_metrics(cached), oracle)
			assert_retained_context_metrics_equal(shaped_text_context_metrics(spacing, 1.25, text, font, .ltr), oracle)
		}
	}
}
