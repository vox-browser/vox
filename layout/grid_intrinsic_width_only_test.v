module layout

import html

fn grid_width_probe_node(root &Node, id string) ?&Node {
	if owner := root.dom_node() {
		if element := owner.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := grid_width_probe_node(child, id) { return found }
	}
	return none
}

fn test_grid_width_measurement_matches_complete_grid_geometry() {
	for chromium in [false, true] {
		for tracks in ['auto', 'minmax(min-content,max-content) 1fr', '50px 1fr 2fr',
			'fit-content(80px) min-content', 'repeat(2, minmax(0,1fr))', '30% auto'] {
			for contents in [
				'<div style="grid-column:1/-1">Longer text with several words</div><div style="width:71px;height:33px">x</div>',
				'<div style="display:grid;grid-template-columns:auto auto"><div style="width:37px;height:93px"></div><div style="width:61px;height:22px"></div></div><div style="min-width:89px">text</div>',
				'<div style="display:grid;grid-template-columns:subgrid;grid-column:1/-1;padding:7px"><div style="width:63px;height:88px"></div><div>words</div></div>',
				'<img width="80" height="40"><div style="display:flex;flex-direction:column"><span>Text wraps here</span><span style="height:90px">more</span></div>',
			] {
				mut document := html.parse_document('<!doctype html><style>body{margin:0;font:16px/20px monospace}#grid{display:inline-grid;grid-template-columns:${tracks};gap:9px;padding:3px}#grid>*{border:1px solid}</style><div id="grid">${contents}<div style="position:absolute;width:20px;height:100px"></div></div>')
				defer { document.finalize() }
				if chromium { document.set_font_rendering_policy(.chromium) }
				result := run_document_layout(document, 800, 600) or { panic('layout failed') }
				grid := grid_width_probe_node(result.root, 'grid') or { panic('grid missing') }
				styled := grid.as_node_with_style() or { panic('style missing') }
				mut source := result.state
				for width in [AvailableSize.make_min_content(), AvailableSize.make_max_content()] {
					space := AvailableSpace.new(width, AvailableSize.make_indefinite())
					mut oracle_state := source.new_measurement_for_subtree(styled)
					populate_intrinsic_containing_block_chain(mut oracle_state, mut source, grid)
					populate_intrinsic_external_containing_blocks(mut oracle_state, mut source, grid, grid)
					mut oracle_values := oracle_state.get_mutable(styled)
					oracle_values.set_indefinite_content_width()
					oracle := run_grid_formatting_context(mut oracle_state, grid, mut oracle_values, .normal, space)
					oracle_state.release_measurement()
					mut state := source.new_measurement_for_subtree(styled)
					populate_intrinsic_containing_block_chain(mut state, mut source, grid)
					populate_intrinsic_external_containing_blocks(mut state, mut source, grid, grid)
					mut values := state.get_mutable(styled)
					values.set_indefinite_content_width()
					assert measure_grid_intrinsic_width(mut state, grid, mut values, space) == oracle.automatic_content_width
					state.release_measurement()
				}
				// Normal layout still publishes the complete descendant geometry.
				assert result.used_values_for(styled)?.content_height().to_double() > 0
			}
		}
	}
}

fn test_grid_width_measurement_keeps_size_containment_and_live_changes() {
	mut document := html.parse_document('<!doctype html><div id="grid" style="display:inline-grid;contain:size;contain-intrinsic-size:73px 41px"><div style="width:200px;height:99px"></div></div>')
	defer { document.finalize() }
	first := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid := grid_width_probe_node(first.root, 'grid') or { panic('grid missing') }
	box := grid.as_box() or { panic('box missing') }
	mut state := first.state
	assert calculate_min_content_width(mut state, box).to_double() == 73
	assert calculate_max_content_width(mut state, box).to_double() == 73
	mut element := document.get_element_by_id('grid')?
	element.set_attribute_value('style', 'display:inline-grid')
	document.update_layout(.debugging)
	second := run_document_layout(document, 800, 600) or { panic('second layout failed') }
	updated := grid_width_probe_node(second.root, 'grid') or { panic('grid missing') }
	mut current := second.state
	assert calculate_min_content_width(mut current, updated.as_box() or { panic('box missing') }).to_double() == 200
	assert calculate_max_content_width(mut current, updated.as_box() or { panic('box missing') }).to_double() == 200
}
