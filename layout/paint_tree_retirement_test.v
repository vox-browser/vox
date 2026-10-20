module layout

import html

fn test_native_paint_tree_waits_for_geometry_and_scene_readers() {
	$if !prealloc {
		return
	}
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:120px;height:20px;background:red}</style><div id="target">before</div>')
	defer { document.finalize() }
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut previous := document_layout_result(document) or { panic('missing layout') }
	old_root := previous.paint_tree
	old_storage := previous.paint_tree_storage
	assert old_storage != unsafe { nil }
	geometry := retain_document_paint_tree(document)
	list := document.record_display_list() or { panic('missing paint') }
	scene := retain_display_list_scene(list)
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	identity := i64(target.as_node().unique_id())
	target.set_attribute_value('style', 'width:200px')
	document.update_layout(.debugging)
	mut current := document_layout_result(document) or { panic('missing replacement') }
	assert current.paint_tree.find_box(identity)?.width == 200
	assert old_root.find_box(identity)?.width == 120
	assert old_storage.arena.reset_count() == 0
	assert old_storage.references == 2
	release_paint_tree(geometry)
	assert old_storage.references == 1
	assert old_root.find_box(identity)?.width == 120
	// Both layout and paint-only replacements must leave the retained scene's
	// backing tree untouched, even when the shell has released its geometry.
	for _ in 0 .. 12 {
		refresh_document_paint_tree(document, mut current, 320, 200)
		viewport_build_stacking_context_tree(voidptr(current))
		_ = document.record_display_list() or { panic('missing replacement paint') }
		assert old_root.find_box(identity)?.width == 120
		assert old_storage.arena.reset_count() == 0
	}
	release_display_list_scene(scene)
	assert old_storage.arena.reset_count() == 1
	assert current.paint_tree_pool.live.len == 1
	assert current.paint_tree_pool.free.len <= paint_tree_storage_spares
}

fn test_native_paint_tree_slot_arenas_stay_bounded_across_rebuilds() {
	$if !prealloc {
		return
	}
	mut document := html.parse_document('<!doctype html><main>' + '<section><p>Text with <b>bold</b> words</p><input placeholder="Search"></section>'.repeat(32) + '</main>')
	defer { document.finalize() }
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	for _ in 0 .. 32 {
		previous_storage := result.paint_tree_storage
		geometry := retain_document_paint_tree(document)
		refresh_document_paint_tree(document, mut result, 320, 200)
		viewport_build_stacking_context_tree(voidptr(result))
		assert result.hit_test_display_list_is_valid
		_ = document.record_viewport_display_list() or { panic('missing paint') }
		release_paint_tree(geometry)
		assert previous_storage.references == 0
		assert previous_storage.arena.usage().used == 0
		assert result.paint_tree_pool.live.len == 1
		assert result.paint_tree_pool.free.len <= paint_tree_storage_spares
		assert result.paint_tree.paint_commands().any(it.text.contains('Text with'))
	}
}
