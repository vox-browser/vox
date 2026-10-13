module layout

import html

fn flex_relayout_used(result DocumentLayoutResult, id string) &UsedValues {
	mut pending := [result.root]
	for pending.len > 0 {
		node := pending.pop()
		if dom_node := node.dom_node() {
			if element := dom_node.as_element() {
				if element.get_attribute_value('id') == id {
					return result.used_values_for(node.as_node_with_style() or { panic(id) }) or { panic(id) }
				}
			}
		}
		pending << node.children()
	}
	panic('missing #${id}')
}

fn test_deep_auto_height_flex_layout_reuses_unchanged_item_geometry() {
	// Repeating each child's natural, definite and stretched inside-layout at
	// every level makes this small tree require exponentially many passes.
	wrappers := '<div class="row">'.repeat(16)
	closing := '</div>'.repeat(16)
	document := html.parse_document('<!doctype html><style>
		body { margin:0 } .row { display:flex; width:100px }
		#leaf { width:100px; height:12px } #percentage { height:50% }
	</style><div class="row" id="outer">${wrappers}<div id="leaf"><div id="percentage"></div></div>${closing}</div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert flex_relayout_used(result, 'outer').content_height().to_double() == 12
	leaf := flex_relayout_used(result, 'leaf')
	assert leaf.content_width().to_double() == 100
	assert leaf.content_height().to_double() == 12
	assert flex_relayout_used(result, 'percentage').content_height().to_double() == 6
}

fn test_flex_relayout_keeps_percentage_height_dependencies_through_wrappers() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 } #outer { display:flex; width:100px }
		#item { width:100px } #spacer { height:40px }
		#percentage { height:50%; width:10px }
	</style><div id="outer"><div id="item"><div id="spacer"></div><div id="percentage"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert flex_relayout_used(result, 'item').content_height().to_double() == 40
	assert flex_relayout_used(result, 'percentage').content_height().to_double() == 20
}

fn test_flex_relayout_still_lays_out_items_when_stretch_changes_their_height() {
	document := html.parse_document('<!doctype html><style>
		body { margin:0 } #outer { display:flex; width:200px; height:80px }
		#item { display:flex; flex-direction:column; width:100px; justify-content:center }
		#leaf { height:20px; width:10px }
	</style><div id="outer"><div id="item"><div id="leaf"></div></div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	assert flex_relayout_used(result, 'item').content_height().to_double() == 80
	assert flex_relayout_used(result, 'leaf').offset.y().to_double() == 30
}

fn test_block_flex_resolves_its_automatic_height_in_its_own_layout() {
	for direction in ['row', 'column'] {
		document := html.parse_document('<!doctype html><style>
			body { margin:0 } .flex { display:flex; flex-direction:${direction}; width:100px }
			.block { display:block } #leaf { height:12px; width:100px }
			#outer { min-height:20px; align-items:center; justify-content:center }
		</style><div class="flex" id="outer"><div class="block"><div class="flex"><div class="block"><div class="flex" id="inner"><div id="leaf"></div></div></div></div></div></div>')
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		assert flex_relayout_used(result, 'outer').content_height().to_double() == 20
		assert flex_relayout_used(result, 'inner').content_height().to_double() == 12
		assert flex_relayout_used(result, 'leaf').content_height().to_double() == 12
	}
}
