module layout

import css
import html

fn block_reuse_node(root &Node, id string) ?&Node {
	if owner := root.dom_node() {
		if element := owner.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := block_reuse_node(child, id) { return found }
	}
	return none
}

fn test_auto_grid_item_block_cache_matches_an_independent_intrinsic_probe() {
	for chromium in [false, true] {
		for contents in [
			'<div style="height:37px"></div>',
			'<div style="height:50%;padding:7px">text</div>',
			'<div style="display:grid;grid-template-columns:1fr 1fr;gap:9px"><div style="height:37px"></div><div style="height:61px"></div></div>',
			'<div style="display:flex;flex-direction:column;gap:5px"><div style="height:23px"></div><div style="height:41px"></div></div>',
		] {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;width:300px;align-items:start}#item{padding:7px;border:2px solid}</style><div id="grid"><div id="item">${contents}</div></div>')
			defer { document.finalize() }
			if chromium { document.set_font_rendering_policy(.chromium) }
			result := run_document_layout(document, 800, 600) or { panic('layout failed') }
			node := block_reuse_node(result.root, 'item') or { panic('item missing') }
			box := node.as_box() or { panic('item box missing') }
			values := result.used_values_for(node.as_node_with_style() or { panic('missing styled item') }) or { panic('geometry missing') }
			mut mutable_box := unsafe { &Box(box) }
			cached := mutable_box.cached_intrinsic_sizes().cached_content_height(false, values.content_width().raw_value()) or { panic('row sizing did not retain block height') }
			mut state := result.state
			oracle := calculate_content_height_with_constraint(mut state, box, values.content_width(), .max_content)
			// Final row layout can make an item's block size definite. The row
			// sizing cache is populated earlier, while that size is indefinite.
			assert cached == oracle
			assert calculate_min_content_height(mut state, box, values.content_width()) == oracle
			assert calculate_max_content_height(mut state, box, values.content_width()) == oracle
		}
	}
}

fn test_grid_block_reuse_excludes_constraints_and_tracks_live_content_changes() {
	for extra in ['height:40px', 'min-height:100px', 'max-height:20px', 'aspect-ratio:2', 'contain:size'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;width:300px;align-items:start}#item{${extra}}</style><div id="grid"><div id="item"><div style="height:61px"></div></div></div>')
		defer { document.finalize() }
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		node := block_reuse_node(result.root, 'item') or { panic('item missing') }
		values := result.used_values_for(node.as_node_with_style() or { panic('missing styled item') }) or { panic('geometry missing') }
		assert !seed_grid_auto_item_block_height(node, values, false)
	}
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;width:300px;align-items:start}</style><div id="grid"><div id="item"><div id="content" style="height:61px"></div></div></div>')
	defer { document.finalize() }
	first := run_document_layout(document, 800, 600) or { panic('first layout failed') }
	first_item := block_reuse_node(first.root, 'item') or { panic('item missing') }
	first_height := first.used_values_for(first_item.as_node_with_style() or { panic('missing styled item') })?.content_height().to_double()
	assert first_height == 61
	mut content := css.query_selector(document.as_node(), '#content')?
	content.set_attribute_value('style', 'height:93px')
	second := run_document_layout(document, 800, 600) or { panic('second layout failed') }
	second_item := block_reuse_node(second.root, 'item') or { panic('item missing') }
	assert second.used_values_for(second_item.as_node_with_style() or { panic('missing styled item') })?.content_height().to_double() == 93
	values := second.used_values_for(second_item.as_node_with_style() or { panic('missing styled item') })?
	assert !seed_grid_auto_item_block_height(second_item, values, true)
}
