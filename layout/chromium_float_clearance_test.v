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
