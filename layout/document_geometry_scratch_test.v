module layout

import css
import dom
import html

fn test_geometry_workspaces_retire_while_used_values_remain_document_owned() {
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	owner := document.native_storage()
	mut allocations := document.enter_native_storage()
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	state.measurement_chunk_pool_.scratch_enabled_ = true
	before := owner.arena.usage().used
	mut work := begin_document_geometry_scratch(document)
	temporary := []u8{len: 20 * 1024 * 1024, init: 17}
	mut values := state.get_mutable(node)
	values.set_content_width(CSSPixels.new(42))
	values.set_grid_template_columns([CSSPixels.new(21)])
	values.set_grid_line_names([['column ${17}']], [['row ${19}']])
	state.set_subgrid_axis_data(node, true, GridSubgridAxisData{
		tracks:     [GridTrack{ base_size: CSSPixels.new(11) }]
		line_names: [[css.GridLineName{ name: 'subgrid ${23}' }]]
	})
	mut probe := state.new_measurement_for_subtree(node)
	probe.get_mutable(node).set_content_width(CSSPixels.new(23))
	probe_temporary := []u8{len: 20 * 1024 * 1024, init: 19}
	assert temporary[temporary.len - 1] == 17
	assert probe_temporary[probe_temporary.len - 1] == 19
	probe.release_measurement()
	work.finish()
	assert values.content_width().to_double() == 42
	assert values.grid_template_columns()[0].to_double() == 21
	assert values.grid_column_line_names()[0][0] == 'column 17'
	assert values.grid_row_line_names()[0][0] == 'row 19'
	subgrid := state.subgrid_axis_data(node, true) or { panic('missing subgrid axis') }
	assert subgrid.tracks[0].base_size.to_double() == 11
	assert subgrid.line_names[0][0].name == 'subgrid 23'
	assert owner.arena.contains(values)
	assert owner.arena.contains(values.grid_template_columns().data)
	assert owner.arena.usage().used - before < 1024 * 1024
	state.release_measurement_chunk_pool()
	allocations.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_native_geometry_survives_retired_workspaces_for_text_grid_tables_and_svg() {
	url := dom.URL{ value: 'https://geometry-scratch.example/' }
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>
main{display:flex;flex-wrap:wrap;width:100%}article{flex:1;min-width:120px}
section{display:grid;grid-template-columns:1fr 2fr;gap:3px}p{max-width:100px}
table{border-collapse:collapse}td{border:3px solid;padding:2px}
</style><main><article><p>Retained wrapped geometry text with several words.</p>
<button>Retained button</button><input placeholder="Retained placeholder"></article>
<article><section><div>First grid cell</div><div>Second grid cell</div></section>
<table><caption>Retained caption</caption><tr><td>First</td><td>Second</td></tr></table>
<svg width="100" height="70" viewBox="0 0 100 70"><path d="M5 5L95 5L50 65Z" fill="green"/>
<foreignObject x="10" y="10" width="60" height="30"><div>SVG content</div></foreignObject></svg>
</article></main>')
	allocations.finish()
	enable_native_paint_tree_storage(document)
	for width in [320, 360, 280, 320] {
		root := layout_document_typed_in_viewport(document, width, 240)
		assert root.paint_commands().any(it.kind == 'draw_svg_path')
		display := document.record_viewport_display_list() or { panic('missing recording') }
		commands := display_list_commands(display)
		assert commands.any(it.text.contains('Retained'))
	}
	handle := document.layout_engine_handle()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	retire_native_document_layout(handle)
	document.release_native_storage()
}
