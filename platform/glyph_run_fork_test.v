module platform

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn test_layout_forks_detach_glyph_and_replay_storage_before_mutation() {
	font := &Font{family: 'serif', point_size: 16, weight: 400}
	source := GlyphRun.new(font, .ltr, [Glyph{code_point: u32(`a`), glyph_index: 1, advance: 8}])
	mut first := source.fork_for_layout()
	second := source.fork_for_layout()
	assert first.glyphs_.data == source.glyphs_.data
	assert first.glyph_indices().data == source.glyph_indices().data
	first.invalidate_replay_data()
	first.glyphs_[0].position.x = 12
	first.glyphs_ << Glyph{code_point: u32(`b`), glyph_index: 2, advance: 9}
	first.refresh_replay_data()
	assert source.glyphs_.len == 1
	assert source.glyphs_[0].position.x == 0
	assert second.glyphs_[0].position.x == 0
	assert source.glyph_indices() == [u16(1)]
	assert second.glyph_positions() == [f64(0), 0]
	assert first.glyph_indices() == [u16(1), 2]
	assert first.glyph_positions()[0] == 12
	assert first.glyphs_.data != source.glyphs_.data
	assert first.glyph_positions().data != source.glyph_positions().data
}

fn retained_layout_fork() &GlyphRun {
	font := &Font{family: 'serif', point_size: 16, weight: 400}
	run := GlyphRun.new(font, .ltr, [Glyph{code_point: u32(`a`), glyph_index: 1, advance: 8}])
	return run.fork_for_layout()
}

fn test_layout_fork_retains_shared_storage_after_its_cache_owner_is_gone() {
	run := retained_layout_fork()
	$if gcboehm ? { C.GC_gcollect() }
	assert run.glyphs_.len == 1
	assert run.glyphs_[0].advance == 8
	assert run.glyph_indices() == [u16(1)]
	assert run.glyph_positions() == [f64(0), 0]
}
