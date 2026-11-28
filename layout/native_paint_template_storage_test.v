module layout

import dom
import html
import platform

fn test_native_scripted_paint_projection_is_owned_by_its_retained_scene() {
	$if !prealloc { return }
	url := dom.URL{value:'https://paint-template.example/'}
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.enable_native_storage()
	owner := document.native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>
p{width:150px}section{display:flow-root;width:180px}strong{border:1px solid blue}
</style><p id="text">Retained text <strong>decorated words</strong> follow.</p>
<section><div>Independent text <span style="display:inline-block">atomic text</span></div></section>')
	allocations.finish()
	enable_native_paint_tree_storage(document)
	assert document.as_node().is_scripting_enabled()
	_ = layout_document_typed_in_viewport(document, 320, 240)
	result := document_layout_result(document) or { panic('missing layout') }
	assert result.state.block_paint_owners_.len == 0
	for _, cache in result.state.inline_layouts_ {
		assert !cache.paint_ready_
		assert cache.paint_lines_.len == 0
	}
	for _, cache in result.state.block_layouts_ {
		assert cache.paint_lines_.len == 0
		assert cache.paint_boxes_.len == 0
	}
	result.root.for_each_in_inclusive_subtree(fn (node &Node) dom.TraversalDecision {
		assert node.ordinary_paint_box_ == unsafe { nil }
		return .@continue
	})
	mut projection := platform.new_arena('scripted projection test')
	mut frame := document.enter_native_storage()
	before := owner.arena.usage().used
	base_before := platform.thread_arena_usage().used
	root := result.root.first_child() or { panic('missing root') }
	for _ in 0 .. 8 {
		entry := projection.enter()
		box := build_typed_paint_tree_in_arena(root, result.state, [6]f64{})
		assert box.paint_commands().any(it.text.contains('Retained'))
		projection.leave(entry)
		projection.reset()
	}
	assert owner.arena.usage().used - before < 4096
	assert platform.thread_arena_usage().used - base_before < 4096
	frame.finish()
	projection.release()
	display := document.record_viewport_display_list() or { panic('missing recording') }
	scene := retain_display_list_scene(display)
	assert scene != unsafe { nil }
	commands := display_list_commands(display)
	mut text := document.get_element_by_id('text') or { panic('missing paragraph') }
	text.set_inner_html('Updated <strong>inline paint</strong>.')!
	document.update_layout(.debugging)
	updated := document.record_viewport_display_list() or { panic('missing updated recording') }
	assert display_list_commands(updated).any(it.text.contains('Updated'))
	assert commands.any(it.text.contains('Retained'))
	handle := document.layout_engine_handle()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	retire_native_document_layout(handle)
	document.release_native_storage()
	assert commands.any(it.text.contains('Retained'))
	release_display_list_scene(scene)
	// Parser/event-loop deliveries can still own a final document lease.
	for _ in 0 .. 100 {
		if owner.arena.usage().capacity == 0 { break }
		platform.pump_native_events(0.01)
	}
	assert owner.arena.usage().capacity == 0
}
