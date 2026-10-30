module layout

import dom
import html

fn flexible_contribution_grid_data(document &dom.Document, id string) dom.LayoutGridData {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	node := element.as_node().layout_node() or { panic('missing ${id} layout') }
	return node.used_grid_data()
}

fn test_flexible_grid_phases_measure_nested_breakable_content_and_live_changes() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>
			html,body{margin:0}.outer{display:grid;width:50px}
			.item{display:grid;min-width:0;grid-template-columns:1fr}
			span{display:inline-block;width:60px;height:10px}
			#minimum{grid-template-columns:minmax(min-content,1fr)}
			#maximum{grid-template-columns:minmax(max-content,1fr)}
			#spanning{grid-template-columns:minmax(max-content,1fr) minmax(max-content,2fr)}
			#spanning>.item{grid-column:span 2}
		</style>
		<div class="outer" id="minimum"><div class="item"><div><span></span><wbr><span></span></div></div></div>
		<div class="outer" id="maximum"><div class="item"><div><span></span><wbr><span></span></div></div></div>
		<div class="outer" id="spanning"><div class="item"><div><span></span><wbr><span></span></div></div></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert flexible_contribution_grid_data(document, 'minimum').columns == [60.0]
		assert flexible_contribution_grid_data(document, 'maximum').columns == [120.0]
		assert flexible_contribution_grid_data(document, 'spanning').columns == [40.0, 80.0]
		mut minimum := document.get_element_by_id('minimum') or { panic('missing minimum') }
		minimum.set_attribute_value('style', 'width:150px')
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert flexible_contribution_grid_data(document, 'minimum').columns == [150.0]
		minimum.set_attribute_value('style', 'width:50px;grid-template-columns:minmax(max-content,1fr)')
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert flexible_contribution_grid_data(document, 'minimum').columns == [120.0]
	}
}

fn test_flexible_grid_row_contributions_keep_intrinsic_limits_and_scroll_minimums() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>
			html,body{margin:0}.grid{display:grid;width:100px;align-content:start}
			.item{display:grid;min-height:0}.content{height:100px}
			#limited{height:min-content;max-height:50px;grid-template-rows:minmax(0px,1fr)}
			#maximum{height:max-content;grid-template-rows:minmax(max-content,1fr)}
			#scroll{height:max-content;grid-template-rows:minmax(auto,0fr)}
			#scroll>.item{overflow:auto}
		</style>
		<div class="grid" id="limited"><div class="item"><div class="content"></div></div></div>
		<div class="grid" id="maximum"><div class="item"><div class="content"></div></div></div>
		<div class="grid" id="scroll"><div class="item"><div class="content"></div></div></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert flexible_contribution_grid_data(document, 'limited').rows == [100.0]
		assert flexible_contribution_grid_data(document, 'maximum').rows == [100.0]
		assert flexible_contribution_grid_data(document, 'scroll').rows == [0.0]
	}
}
