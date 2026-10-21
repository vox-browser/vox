module layout

import css
import dom
import html

fn test_flex_work_inside_retained_inline_construction_retires_its_workspace() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	owner := document.native_storage()
	mut allocations := document.enter_native_storage()
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut state := LayoutState.new()
	mut outer := begin_document_geometry_scratch(document)
	mut inline_allocations := retain_geometry_allocations()
	before := owner.arena.usage().used
	mut flex := begin_flex_geometry_scratch(document, .normal)
	temporary := []u8{len: 20 * 1024 * 1024, init: 31}
	mut values := state.get_mutable(node)
	values.set_grid_template_columns([CSSPixels.new(37)])
	values.set_grid_line_names([['flex ${41}']], [['item ${43}']])
	assert temporary[temporary.len - 1] == 31
	flex.finish()
	// Both the published values and subsequent inline construction must use
	// the enclosing document, even after the nested workspace is poisoned.
	assert values.grid_template_columns()[0].to_double() == 37
	assert values.grid_column_line_names()[0][0] == 'flex 41'
	assert values.grid_row_line_names()[0][0] == 'item 43'
	inline_text := 'retained inline ${47}'.clone()
	assert owner.arena.contains(values)
	assert owner.arena.contains(values.grid_template_columns().data)
	assert owner.arena.contains(inline_text.str)
	assert owner.arena.usage().used - before < 1024 * 1024
	inline_allocations.finish()
	outer.finish()
	assert inline_text == 'retained inline 47'
	allocations.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_flex_does_not_shorten_an_existing_workspace_or_intrinsic_probe() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	state.measurement_chunk_pool_.scratch_enabled_ = true
	mut outer := begin_document_geometry_scratch(document)
	mut flex := begin_flex_geometry_scratch(document, .normal)
	assert flex.scratch == unsafe { nil }
	work := []u8{len: 1024, init: 53}
	flex.finish()
	assert work[work.len - 1] == 53
	mut probe := state.new_measurement_for_subtree(node)
	mut probe_flex := begin_flex_geometry_scratch(document, .normal)
	assert probe_flex.scratch == unsafe { nil }
	mut values := probe.get_mutable(node)
	values.set_grid_template_columns([CSSPixels.new(59)])
	probe_flex.finish()
	assert values.grid_template_columns()[0].to_double() == 59
	assert !document.native_storage().arena.contains(values)
	probe.release_measurement()
	outer.finish()
	mut intrinsic := begin_flex_geometry_scratch(document, .intrinsic_sizing)
	assert intrinsic.scratch == unsafe { nil }
	intrinsic.finish()
	state.release_measurement_chunk_pool()
	allocations.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_inline_flex_rows_columns_and_nested_grid_remain_paintable_after_reflow() {
	url := dom.URL{value: 'https://inline-flex-scratch.example/'}
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>
body{margin:0;font:16px/20px monospace}.row,.column{display:inline-flex;width:180px}
.row{flex-wrap:wrap;gap:3px}.column{flex-direction:column;height:100px}
.item{flex:1;min-width:70px}.column>.item{min-height:0}
.grid{display:grid;grid-template-columns:1fr 2fr}.grid>b{font-weight:normal}
</style><p>Before <span class="row"><span class="item">Row one wraps across lines</span>
<span class="item grid"><b>Grid one</b><b>Grid two</b></span></span> After</p>
<p>Before <span class="column"><span class="item">Column one</span>
<span class="item">Column two</span></span> After</p>')
	allocations.finish()
	enable_native_paint_tree_storage(document)
	for width in [360, 280, 400, 360] {
		_ = layout_document_typed_in_viewport(document, width, 300)
		display := document.record_viewport_display_list() or { panic('missing recording') }
		commands := display_list_commands(display)
		for word in ['Row', 'Grid', 'Column', 'After'] {
			assert commands.any(it.text.contains(word))
		}
	}
	handle := document.layout_engine_handle()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	retire_native_document_layout(handle)
	document.release_native_storage()
}
