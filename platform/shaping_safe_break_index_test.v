module platform

fn test_indexed_safe_ranges_match_checked_scan_at_every_cluster_boundary() {
	for advances in [[f32(5), 3, 7, 2], [f32(16_777_216), 1, -16_777_216, 0.125]] {
		shape := CachedShape{
			glyphs: [
				Glyph{ advance: advances[0], offset_x: 0.25, length_in_code_units: 1, shaping_break_safety: 1 },
				Glyph{ advance: advances[1], length_in_code_units: 2, shaping_break_safety: 2 },
				Glyph{ advance: advances[2], offset_x: 0.5, length_in_code_units: 1, shaping_break_safety: 1 },
				Glyph{ advance: advances[3], offset_x: 8, length_in_code_units: 1, shaping_break_safety: 1 },
			]
		}
		indexed := clone_cached_shape(shape)
		assert indexed.safe_break_boundaries == [0, 1, -1, 2, 3, 4]
		for start in -1 .. 7 {
			for length in 0 .. 8 {
				for total in [4, 5, 6] {
					oracle := cached_shape_safe_break_width(shape, start, length, total)
					actual := cached_shape_safe_break_width(indexed, start, length, total)
					if width := oracle {
						assert actual or { panic('indexed range rejected') } == width
					} else {
						assert actual == none
					}
				}
			}
		}
	}
}

fn test_safe_break_indices_reject_unknown_and_oversized_coverage() {
	assert cached_shape_safe_break_boundaries(CachedShape{}) == []int{}
	for length in [0, -1, 1_048_577] {
		shape := CachedShape{ glyphs: [Glyph{ length_in_code_units: length, shaping_break_safety: 1 }] }
		assert cached_shape_safe_break_boundaries(shape) == []int{}
	}
	for safety in [u8(0), 3] {
		shape := CachedShape{
			glyphs: [
				Glyph{ length_in_code_units: 1, shaping_break_safety: 1 },
				Glyph{ length_in_code_units: 1, shaping_break_safety: safety },
			]
		}
		assert cached_shape_safe_break_boundaries(shape) == []int{}
	}
	shape := CachedShape{ glyphs: [Glyph{ length_in_code_units: 1, shaping_break_safety: 1 }], face: .emoji }
	assert cached_shape_safe_break_boundaries(shape) == []int{}
	oversized := CachedShape{
		glyphs: [
			Glyph{ length_in_code_units: 1_048_576, shaping_break_safety: 1 },
			Glyph{ length_in_code_units: 1, shaping_break_safety: 1 },
		]
	}
	assert cached_shape_safe_break_boundaries(oversized) == []int{}
	// The bounded index is optional: its absence preserves the checked scan.
	assert cached_shape_safe_break_width(oversized, 1_048_576, 1, 1_048_577) != none
}

fn test_safe_break_indices_belong_to_cache_storage_after_caller_scratch_retires() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
	scratch := begin_thread_scratch('safe break index caller')
	text := 'AVATAR ffi To Wa Y word'.clone()
	shape := shape_text_with_spacing(0, 0.25, 1, text, font, .ltr)
	oracle := cached_shape_from(shape)
	width := cached_shape_safe_break_width(oracle, 0, text.len, text.len) or { panic('missing reference width') }
	scratch.finish()
	mut cache := shared_shaping_cache()
	cached := cache.lookup(shaping_cache_font_key(font), 'AVATAR ffi To Wa Y word', ShapeParams.new(.ltr, 0.25, 1)) or { panic('missing cached shape') }
	assert cached.safe_break_boundaries.len == 'AVATAR ffi To Wa Y word'.len + 1
	assert shaped_text_safe_break_width(0.25, 1, 'AVATAR ffi To Wa Y word', 0, 23, font) or { panic('retired safe index') } == width
}
