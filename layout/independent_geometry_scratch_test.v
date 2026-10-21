module layout

import css
import dom
import html

fn test_nested_geometry_detaches_cached_line_headers_into_the_document() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	owner := document.native_storage()
	mut allocations := document.enter_native_storage()
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut state := LayoutState.new()
	mut values := state.get_mutable(node)
	lines := [LineBox.new(.ltr, .horizontal_tb)]
	values.borrow_retained_line_boxes(lines)
	mut work := begin_nested_geometry_scratch(document, .normal)
	_ = state.get_mutable(node)
	assert !values.line_boxes_are_shared_
	assert owner.arena.contains(values.line_boxes.data)
	assert values.line_boxes.data != lines.data
	work.finish()
	assert values.line_boxes.len == 1 && lines.len == 1
	allocations.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_atomic_inline_contexts_preserve_retained_scenes_after_nested_workspaces_retire() {
	url := dom.URL{value: 'https://independent-scratch.example/'}
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>
body{margin:0;font:16px/20px monospace}.atomic{display:inline-block;width:160px;vertical-align:top;position:relative}
.float{float:left;width:24px;height:24px;background:green}.abs{position:absolute;left:0;top:130px}
.grid{display:grid;grid-template-columns:1fr 2fr}table{border-collapse:collapse}td{border:1px solid}
.plain{display:inline-block;width:120px;overflow:hidden}
</style><div>Before <span class="atomic"><span class="float"></span>Floating text wraps beside the box.
<div class="grid"><b>Grid one</b><b>Grid two</b></div>
<table><tr><td>Cell one</td><td>Cell two</td></tr></table><b class="abs">Absolute</b>
<svg width="60" height="40" viewBox="0 0 60 40"><path d="M2 2L58 2L30 38Z" fill="green"/></svg>
</span> After <span class="plain">Cached ordinary inline block content.</span></div>')
	allocations.finish()
	enable_native_paint_tree_storage(document)
	mut first := unsafe { &dom.DisplayList(nil) }
	mut first_scene := unsafe { voidptr(nil) }
	for width in [360, 360, 280, 400, 400, 360] {
		root := layout_document_typed_in_viewport(document, width, 480)
		assert root.paint_commands().any(it.kind == 'draw_svg_path')
		display := document.record_viewport_display_list() or { panic('missing recording') }
		if first == unsafe { nil } {
			first = display
			first_scene = retain_display_list_scene(display)
		}
		commands := display_list_commands(display)
		for word in ['Floating', 'Grid', 'Cell', 'Absolute', 'After', 'Cached'] {
			assert commands.any(it.text.contains(word)), word
		}
	}
	assert display_list_commands(first).any(it.text.contains('Cached'))
	assert display_list_commands(first).any(it.kind == 'draw_svg_path')
	release_display_list_scene(first_scene)
	handle := document.layout_engine_handle()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	retire_native_document_layout(handle)
	document.release_native_storage()
}
