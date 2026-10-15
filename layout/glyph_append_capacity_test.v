module layout

import css
import platform

fn append_capacity_test_run(count int, text_type platform.GlyphRunTextType) &platform.GlyphRun {
	mut glyphs := []platform.Glyph{cap: count}
	for i in 0 .. count {
		glyphs << platform.Glyph{
			code_point: u32(`a`)
			glyph_index: i + 1
			position: platform.GlyphPosition{f32(i), 0}
			advance: 1
		}
	}
	return platform.GlyphRun.new(&platform.Font{family: 'serif', point_size: 16}, text_type, glyphs)
}

fn test_long_ltr_appends_keep_cached_glyphs_and_other_forks_independent() {
	source := append_capacity_test_run(4, .ltr)
	other := source.fork_for_layout()
	mut merged := source.fork_for_layout()
	mut fragment := LineBoxFragment{direction_: .ltr, current_insert_direction: .ltr,
		inline_length_: CSSPixels.new(4), glyph_run_: merged}
	chunk := append_capacity_test_run(97, .ltr)
	for _ in 0 .. 5 { fragment.append_glyph_run(chunk, CSSPixels.new(97)) }
	gc_collect()
	merged.refresh_replay_data()
	assert merged.glyphs_.len == 489
	assert fragment.inline_length().to_double() == 489
	for i, glyph in merged.glyphs_ { assert glyph.position.x == f32(i) }
	assert merged.glyph_indices().len == 489
	assert merged.glyph_positions().len == 978
	assert source.glyphs_.len == 4 && other.glyphs_.len == 4
	assert source.glyphs_[0].position.x == 0 && other.glyphs_[0].position.x == 0
	assert chunk.glyphs_.len == 97 && chunk.glyphs_[0].position.x == 0
}

fn test_long_rtl_appends_keep_shifted_positions_and_end_padding_behavior() {
	source := append_capacity_test_run(4, .rtl)
	mut merged := source.fork_for_layout()
	mut fragment := LineBoxFragment{direction_: .rtl, current_insert_direction: .rtl,
		inline_length_: CSSPixels.new(4), glyph_run_: merged}
	chunk := append_capacity_test_run(97, .rtl)
	for _ in 0 .. 3 { fragment.append_glyph_run(chunk, CSSPixels.new(97)) }
	assert merged.glyphs_.len == 295
	for i in 0 .. 4 { assert merged.glyphs_[i].position.x == f32(291 + i) }
	for block in 0 .. 3 {
		for i in 0 .. 97 { assert merged.glyphs_[4 + block * 97 + i].position.x == f32((2 - block) * 97 + i) }
	}
	padding := append_capacity_test_run(1, .end_padding)
	fragment.append_glyph_run(padding, CSSPixels.new(1))
	gc_collect()
	merged.refresh_replay_data()
	assert merged.glyphs_[0].position.x == 291
	assert merged.glyphs_.last().position.x == 0
	assert source.glyphs_[0].position.x == 0 && chunk.glyphs_[0].position.x == 0
	assert merged.glyph_indices().len == 296
}

fn test_empty_appends_retain_live_fork_geometry_and_cached_replay() {
	source := append_capacity_test_run(4, .ltr)
	mut merged := source.fork_for_layout()
	mut fragment := LineBoxFragment{direction_: .ltr, current_insert_direction: .ltr,
		inline_length_: CSSPixels.new(4), glyph_run_: merged}
	empty := append_capacity_test_run(0, .ltr)
	for _ in 0 .. 3 { fragment.append_glyph_run(empty, CSSPixels.new(0)) }
	gc_collect()
	merged.refresh_replay_data()
	assert merged.glyphs_.len == 4 && fragment.inline_length().to_double() == 4
	assert merged.glyph_indices() == source.glyph_indices()
	assert merged.glyph_positions() == source.glyph_positions()
}

fn test_glyph_vector_self_append_keeps_existing_ltr_and_rtl_positions() {
	for direction in [css.Direction.ltr, .rtl] {
		mut run := append_capacity_test_run(6, if direction == .ltr { .ltr } else { .rtl })
		mut fragment := LineBoxFragment{direction_: direction, current_insert_direction: direction,
			inline_length_: CSSPixels.new(6), glyph_run_: run}
		fragment.append_glyph_run(run, CSSPixels.new(6))
		gc_collect()
		run.refresh_replay_data()
		assert run.glyphs_.len == 12
		assert fragment.inline_length().to_double() == 12
		for i in 0 .. 6 {
			assert run.glyphs_[i].position.x == f32(if direction == .ltr { i } else { i + 6 })
			assert run.glyphs_[i + 6].position.x == f32(i + 6)
		}
		assert run.glyph_indices().len == 12
		assert run.glyph_positions().len == 24
	}
}
