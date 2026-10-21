module layout

import dom
import html
import platform

fn test_native_static_projection_keeps_scene_payloads_without_duplicate_templates() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	document.set_scripting_enabled_by_embedder(false)
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>html,body{margin:0}p{color:green}</style>' + '<p>Retained <b>static</b> words</p>'.repeat(64))
	allocations.finish()
	enable_native_paint_tree_storage(document)
	_ = run_document_layout(document, 320, 240) or { panic('missing layout') }
	old := document.record_display_list() or { panic('missing paint') }
	reader := retain_display_list_scene(old)
	expected := old.dump()
	mut result := document_layout_result(document) or { panic('missing result') }
	mut projection := platform.new_arena('static projection test')
	mut projection_document_growth := i64(0)
	mut projection_base_growth := i64(0)
	for _ in 0 .. 20 {
		mut frame := document.enter_native_storage()
		before := document.native_storage().arena.usage().used
		base_before := platform.thread_arena_usage().used
		entry := projection.enter()
		root := result.root.first_child() or { panic('missing root') }
		box := build_typed_paint_tree_in_arena(root, result.state, [6]f64{})
		assert box.paint_commands().any(it.text == 'Retained ')
		projection.leave(entry)
		projection_document_growth += document.native_storage().arena.usage().used - before
		projection_base_growth += platform.thread_arena_usage().used - base_before
		projection.reset()
		refresh_document_paint_tree(document, mut result, 320, 240)
		viewport_build_stacking_context_tree(voidptr(result))
		current := document.record_display_list() or { panic('missing replacement paint') }
		mut verification := platform.begin_thread_scratch('static paint verification')
		assert current.dump() == expected
		assert old.dump() == expected
		assert result.state.block_paint_owners_.len == 0
		for _, cached in result.state.inline_layouts_ { assert !cached.paint_ready_ }
		verification.finish()
		frame.finish()
	}
	projection.release()
	// Projection payloads must stay in the recyclable projection arena. The
	// surrounding viewport bridge also rebuilds its own independent caches.
	assert projection_document_growth < 4096
	assert projection_base_growth < 4096
	result.root.for_each_in_inclusive_subtree(fn (node &Node) dom.TraversalDecision {
		assert node.ordinary_paint_box_ == unsafe { nil }
		return .@continue
	})
	assert display_list_commands(old).any(it.text == 'Retained ')
	release_display_list_scene(reader)
	retire_native_document_layout(document.layout_engine_handle())
	if navigable := document.navigable() {
		mut retiring := unsafe { &dom.Navigable(navigable) }
		retiring.remove_from_all_navigables()
	}
	document.finalize()
	document.release_native_storage()
}
