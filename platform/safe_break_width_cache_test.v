module platform

// Written but deliberately not compiled or run until Brave parity.
fn test_safe_break_handle_ranges_and_dynamic_identity() {
	release_unused_text_shaping()
	mut local := SafeBreakWidthCache{}
	mut font := &Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
	for text in ['AVATAR ffi To Wa Y word', 'it’s a “normal” word…', 'A  repeated space'] {
		units := utf16_code_units(text)
		for spacing in [[f32(0), 0], [f32(0.25), 1.25], [f32(-0.75), 0]] {
			_ = shape_text_with_spacing(0, spacing[0], spacing[1], text, font, .ltr)
			for collapses in [false, true] {
				for start in 0 .. units.len {
					for end in start + 1 .. units.len + 1 {
						expected := shaped_text_safe_break_width(spacing[0], spacing[1], text, start, end - start, font)
						actual := shaped_text_safe_break_width_cached(mut local, spacing[0], spacing[1], text, start, end - start, font, collapses)
						if collapses && text.contains('  ') { assert actual == none } else { assert actual == expected }
					}
				}
			}
		}
	}
	text := 'Retained words'
	_ = shape_text_with_spacing(0, 0, 0, text, font, .ltr)
	assert shaped_text_safe_break_width_cached(mut local, 0, 0, text, 0, text.len, font, true) != none
	old_generation := local.generation
	release_unused_text_shaping()
	assert old_generation != platform_safe_break_cache_generation
	assert shaped_text_safe_break_width_cached(mut local, 0, 0, text, 0, text.len, font, true) == none
	_ = shape_text_with_spacing(0, 0, 0, text, font, .ltr)
	assert shaped_text_safe_break_width_cached(mut local, 0, 0, text, 0, text.len, font, true) != none
	font.point_size = 21
	assert shaped_text_safe_break_width_cached(mut local, 0, 0, text, 0, text.len, font, true) == none
	_ = shape_text_with_spacing(0, 0, 0, text, font, .ltr)
	assert shaped_text_safe_break_width_cached(mut local, 0, 0, text, 0, text.len, font, true) == shaped_text_safe_break_width(0, 0, text, 0, text.len, font)
}

fn test_safe_break_handle_updates_recency_and_survives_eviction_and_scratch_keys() {
	release_unused_text_shaping()
	font := &Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
	mut local := SafeBreakWidthCache{}
	scratch := begin_thread_scratch('deferred safe break handle ownership')
	text := 'Independent cached words'.clone()
	_ = shape_text_with_spacing(0, 0, 0, text, font, .ltr)
	width := shaped_text_safe_break_width_cached(mut local, 0, 0, text, 0, text.len, font, false) or { panic('no safe range') }
	scratch.finish()
	mut shared := shared_shaping_cache()
	before := shared.tick
	assert shaped_text_safe_break_width_cached(mut local, 0, 0, 'Independent cached words', 0, 24, font, false) or { panic('retired key') } == width
	assert shared.tick == before + 1
	assert shared.fonts[local.font_index].last_used_tick == shared.tick
	assert shared.fonts[local.font_index].shapes_by_text[local.text_index].last_used_tick == shared.tick
	shared.evict_least_recently_used_texts(local.font_index)
	assert local.generation != platform_safe_break_cache_generation
	assert shaped_text_safe_break_width_cached(mut local, 0, 0, 'Independent cached words', 0, 24, font, false) == none
	_ = shape_text_with_spacing(0, 0, 0, 'Independent cached words', font, .ltr)
	assert shaped_text_safe_break_width_cached(mut local, 0, 0, 'Independent cached words', 0, 24, font, false) != none
	shared.evict_least_recently_used_font()
	assert local.generation != platform_safe_break_cache_generation
	assert shaped_text_safe_break_width_cached(mut local, 0, 0, 'Independent cached words', 0, 24, font, false) == none
}
