module layout

import html

fn float_avoiding_find(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := float_avoiding_find(child, id) {
			return found
		}
	}
	return none
}

fn float_avoiding_border_box(result DocumentLayoutResult, id string, wrapper bool) []f64 {
	mut node := float_avoiding_find(result.root, id) or { panic('missing #${id}') }
	if wrapper {
		node = node.parent() or { panic('#${id} has no table wrapper') }
	}
	styled := node.as_node_with_style() or { panic('#${id} has no style') }
	used := result.used_values_for(styled) or { panic('#${id} has no used values') }
	return [used.offset.x().minus(used.border_box_left()).to_double(),
		used.border_box_width().to_double()]
}

// 4chan's blotter: a centered fixed-width table keeps its width once earlier
// floats are cleared, instead of filling the line as an auto-width block.
fn test_tables_and_replaced_boxes_keep_their_width_beside_floats() {
	mut document := html.parse_document('<!doctype html><style>body { margin:0 }
		table { border-spacing:0 } td { padding:0 }
		.right { float:right; width:100px; height:20px }</style>
		<div class="right"></div><div style="clear:both;height:10px"></div>
		<table id="cleared" style="width:468px;margin:auto"><tr><td>blotter</td></tr></table>
		<div style="float:left;width:50px;height:30px"></div>
		<table id="beside" style="width:300px;margin:auto"><tr><td>beside</td></tr></table>
		<img id="image" style="display:block;width:200px;height:10px;margin-left:auto">
		<div style="clear:both"></div>
		<table id="wide" style="width:1000px;margin:auto"><tr><td>wide</td></tr></table>')
	result := run_document_layout(document, 1024, 600) or { panic('layout failed') }
	assert float_avoiding_border_box(result, 'cleared', true) == [278.0, 468.0]
	// Auto margins center the box in the space beside the float.
	assert float_avoiding_border_box(result, 'beside', true) == [387.0, 300.0]
	assert float_avoiding_border_box(result, 'image', false) == [824.0, 200.0]
	assert float_avoiding_border_box(result, 'wide', true) == [12.0, 1000.0]
}

// 4chan's replies: an auto-width table beside the floated `>>` arrows shrinks
// to the remaining space instead of dropping below the float.
fn test_auto_width_tables_shrink_beside_floats() {
	mut document := html.parse_document('<!doctype html><style>body { margin:0; font:16px Arial }
		table { border-spacing:0 } td { padding:0 }</style>
		<div style="width:300px"><div style="float:left;width:50px;height:30px"></div>
		<table id="reply"><tr><td>a reply long enough to need every pixel beside the arrows</td></tr></table></div>')
	result := run_document_layout(document, 1024, 600) or { panic('layout failed') }
	assert float_avoiding_border_box(result, 'reply', true) == [50.0, 250.0]
	mut node := float_avoiding_find(result.root, 'reply') or { panic('missing #reply') }
	node = node.parent() or { panic('#reply has no table wrapper') }
	styled := node.as_node_with_style() or { panic('wrapper has no style') }
	used := result.used_values_for(styled) or { panic('wrapper has no used values') }
	assert used.offset.y().to_double() == 0
}

// Normal flow stretches a fitting table's end margin across the line. Beside a
// float, the table's size starts again from its specified margins.
fn test_fitting_auto_width_table_keeps_its_max_content_width_beside_floats() {
	mut document := html.parse_document('<!doctype html><style>body { margin:0; font:16px Arial }
		table { border-spacing:0; margin:4px 0 } td { padding:0 }</style>
		<div style="width:600px"><div style="float:left;width:200px;height:30px"></div>
		<table id="short"><tr><td><div style="display:inline-block;width:150px;height:10px"></div>
		<div style="display:inline-block;width:150px;height:10px"></div></td></tr></table></div>')
	result := run_document_layout(document, 1024, 600) or { panic('layout failed') }
	box := float_avoiding_border_box(result, 'short', true)
	// Both inline blocks and the space between them stay on one line.
	assert box[0] == 200 && box[1] > 300 && box[1] < 310
}
