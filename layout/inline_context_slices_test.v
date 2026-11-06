module layout

import css
import dom
import html
import math
import platform

fn context_slice_test_text(document &dom.Document) &TextNode {
	element := document.get_element_by_id('text') or { panic('element') }
	child := element.as_node().first_child() or { panic('text child') }
	bridge := child.layout_node() or { panic('text layout bridge') }
	return unsafe { &Node(bridge.real_layout_handle()) }.as_text_node() or { panic('text layout') }
}

fn context_slice_test_equal(a platform.ShapedText, b platform.ShapedText) {
	assert a.trailing_whitespace == b.trailing_whitespace
	assert a.glyph_run.glyphs() == b.glyph_run.glyphs()
	assert math.f32_bits(a.glyph_run.width()) == math.f32_bits(b.glyph_run.width())
	assert math.f32_bits(a.glyph_run.space_width) == math.f32_bits(b.glyph_run.space_width)
	assert voidptr(a.glyph_run.font()) == voidptr(b.glyph_run.font())
	assert a.glyph_run.text_type() == b.glyph_run.text_type()
	assert a.glyph_run.face() == b.glyph_run.face()
}

fn context_slice_test_compare(iterator &InlineLevelIterator, text &TextNode,
	chunks []TextNodeChunk, cache &InlineContextSlices) {
	run := iterator.chromium_single_script_context_run(text, chunks)
	segments := if run == none { iterator.chromium_segmented_context_runs(text, chunks) }
		else { []ChromiumTextContextRun{} }
	mut cursor := ChromiumContextSliceCursor{}
	for index, chunk in chunks {
		expected := if source := run { chromium_context_slice_with_cursor(source, chunk, mut cursor) }
			else { chromium_segmented_context_slice_with_cursor(segments, chunk, mut cursor) }
		actual := cache.fork_slice(index)
		if oracle := expected {
			context_slice_test_equal(actual or { panic('cached context missing') }, oracle)
		} else { assert actual == none }
	}
}

