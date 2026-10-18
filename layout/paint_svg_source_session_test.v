module layout

import html
import http
import loader

fn paint_source_publish(address string, color string) {
	if !loader.is_initialized() { loader.initialize() }
	mut resources := loader.ResourceLoader.the()
	resources.register_network_response(address, loader.NetworkResponse{
		data:    '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="10"><rect id="shape" width="20" height="10" fill="${color}"/></svg>'.bytes()
		headers: [http.Header{ name: 'Content-Type', value: 'image/svg+xml' }]
	})
}

fn test_paint_source_probes_share_absent_and_present_results_only_for_one_build() {
	address := 'https://paint-source-session.test/asset'
	mut document := html.parse_document('<!doctype html><p>paint owner</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 100)
	result := document_layout_result(document)?
	root := result.root.first_child()?
	viewport := root.root_viewport()?
	scope := begin_paint_svg_source_session(root)
	assert svg_image_source_for_paint(root, address) == none
	paint_source_publish(address, 'lime')
	assert svg_image_source_for_paint(root, address) == none
	assert viewport.paint_svg_sources_.sources.len == 1
	scope.finish()
	assert viewport.paint_svg_sources_ == unsafe { nil }
	old := svg_image_document_for_source_in_viewport(root, address, .light)?
	assert old.get_element_by_id('shape')?.get_attribute_value('fill') == 'lime'
	paint_source_publish(address, 'blue')
	new := svg_image_document_for_source_in_viewport(root, address, .light)?
	assert new.get_element_by_id('shape')?.get_attribute_value('fill') == 'blue'
	assert old.get_element_by_id('shape')?.get_attribute_value('fill') == 'lime'
}

fn test_paint_source_session_separates_color_documents_and_restores_nested_scopes() {
	address := 'https://paint-source-session.test/shared'
	paint_source_publish(address, 'lime')
	mut document := html.parse_document('<!doctype html><p>paint owner</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 100)
	root := document_layout_result(document)?.root.first_child()?
	viewport := root.root_viewport()?
	scope := begin_paint_svg_source_session(root)
	outer := viewport.paint_svg_sources_
	light := svg_image_document_for_source_in_viewport(root, address, .light)?
	dark := svg_image_document_for_source_in_viewport(root, address, .dark)?
	assert voidptr(light) != voidptr(dark)
	assert outer.sources.len == 1
	nested := begin_paint_svg_source_session(root)
	assert voidptr(viewport.paint_svg_sources_) != voidptr(outer)
	assert svg_image_source_for_paint(root, address) != none
	nested.finish()
	assert voidptr(viewport.paint_svg_sources_) == voidptr(outer)
	scope.finish()
	assert viewport.paint_svg_sources_ == unsafe { nil }
}
