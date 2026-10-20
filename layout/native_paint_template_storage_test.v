module layout

import dom
import html
import platform

fn test_native_paint_templates_belong_to_their_document_and_retained_scene() {
	$if !prealloc { return }
	url := dom.URL{value:'https://paint-template.example/'}
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.enable_native_storage()
	owner := document.native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>
p{width:150px}section{display:flow-root;width:180px}strong{border:1px solid blue}
</style><p>Retained template <strong>decorated words</strong> follow.</p>
<section><div>Independent text <span style="display:inline-block">atomic text</span></div></section>')
	allocations.finish()
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 320, 240)
	result := document_layout_result(document) or { panic('missing layout') }
	mut inline_templates := 0
	for _, cache in result.state.inline_layouts_ {
		if cache.paint_ready_ && cache.paint_lines_.len > 0 {
			assert owner.arena.contains(cache.paint_lines_.data)
			for line in cache.paint_lines_ {
				if line.fragments.len > 0 { assert owner.arena.contains(line.fragments.data) }
			}
			inline_templates++
		}
	}
	assert inline_templates > 0
	mut block_templates := 0
	for _, cache in result.state.block_layouts_ {
		for _, snapshot in cache.paint_lines_ {
			assert owner.arena.contains(voidptr(snapshot))
			assert owner.arena.contains(snapshot.lines.data)
			block_templates++
		}
		for _, snapshot in cache.paint_boxes_ { assert owner.arena.contains(voidptr(snapshot)) }
	}
	assert block_templates > 0
	display := document.record_viewport_display_list() or { panic('missing recording') }
	scene := retain_display_list_scene(display)
	assert scene != unsafe { nil }
	commands := display_list_commands(display)
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
