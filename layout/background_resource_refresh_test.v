module layout

import dom
import html
import loader
import http

const resource_refresh_source = '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10"><rect id="shape" width="20" height="10" fill="lime"/></svg>'

fn resource_refresh_publish(address string, source string) {
	if !loader.is_initialized() { loader.initialize() }
	mut resource_loader := loader.ResourceLoader.the()
	resource_loader.register_network_response(address, loader.NetworkResponse{
		data: source.bytes()
		headers: [http.Header{name:'Content-Type',value:'image/svg+xml'}]
	})
}

fn resource_refresh_commands(document &dom.Document) []PaintCommand {
	mut mutable_document := unsafe { &dom.Document(document) }
	return display_list_commands(record_retained_display_list(mut mutable_document) or { panic('missing display list') })
}

fn test_completed_background_refresh_retains_geometry_and_body_block_inline_owners() {
	address := 'https://resource-refresh.test/shared.svg'
	document := html.parse_document('<!doctype html><style>html,body{margin:0}body,div,span{background:url("${address}") no-repeat}div{width:40px;height:20px}</style><body><div id="block"></div><span id="inline">inline text</span><p id="untouched">stable text</p></body>')
	_ = layout_document_typed_in_viewport(document, 200, 100)
	before := document_layout_result(document) or { panic('missing retained layout') }
	root := voidptr(before.root)
	state := voidptr(before.state)
	children := voidptr(before.paint_tree.children.data)
	first_commands := resource_refresh_commands(document)
	assert first_commands.filter(it.kind == 'draw_background_image').len >= 3
	assert !first_commands.any(it.image().background_svg_document != none)
	mut mutable_document := unsafe { &dom.Document(document) }
	hit := mutable_document.element_from_point(2, 2)
	assert before.hit_test_display_list_is_valid
	untouched := document.get_element_by_id('untouched')?
	mut untouched_phase := -1
	for index, entry in before.paint_order {
		if entry.box.node_id == i64(untouched.as_node().unique_id()) { untouched_phase = index }
	}
	assert untouched_phase >= 0
	assert before.paint_phase_entry_valid[untouched_phase]
	resource_refresh_publish(address, resource_refresh_source)
	assert refresh_document_background_resources(document, {address:true})
	after := document_layout_result(document) or { panic('missing refreshed layout') }
	assert voidptr(after.root) == root
	assert voidptr(after.state) == state
	assert voidptr(after.paint_tree.children.data) == children
	assert after.hit_test_display_list_is_valid
	assert after.paint_phase_entry_valid[untouched_phase]
	assert mutable_document.element_from_point(2, 2) == hit
	commands := resource_refresh_commands(document)
	layers := commands.filter(it.kind == 'draw_background_image')
	assert layers.len == first_commands.filter(it.kind == 'draw_background_image').len
	isolated := layers[0].image().background_svg_document or { panic('missing completed background') }
	for layer in layers {
		assert voidptr(layer.image().background_svg_document?) == voidptr(isolated)
		assert layer.image().image_intrinsic_width == 20
		assert layer.image().image_intrinsic_height == 10
	}
	assert document.layout_is_up_to_date()
}

fn test_background_refresh_replaces_same_size_bytes_and_drops_failed_resource_without_mutating_old_owners() {
	address := 'https://resource-refresh.test/replaced.svg'
	resource_refresh_publish(address, resource_refresh_source)
	document := html.parse_document('<!doctype html><div style="width:20px;height:10px;background:url(${address})"></div>')
	_ = layout_document_typed_in_viewport(document, 100, 100)
	old_commands := resource_refresh_commands(document)
	old_document := old_commands.filter(it.image().background_svg_document != none)[0].image().background_svg_document?
	resource_refresh_publish(address, resource_refresh_source.replace('lime', 'blue'))
	assert refresh_document_background_resources(document, {address:true})
	new_commands := resource_refresh_commands(document)
	new_document := new_commands.filter(it.image().background_svg_document != none)[0].image().background_svg_document?
	assert voidptr(old_document) != voidptr(new_document)
	assert old_document.get_element_by_id('shape')?.get_attribute_value('fill') == 'lime'
	assert new_document.get_element_by_id('shape')?.get_attribute_value('fill') == 'blue'
	assert voidptr(old_commands.filter(it.image().background_svg_document != none)[0].image().background_svg_document?) == voidptr(old_document)
	mut resource_loader := loader.ResourceLoader.the()
	resource_loader.register_network_response(address, loader.NetworkResponse{status_code:404})
	assert refresh_document_background_resources(document, {address:true})
	assert !resource_refresh_commands(document).any(it.image().background_svg_document != none)
	assert new_document.get_element_by_id('shape')?.get_attribute_value('fill') == 'blue'
}