fn test_retained_context_slices_match_uncached_kerning_unicode_and_cluster_fallbacks() {
	for value in ['N. America To Wa Y  words', 'Т-то Т-то final ', '😀Т-то Т-то',
		'A  B   C', 'one\ntwo\tthree', 'á b-c d', 'مرحبا بالعالم'] {
		mut document := html.parse_document('<!doctype html><p id="text" style="font:16px Arial;white-space:pre-wrap;letter-spacing:.25px;word-spacing:1.25px">${value}</p>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 320, 160)
		text := context_slice_test_text(document)
		chunks := text.cached_inline_chunks_ or { panic('chunks') }
		iterator := InlineLevelIterator{is_unidirectional_left_to_right:true,layout_mode:.intrinsic_sizing}
		cache := iterator.retained_inline_context_slices(text, chunks)
		if disable_inline_context_slice_reuse { assert cache == none; continue }
		prepared := cache or { panic('eligible context not retained') }
		context_slice_test_compare(&iterator, text, chunks, prepared)
		assert voidptr(iterator.retained_inline_context_slices(text, chunks)?) == voidptr(prepared)
	}
}

fn test_cached_context_slice_forks_detach_before_glyph_and_replay_mutations() {
	if disable_inline_context_slice_reuse { return }
	mut document := html.parse_document('<!doctype html><p id="text" style="font:16px Arial">N. America To Wa Y words</p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 160)
	text := context_slice_test_text(document)
	chunks := text.cached_inline_chunks_?
	iterator := InlineLevelIterator{is_unidirectional_left_to_right:true,layout_mode:.intrinsic_sizing}
	cache := iterator.retained_inline_context_slices(text, chunks)?
	for index, entry in cache.slices {
		source := entry.shape or { continue }
		mut first := cache.fork_slice(index)?.glyph_run
		second := cache.fork_slice(index)?.glyph_run
		assert first.glyphs_.data == source.glyph_run.glyphs_.data
		first.invalidate_replay_data()
		first.glyphs_[0].position.x += 17
		first.glyphs_ << platform.Glyph{code_point:u32(`x`), advance:9}
		first.refresh_replay_data()
		assert first.glyphs_.data != source.glyph_run.glyphs_.data
		assert second.glyphs() == source.glyph_run.glyphs()
		assert second.glyph_indices() == source.glyph_run.glyph_indices()
		assert second.glyph_positions() == source.glyph_run.glyph_positions()
	}
	context_slice_test_compare(&iterator, text, chunks, cache)
}

fn test_context_slice_cache_keys_include_paragraph_direction_and_live_font_generation() {
	if disable_inline_context_slice_reuse { return }
	mut document := html.parse_document('<!doctype html><p id="text" style="font:16px Arial;unicode-bidi:normal">Words with soft boundaries</p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 160)
	text := context_slice_test_text(document)
	chunks := text.cached_inline_chunks_?
	first_iterator := InlineLevelIterator{is_unidirectional_left_to_right:true}
	first := first_iterator.retained_inline_context_slices(text, chunks)?
	second_iterator := InlineLevelIterator{is_unidirectional_left_to_right:false}
	second := second_iterator.retained_inline_context_slices(text, chunks)?
	assert voidptr(first) != voidptr(second)
	context_slice_test_compare(&second_iterator, text, chunks, second)
	mut fonts := unsafe { &css.FontComputer(css.css_style_computer_for(document).font_computer()) }
	fonts.did_load_font('UnrelatedContextSliceFace')
	third := second_iterator.retained_inline_context_slices(text, chunks)?
	assert voidptr(third) != voidptr(second)
	context_slice_test_compare(&second_iterator, text, chunks, third)
}

fn test_context_slices_follow_live_text_spacing_font_and_width_changes_like_a_full_rebuild() {
	mut document := html.parse_document('<!doctype html><p id="text" style="font:16px Arial;width:170px">N. America To Wa Y words and trailing space </p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 160)
	mut element := document.get_element_by_id('text')?
	for declarations in ['font:16px Arial;width:93px',
		'font:16px Arial;letter-spacing:-.5px;word-spacing:2px;width:170px',
		'font:21px Times New Roman;width:121px',
		'font:16px Arial;direction:rtl;unicode-bidi:normal;width:110px'] {
		element.set_attribute_value('style', declarations)
		document.update_layout(.debugging)
		current := document.record_display_list()?.dump()
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		assert document.record_display_list()?.dump() == current
	}
	element.as_node().set_text_content('Changed words 😀 Т-то Т-то')!
	document.update_layout(.debugging)
	current := document.record_display_list()?.dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert document.record_display_list()?.dump() == current
}

fn test_context_slice_cache_limits_keep_large_or_non_chromium_text_on_the_original_path() {
	for value in ['x', 'word '.repeat(130), 'x'.repeat(4100) + ' y'] {
		mut document := html.parse_document('<!doctype html><p id="text" style="font:16px Arial">${value}</p>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 320, 160)
		text := context_slice_test_text(document)
		chunks := text.cached_inline_chunks_?
		iterator := InlineLevelIterator{is_unidirectional_left_to_right:true}
		assert iterator.retained_inline_context_slices(text, chunks) == none
	}
}

fn test_native_context_slices_outlive_producing_scratch_and_retire_with_the_document() {
	if disable_inline_context_slice_reuse { return }
	url := dom.URL{value:'https://context-slices.example/'}
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.enable_native_storage()
	owner := document.native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><p id="text" style="font:16px Arial">N. America To Wa Y words</p>')
	allocations.finish()
	document.set_font_rendering_policy(.chromium)
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 320, 160)
	mut text := context_slice_test_text(document)
	chunks := text.cached_inline_chunks_?
	text.cached_inline_context_slices_ = none
	allocations = document.enter_native_storage()
	mut scratch := platform.new_arena('context slice producer')
	entry := scratch.enter()
	iterator := InlineLevelIterator{is_unidirectional_left_to_right:true}
	cache := iterator.retained_inline_context_slices(text, chunks)?
	scratch.leave(entry)
	scratch.release()
	allocations.finish()
	$if prealloc {
		assert owner.arena.contains(cache)
		assert owner.arena.contains(cache.slices.data)
		for slice in cache.slices {
			if shape := slice.shape { assert owner.arena.contains(shape.glyph_run.glyphs_.data) }
		}
	}
	gc_collect()
	context_slice_test_compare(&iterator, text, chunks, cache)
	handle := document.layout_engine_handle()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	retire_native_document_layout(handle)
	document.release_native_storage()
	$if prealloc {
		// Native font work can finish through a queued callback holding the
		// document's last activity lease. Require its actual release too.
		for _ in 0 .. 100 {
			if owner.arena.usage().capacity == 0 { break }
			platform.pump_native_events(0.01)
		}
		assert owner.arena.usage().capacity == 0
	}
}

fn test_context_slices_for_a_foreign_document_do_not_borrow_the_entered_owner() {
	if disable_inline_context_slice_reuse { return }
	mut foreign := html.parse_document('<!doctype html><p id="text" style="font:16px Arial">Foreign words keep their own storage</p>')
	defer { foreign.finalize() }
	foreign.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(foreign, 320, 160)
	mut text := context_slice_test_text(foreign)
	chunks := text.cached_inline_chunks_?
	text.cached_inline_context_slices_ = none
	mut other := dom.Document.create(dom.url_about_blank())
	other.enable_native_storage()
	owner := other.native_storage()
	mut allocations := other.enter_native_storage()
	mut scratch := platform.new_arena('foreign context scratch')
	entry := scratch.enter()
	iterator := InlineLevelIterator{is_unidirectional_left_to_right:true}
	cache := iterator.retained_inline_context_slices(text, chunks)?
	scratch.leave(entry)
	scratch.release()
	allocations.finish()
	$if prealloc {
		assert !owner.arena.contains(cache)
		assert !owner.arena.contains(cache.slices.data)
		for slice in cache.slices {
			if shape := slice.shape { assert !owner.arena.contains(shape.glyph_run.glyphs_.data) }
		}
	}
	other.finalize()
	other.release_native_storage()
	context_slice_test_compare(&iterator, text, chunks, cache)
}
