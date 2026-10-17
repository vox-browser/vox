module layout

import html

fn float_clearance_used(result DocumentLayoutResult, root &Node, id string) &UsedValues {
	node := float_clearance_find(root, id) or { panic('missing #${id}') }
	styled := node.as_node_with_style() or { panic('#${id} has no style') }
	return result.used_values_for(styled) or { panic('#${id} has no used values') }
}

fn float_clearance_find(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := float_clearance_find(child, id) {
			return found
		}
	}
	return none
}

// Wikipedia's footer: a cleared float stacks below an earlier float, while the
// inline content that follows both stays beside the first one, as in Brave.
fn test_cleared_float_does_not_move_following_inline_content() {
	markup := '<!doctype html><style>body { margin:0; font:14px system-ui }
		.f { float:left; clear:left; width:100px }</style>
		<div style="width:300px"><div class="f" style="height:20px;margin-bottom:5px"></div>
		<div class="f" style="height:40px"></div>
		<div id="inline" style="display:inline-block;width:150px;height:20px"></div></div>'
	mut chromium := html.parse_document(markup)
	chromium.set_font_rendering_policy(.chromium)
	blink := run_document_layout(chromium, 800, 600) or { panic('layout failed') }
	inline := float_clearance_used(blink, blink.root, 'inline')
	assert inline.offset.y().to_double() == 0
	assert inline.offset.x().to_double() == 100
	// LibWeb places the line at the cleared float.
	result := run_document_layout(html.parse_document(markup), 800, 600) or { panic('layout failed') }
	assert float_clearance_used(result, result.root, 'inline').offset.y().to_double() == 25
}

fn float_clearance_offsets(markup string, chromium bool) []f64 {
	mut document := html.parse_document('<!doctype html><style>body { margin:0 }
		.f { float:right; width:50px; height:40px }</style>
		<div style="height:10px"></div><div class="f"></div>' + markup)
	if chromium {
		document.set_font_rendering_policy(.chromium)
	}
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	if float_clearance_find(result.root, 'child') == none {
		return [float_clearance_used(result, result.root, 'cleared').offset.y().to_double()]
	}
	return [float_clearance_used(result, result.root, 'cleared').offset.y().to_double(),
		float_clearance_used(result, result.root, 'child').offset.y().to_double()]
}

// 4chan's board banner: the margin of a cleared block's first child collapses
// into the clearance below the float instead of lowering the block, as in Brave.
fn test_cleared_block_keeps_collapsed_child_margin_within_clearance() {
	nested := '<div id="cleared" style="clear:both"><div id="child" style="margin:5px auto;height:20px"></div></div>'
	assert float_clearance_offsets(nested, true) == [50.0, 0.0]
	assert float_clearance_offsets(nested, false) == [55.0, 0.0]
}

// CSS 2.1 §9.5.2: no clearance is introduced when the hypothetical position
// after collapsed margins is already past the float.
fn test_cleared_block_margins_past_the_float_introduce_no_clearance() {
	own := '<div id="cleared" style="clear:both;margin-top:60px;height:20px"></div>'
	assert float_clearance_offsets(own, true) == [70.0]
	assert float_clearance_offsets(own, false) == [50.0]
	child := '<div id="cleared" style="clear:both;margin-top:20px"><div id="child" style="margin-top:60px;height:20px"></div></div>'
	assert float_clearance_offsets(child, true) == [70.0, 0.0]
	small := '<div id="cleared" style="clear:both;margin-top:20px"><div id="child" style="margin-top:30px;height:20px"></div></div>'
	assert float_clearance_offsets(small, true) == [50.0, 0.0]
	negative := '<div id="cleared" style="clear:both;margin-top:-5px;height:20px"></div>'
	assert float_clearance_offsets(negative, true) == [50.0]
	// A negative margin does not create clearance once the floats are cleared.
	after := '<div style="clear:both;height:10px"></div><div id="cleared" style="clear:both;margin-top:-5px;height:20px"></div>'
	assert float_clearance_offsets(after, true) == [55.0]
}