fn test_background_refresh_falls_back_for_pending_style_repaint_and_unmatched_resources() {
	address := 'https://resource-refresh.test/fallback.svg'
	document := html.parse_document('<!doctype html><div id="target" style="width:20px;height:10px;background:url(${address})"></div>')
	assert !refresh_document_background_resources(document, {address:true})
	_ = layout_document_typed_in_viewport(document, 100, 100)
	_ = resource_refresh_commands(document)
	assert !refresh_document_background_resources(document, {'https://resource-refresh.test/other.svg':true})
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	target.set_attribute_value('style', 'width:40px;height:20px;background:url(${address});opacity:.5')
	assert !refresh_document_background_resources(document, {address:true})
	_ = layout_document_typed_in_viewport(document, 100, 100)
	_ = resource_refresh_commands(document)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_needs_repaint_with_invalidation(.paint_commands)
	assert !refresh_document_background_resources(document, {address:true})
	_ = resource_refresh_commands(document)
	assert refresh_document_background_resources(document, {address:true})
	box := document_layout_result(document)?.paint_tree.find_box(i64(target.as_node().unique_id()))?
	assert box.width == 40
	assert box.height == 20
	assert box.opacity == 0.5
}

fn test_background_refresh_defers_pending_container_query_stabilization_to_normal_layout() {
 address := 'https://resource-refresh.test/query.svg'
 document := html.parse_document('<!doctype html><style>#container{container-type:inline-size;width:100px;height:30px}#target{background:url(${address})}</style><div id="container"><p id="target">query content</p></div>')
 _ = layout_document_typed_in_viewport(document, 200, 100)
 _ = resource_refresh_commands(document)
 container := document.get_element_by_id('container')?
 mut mutable_document := unsafe { &dom.Document(document) }
 mutable_document.set_needs_container_query_evaluation_after_layout(container)
 assert document.layout_is_up_to_date()
 assert document.needs_style_update_after_layout()
 assert !refresh_document_background_resources(document, {address:true})
 _ = layout_document_typed_in_viewport(document, 200, 100)
 _ = resource_refresh_commands(document)
 assert !document.needs_style_update_after_layout()
 resource_refresh_publish(address, resource_refresh_source)
 assert refresh_document_background_resources(document, {address:true})
}

fn test_declined_background_completion_refreshes_snapshot_during_retained_viewport_relayout() {
	address := 'https://resource-refresh.test/late-arrow.svg'
	mut document := html.parse_document('<!doctype html><div style="width:10px;height:10px;background:url(${address})"></div>')
	defer { document.finalize() }
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 200, 100)
	assert !resource_refresh_commands(document).any(it.image().background_svg_document != none
		|| it.image().background_static_svg_resource != none)
	root := document.layout_engine_handle()
	resource_refresh_publish(address, resource_refresh_source)
	document.set_needs_repaint_with_invalidation(.paint_commands)
	assert !refresh_document_background_resources(document, {address:true})
	_ = layout_document_typed_in_viewport(document, 200, 100)
	assert document.layout_engine_handle() == root
	assert resource_refresh_commands(document).any(it.image().background_svg_document != none
		|| it.image().background_static_svg_resource != none)
}
