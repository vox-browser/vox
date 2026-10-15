module layout

import dom
import html
import painting

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn svg_filter_snapshot_recorded_filter(document &dom.Document) painting.GfxFilter {
	mut mutable_document := unsafe { &dom.Document(document) }
	commands := display_list_commands(mutable_document.record_display_list() or {
		panic('missing display list')
	})
	layers := commands.filter(it.kind == 'begin_css_filter_layer')
	assert layers.len == 1
	return layers[0].visual_layer().filter or { panic('missing recorded filter') }
}

fn test_svg_filter_snapshot_tracks_resource_and_source_removal_without_mutating_old_recordings() {
	mut document :=
		html.parse_document('<!doctype html><style>body{margin:0}#target{width:80px;height:40px;background:red;filter:contrast(150%) url(#fx)}</style><svg width="0" height="0"><defs><filter id="fx"><feFlood id="flood" flood-color="blue"/></filter></defs></svg><div id="target"></div>')
	_ = layout_document_typed_in_viewport(document, 160, 120)
	first := svg_filter_snapshot_recorded_filter(document)
	assert first.nodes.len == 1
	assert first.nodes[0].color == painting.Color{0, 0, 255, 255}
	assert first.operations.len == 1
	mut flood := document.get_element_by_id('flood') or { panic('missing flood') }
	flood.set_attribute_value('flood-color', 'green')
	document.update_layout(.dump_display_list)
	second := svg_filter_snapshot_recorded_filter(document)
	assert second.nodes[0].color == painting.Color{0, 128, 0, 255}
	assert first.nodes[0].color == painting.Color{0, 0, 255, 255}
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	target.set_attribute_value('style', 'filter:contrast(150%)')
	document.update_layout(.dump_display_list)
	css_only := svg_filter_snapshot_recorded_filter(document)
	assert css_only.nodes.len == 0
	assert css_only.operations.len == 1
	assert css_only.bounds == none
	target.set_attribute_value('style', 'filter:none')
	document.update_layout(.dump_display_list)
	commands := display_list_commands(document.record_display_list() or {
		panic('missing final recording')
	})
	assert !commands.any(it.kind == 'begin_css_filter_layer')
	$if gcboehm ? { C.GC_gcollect() }
	assert first.nodes[0].color == painting.Color{0, 0, 255, 255}
	assert second.nodes[0].color == painting.Color{0, 128, 0, 255}
}
