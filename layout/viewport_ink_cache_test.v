module layout

import dom
import html

fn assert_cached_viewport_ink_matches_replay(result &DocumentLayoutResult) {
	cache := &result.record_scratch.viewport_ink_cache
	assert cache.valid
	assert cache.entries.len == result.paint_order.len
	transforms := [
		[f64(1), 0, 0, 1, 0, 0]!,
		[f64(1), 0, 0, 1, 0, -701.25]!,
		[f64(2), 0, 0, 2, -15.5, -1400.75]!,
		[f64(1), .125, -.25, 1, 25, -700]!,
		[f64(1), 0, 0, 1, 0, -1_000_001]!,
	]
	mut probe := PaintCommand{}
	for index, entry in result.paint_order {
		for transform in transforms {
			before := viewport_entry_has_bounded_ink(entry.box)
				&& viewport_box_ink_is_outside(entry.box, transform, 320, 100, mut probe)
			after := viewport_cached_entry_ink_is_outside(cache, index, transform, 320, 100, mut probe)
			assert before == after, 'entry=${index}, transform=${transform}'
		}
	}
}

fn test_viewport_ink_cache_preserves_each_component_and_current_transform() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}p{height:130px}#changed{outline:3px solid red;outline-offset:-5px}#decorated{text-decoration:underline wavy;outline:1px solid green}#fixed{position:fixed;top:10px}#transformed{transform:translateY(-200px)}</style><p id="changed">first <span id="decorated">decorated text</span></p><p id="transformed">transformed</p><p id="fixed">fixed</p><p style="filter:blur(2px)">filtered</p><svg><rect width="20" height="20"/></svg><p>last</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	_ = document.record_viewport_display_list()?
	mut result := document_layout_result(document)?
	assert_cached_viewport_ink_matches_replay(result)
	entries := result.record_scratch.viewport_ink_cache.entries.data
	rects := result.record_scratch.viewport_ink_cache.rects.data
	revision := result.record_scratch.viewport_ink_cache.revision
	for y in [f64(1.25), 100.5, 200, 360.75, 0] {
		document.set_viewport_rect(dom.Rect{0, y, 320, 100})
		_ = document.record_viewport_display_list()?
		assert result.record_scratch.viewport_ink_cache.entries.data == entries
		assert result.record_scratch.viewport_ink_cache.rects.data == rects
		assert result.record_scratch.viewport_ink_cache.revision == revision
		assert_cached_viewport_ink_matches_replay(result)
	}
	// A paint-only update can change eligibility without changing layout size.
	mut changed := document.get_element_by_id('changed')?
	changed.set_attribute_value('style', 'box-shadow:0 0 25px red;outline:40px solid blue')
	document.update_layout(.debugging)
	_ = document.record_viewport_display_list()?
	result = document_layout_result(document)?
	assert result.record_scratch.viewport_ink_cache.revision != revision
	assert_cached_viewport_ink_matches_replay(result)
	viewport_invalidate_stacking_context(voidptr(result))
	assert !result.stacking_context_tree_is_valid
	document.set_needs_repaint()
	_ = document.record_viewport_display_list()?
	assert_cached_viewport_ink_matches_replay(result)
}

fn test_viewport_ink_workspace_moves_without_reusing_an_old_layouts_bounds() {
	mut document := html.parse_document('<!doctype html><p id="changed">short text</p>' + '<p>more content</p>'.repeat(12))
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	_ = document.record_viewport_display_list()?
	mut previous := document_layout_result(document)?
	assert previous.record_scratch.viewport_ink_cache.valid
	storage := previous.record_scratch.viewport_ink_cache.rects.data
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('changed text with a different width')!
	document.update_layout(.debugging)
	mut current := document_layout_result(document)?
	assert voidptr(current) != voidptr(previous)
	assert !current.record_scratch.viewport_ink_cache.valid
	assert current.record_scratch.viewport_ink_cache.rects.data == storage
	assert previous.record_scratch.viewport_ink_cache.rects.cap == 0
	_ = document.record_viewport_display_list()?
	assert_cached_viewport_ink_matches_replay(current)
}
