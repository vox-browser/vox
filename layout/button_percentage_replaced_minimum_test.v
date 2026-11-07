module layout

import dom
import html

fn button_replaced_minimum_used(document &dom.Document, result DocumentLayoutResult, id string) UsedValues {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	bridge := element.as_node().layout_node() or { panic('missing ${id} layout') }
	node := unsafe { &Node(bridge.layout_handle) }
	styled := node.as_node_with_style() or { panic('${id} has no style') }
	used := result.used_values_for(styled) or { panic('${id} has no used values') }
	return *used
}

// Old Reddit's video controls: an 18px button flex item whose only content is
// an <svg> with width:auto and height:100%. Its percentage height resolves
// against the button's definite height through the anonymous button wrappers,
// so the transferred 18px width is the button's min-content contribution and
// the automatic minimum keeps the overflowing flex item at 18px.
fn test_button_flex_item_keeps_width_transferred_from_percentage_height_content() {
	mut document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.row { display:flex; width:100px }
		.fill { width:200px; height:10px }
		button { width:18px; height:18px; padding:0; border:0; margin:0 }
		svg { display:block; width:auto; height:100% }
	</style><div class="row"><button id="button"><svg id="svg" viewBox="0 0 40 40"><path d="M5 5h12v30H5z"/></svg></button><div class="fill" id="fill"></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 400, 300) or { panic('layout failed') }
	button := button_replaced_minimum_used(document, result, 'button')
	assert button.content_width().to_double() == 18
	assert button.content_height().to_double() == 18
	svg := button_replaced_minimum_used(document, result, 'svg')
	assert svg.content_width().to_double() == 18
	assert svg.content_height().to_double() == 18
	assert svg.offset.x().to_double() == 0 && svg.offset.y().to_double() == 0
	fill := button_replaced_minimum_used(document, result, 'fill')
	assert fill.content_width().to_double() == 82
}

// The fullscreen button's icon is an inline-level replaced box: the inline
// formatting context sizes it with its own (indefinite) available height
// during intrinsic measurement. Its percentage height still resolves against
// the button.
fn test_button_flex_item_keeps_width_transferred_from_inline_replaced_content() {
	mut document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.row { display:flex; width:100px }
		.fill { width:200px; height:10px }
		button { width:18px; height:18px; padding:0; border:0; margin:0 }
		svg { width:auto; height:100% }
	</style><div class="row"><button id="button"><svg id="svg" viewBox="0 0 20 20"><path d="M2 2h16v16H2z"/></svg></button><div class="fill" id="fill"></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 400, 300) or { panic('layout failed') }
	button := button_replaced_minimum_used(document, result, 'button')
	assert button.content_width().to_double() == 18
	svg := button_replaced_minimum_used(document, result, 'svg')
	assert svg.content_width().to_double() == 18
	assert svg.content_height().to_double() == 18
	fill := button_replaced_minimum_used(document, result, 'fill')
	assert fill.content_width().to_double() == 82
}
