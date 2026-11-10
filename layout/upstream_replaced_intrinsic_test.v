// Copyright (c) 2026-present, the Ladybird developers.
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import html

fn upstream_replaced_intrinsic_values(result &DocumentLayoutResult, id string) &UsedValues {
	mut pending := [result.root]
	for pending.len > 0 {
		node := pending.pop()
		if dom_node := node.dom_node() {
			if element := dom_node.as_element() {
				if element.get_attribute_value('id') == id {
					styled := node.as_node_with_style() or { panic('missing style') }
					return result.used_values_for(styled) or { panic('missing geometry') }
				}
			}
		}
		for child in node.children() { pending << child }
	}
	panic('missing #${id}')
}

// Ladybird 2a888e0ee1e33f9cc7c44feae33e3fb9c225267b. Vox already
// measures wrapping columns in their widest item's max-content contribution.
fn test_wrapping_column_keeps_max_width_images_at_their_natural_size() {
	mut document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.row { display:flex }
		a { display:flex; flex-direction:column; align-items:center }
		.wrap { flex-wrap:wrap }
		img { max-width:100% }
	</style>
	<div class="row"><a class="wrap"><img id="wrap" src="data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'730\' height=\'90\'%3E%3C/svg%3E"></a></div>
	<div class="row"><a><img id="nowrap" src="data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'730\' height=\'90\'%3E%3C/svg%3E"></a></div>')
	defer { document.finalize() }
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	for id in ['wrap', 'nowrap'] {
		image := upstream_replaced_intrinsic_values(&result, id)
		assert image.content_width().to_double() == 730
		assert image.content_height().to_double() == 90
	}
}

// Ladybird 6e7edb068ee0ff3a31cd497f4028a4527e140e4c. The independently
// definite frame height must survive intrinsic image-width measurement.
fn test_flex_item_minimum_width_transfers_an_images_percentage_height() {
	mut document := html.parse_document('<!doctype html><style>
		body { margin:0 }
		.row { display:flex; width:600px }
		.item { flex:0 1 50% }
		.frame { display:flex; height:100px; overflow:hidden }
		img { height:100% }
	</style><div class="row">
		<div class="item"><div class="frame"><img id="image" src="data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'2000\' height=\'1000\'%3E%3C/svg%3E"></div></div>
		<div class="item" id="second">second item</div>
	</div>')
	defer { document.finalize() }
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	image := upstream_replaced_intrinsic_values(&result, 'image')
	assert image.content_width().to_double() == 200
	assert image.content_height().to_double() == 100
	assert upstream_replaced_intrinsic_values(&result, 'second').offset.x().to_double() == 300
}
