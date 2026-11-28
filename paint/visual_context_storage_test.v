module main

import html
import layout
import platform

fn test_native_visual_context_rebuild_reuses_storage_with_a_retained_recording() {
	$if !prealloc { return }
	mut document := html.parse_document('<!doctype html>
		<div style="width:100px;height:50px;overflow:auto">
			<p style="position:sticky;top:0;opacity:.5;transform:translateX(3px)">Sticky</p>
			<div style="height:200px"></div>
		</div>')
	document.enable_native_storage()
	defer {
		document.finalize()
		document.release_native_storage()
	}
	layout.enable_native_paint_tree_storage(document)
	_ = layout.layout_document_typed_in_viewport(document, 320, 240)
	result := layout.document_layout_result(document) or { panic('missing layout') }
	viewport := document.unsafe_paintable() or { panic('missing viewport') }
	old_list := document.record_display_list() or { panic('missing recording') }
	scene := layout.retain_display_list_scene(old_list)
	defer { layout.release_display_list_scene(scene) }
	assert old_list.command_count() > 0
	before_dump := old_list.dump()
	viewport.assign_accumulated_visual_contexts()
	contexts := result.visual_context_tree.nodes.data
	frames := result.scroll_state.frames.data
	assert result.visual_context_tree.nodes.len > 1
	assert result.scroll_state.frames.len > 2
	before := platform.thread_arena_usage().used
	for _ in 0 .. 64 {
		viewport.assign_accumulated_visual_contexts()
		assert result.visual_context_tree.nodes.data == contexts
		assert result.scroll_state.frames.data == frames
	}
	assert platform.thread_arena_usage().used == before
	assert old_list.dump() == before_dump
}
