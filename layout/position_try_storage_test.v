module layout

import css
import dom
import html
import platform

fn test_position_try_retry_state_and_dom_styles_survive_a_temporary_geometry_query() {
	$if !prealloc {
		return
	}
	url := dom.URL{ value: 'https://position-try-storage.test/' }
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.enable_native_storage()
	defer {
		handle := document.layout_engine_handle()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		retire_native_document_layout(handle)
		document.release_native_storage()
	}
	mut owner := document.enter_native_storage()
	defer { owner.finish() }
	html.parse_html_from_a_string(document, '<!doctype html><style>body{margin:0}#container{position:relative;width:190px;height:100px}#target{position:absolute;left:150px;top:10px;width:50px;height:20px;position-try-fallbacks:--fallback}@position-try --fallback{left:50px;top:30px}</style><div id="container"><div id="target"></div></div>')
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 300, 200)
	mut result := document_layout_result(document) or { panic('Missing layout') }
	target := document.get_element_by_id('target') or { panic('Missing target') }
	bridge := target.as_node().layout_node() or { panic('Missing layout node') }
	node := unsafe { &Node(bridge.layout_handle) }
	mut box := node.as_box() or { panic('Missing target box') }
	box.position_try_state_ = none
	mut temporary := platform.new_arena('position try caller')
	entry := temporary.enter()
	assert layout_with_position_try_fallbacks(mut result.state, node)
	temporary.leave(entry)
	retained := box.position_try_state_ or { panic('Missing retry state') }
	mirror := dom.AbstractElement.new(target, none).computed_properties() or { panic('Missing DOM style') }
	computed := css.computed_properties_for_element(target) or { panic('Missing computed style') }
	assert !temporary.contains(retained) && !temporary.contains(mirror) && !temporary.contains(computed)
	assert !temporary.contains(retained.base_css) && !temporary.contains(retained.applied_layout)
	temporary.reset()
	assert position_try_property_text(retained.base_layout, .position_try_fallbacks) == '--fallback'
	assert (computed.property(.left, .yes) or { panic('Missing left') }).css_text == '50px'
	assert layout_with_position_try_fallbacks(mut result.state, node)
	assert target.get_bounding_client_rect().x == 50
}
