module layout

import dom
import css
import html

fn test_native_measurement_scratch_reuses_whole_probes_and_preserves_nested_results() {
	document := dom.Document.create(dom.url_about_blank())
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	source.measurement_chunk_pool_.scratch_enabled_ = true
	pool := source.measurement_chunk_pool_
	mut first := source.new_measurement_for_subtree(node)
	first_values := []u8{len: 8192, init: 17}
	mut nested := first.new_measurement_for_subtree(node)
	nested.get_mutable(node).set_content_width(CSSPixels.new(42))
	width := nested.get(node).content_width()
	nested.release_measurement()
	assert width.raw_value() == CSSPixels.new(42).raw_value()
	assert first_values[0] == 17 && first_values[first_values.len - 1] == 17
	first.release_measurement()
	$if prealloc {
		assert pool.scratch_depth_ == 0
		assert pool.scratch_slots_.len == 2
	}
	for _ in 0 .. 50 {
		mut probe := source.new_measurement_for_subtree(node)
		_ = []u8{len: 8192, init: 19}
		probe.get_mutable(node).set_content_width(CSSPixels.new(23))
		result := probe.get(node).content_width()
		probe.release_measurement()
		assert result.raw_value() == CSSPixels.new(23).raw_value()
	}
	$if prealloc { assert pool.scratch_slots_.len == 2 }
	source.release_measurement_chunk_pool()
	assert pool.scratch_slots_.len == 0
}

fn test_native_intrinsic_caches_survive_probe_reuse_and_later_layout_passes() {
	url := dom.URL{value: 'https://measurement-scratch.example/'}
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.set_font_rendering_policy(.chromium)
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>
main{display:flex;width:fit-content}section{display:inline-flex;flex-direction:column}
p{max-width:140px}table{width:min-content}td{padding:3px}</style>
<main><section><button>Measured button text</button><p>Wrapped text with several words.</p>
<table><caption>Measured caption</caption><tr><td>First cell</td><td>Second cell</td></tr></table>
</section><section><input placeholder="Measured input"><p>Second measured column</p></section></main>')
	allocations.finish()
	enable_native_paint_tree_storage(document)
	for width in [320, 360, 280, 320] {
		_ = layout_document_typed_in_viewport(document, width, 240)
		display_list := document.record_viewport_display_list() or { panic('missing recording') }
		commands := display_list_commands(display_list)
		assert commands.any(it.text.contains('Measured'))
	}
	handle := document.layout_engine_handle()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	retire_native_document_layout(handle)
	document.release_native_storage()
}
