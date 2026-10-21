module layout

import html

fn test_isolated_svg_paint_trees_recycle_across_sizes_after_scene_readers_retire() {
	$if !prealloc { return }
	mut document := html.parse_document('<!doctype html><svg width="60" height="40"><path d="M0 0L60 0L30 40Z" fill="green"/></svg>')
	defer { document.finalize() }
	enable_native_paint_tree_storage(document)
	_ = run_document_layout(document, 60, 40) or { panic('missing SVG layout') }
	old_list := document.record_display_list() or { panic('missing SVG paint') }
	reader := retain_display_list_scene(old_list)
	old_dump := old_list.dump()
	old_result := document_layout_result(document) or { panic('missing result') }
	old_storage := old_result.paint_tree_storage
	assert old_storage != unsafe { nil }
	for size in 61 .. 81 {
		_ = run_document_layout(document, size, 40) or { panic('missing resized SVG') }
		list := document.record_display_list() or { panic('missing resized paint') }
		assert display_list_commands(list).any(it.kind == 'draw_svg_path')
		assert old_list.dump() == old_dump
		assert old_storage.arena.reset_count() == 0
	}
	release_display_list_scene(reader)
	assert old_storage.arena.reset_count() == 1
	current := document_layout_result(document) or { panic('missing result') }
	assert current.paint_tree_pool.live.len == 1
	assert current.paint_tree_pool.free.len <= paint_tree_storage_spares
}
