module layout

import html

fn test_fixed_height_button_content_can_shrink_below_its_inline_line_box() {
	mut document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.row { display:flex; align-items:center; height:48px }
		button { width:48px; height:32px; padding:0; border:0; font:16px/32px Arial }
		.icon { display:inline-flex; width:48px; height:32px; font-size:0 }
		.icon > span { display:inherit; width:100%; height:100%; align-items:center; justify-content:center }
		svg { width:24px; height:24px }
	</style><div class="row"><button id="search"><span class="icon" id="icon"><span><svg id="svg" viewBox="0 0 24 24"><rect width="24" height="24" fill="green"/></svg></span></span></button></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 1024, 768) or { panic('layout failed') }
	element := document.get_element_by_id('search') or { panic('missing button') }
	bridge := element.as_node().layout_node() or { panic('missing button layout') }
	button := unsafe { &Node(bridge.layout_handle) }
	wrapper := button.first_child() or { panic('missing flex wrapper') }
	content := wrapper.first_child() or { panic('missing content wrapper') }
	content_style := content.as_node_with_style()?
	content_used := result.used_values_for(content_style)?
	// The inline-flex icon and the button font's strut make a line taller
	// than 32px. The anonymous flex item's zero minimum lets it shrink to
	// the button instead of shifting the overflowing line upward to center it.
	assert content.computed_values().size_value(.min_height).is_auto() == false
	assert content_used.content_height().to_double() == 32
	assert content_used.offset.y().to_double() == 0
	for id, expected_y in {
		'icon': 0.0
		'svg':  4.0
	} {
		child_element := document.get_element_by_id(id)?
		child_bridge := child_element.as_node().layout_node()?
		child := unsafe { &Node(child_bridge.layout_handle) }
		child_style := child.as_node_with_style()?
		child_used := result.used_values_for(child_style)?
		assert child_used.offset.y().to_double() == expected_y
	}
}
