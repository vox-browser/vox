module layout

import css
import dom
import html
import loader
import http

fn flow_image_rebuild_matches(mut document dom.Document) {
	expected := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('rebuilt paint') }).dump() == expected
}

fn flow_image_changed_sibling(mut document dom.Document, index int) {
	mut changed := document.get_element_by_id('changed') or { panic('changed') }
	changed.set_inner_html('<p>Changed sibling ${index}</p>') or { panic(err) }
}

fn flow_image_layout_handle(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic(id) }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('layout') }.real_layout_handle()) }
}

fn test_retained_flow_images_preserve_decoded_cards_after_restyle_and_sibling_rebuild() {
	mut document, _ := retained_image_fixture()
	defer { document.finalize() }
	for index in 0 .. 3 {
		before := flow_image_layout_handle(document, 'stable')
		photo := flow_image_layout_handle(document, 'photo')
		document.set_needs_full_style_update(true)
		document.update_style()
		flow_image_changed_sibling(mut document, index)
		document.update_layout(.debugging)
		assert (voidptr(flow_image_layout_handle(document, 'stable')) == voidptr(before)) == (!disable_retained_flow_images && !retain_flow_style_identities)
		assert (voidptr(flow_image_layout_handle(document, 'photo')) == voidptr(photo)) == (!disable_retained_flow_images && !retain_flow_style_identities)
		flow_image_rebuild_matches(mut document)
	}
}

fn test_retained_flow_images_recheck_unavailable_network_sources_and_provider_completion() {
	address := dom.URL{ value: 'https://retained-flow-images.example/' }
	mut document := html.parse_navigation_document('<!doctype html><div id="changed"></div><section id="stable" style="display:grid;grid-template-columns:1fr 1fr;width:200px;position:relative"><img src="https://retained-flow-images.example/placeholder.png" style="position:absolute;width:100%"><img id="photo" src="https://retained-flow-images.example/pending.jpg" loading="lazy" style="width:100%"><p>Wrapped words beside image.</p></section>', address, address.origin(), none) or { panic(err) }
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 400)
	before := flow_image_layout_handle(document, 'stable')
	photo := flow_image_layout_handle(document, 'photo')
	document.set_needs_full_style_update(true)
	document.update_style()
	flow_image_changed_sibling(mut document, 0)
	document.update_layout(.debugging)
	assert (voidptr(flow_image_layout_handle(document, 'stable')) == voidptr(before)) == !disable_retained_flow_images
	if !disable_retained_flow_images {
		assert retained_flow_image_input(photo) != none
	}
	mut element := document.get_element_by_id('photo')?
	mut image := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	image.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
		return retained_image_pixels(13, 7, 255)
	})
	image.update_the_image_data(false, false)
	assert image.complete()
	assert retained_flow_image_input(photo) == none
	flow_image_changed_sibling(mut document, 1)
	document.update_layout(.debugging)
	flow_image_rebuild_matches(mut document)
	element.set_attribute_value('src', 'https://retained-flow-images.example/replacement.jpg')
	image.update_the_image_data(false, false)
	flow_image_changed_sibling(mut document, 2)
	document.update_layout(.debugging)
	flow_image_rebuild_matches(mut document)
}

fn test_retained_flow_images_reject_changed_constructor_metadata_and_svg_fallback() {
	mut document, _ := retained_image_fixture()
	defer { document.finalize() }
	photo := flow_image_layout_handle(document, 'photo')
	mut box := photo.as_image_box()?
	if !disable_retained_flow_images {
		assert retained_flow_image_input(photo) != none
	}
	previous := box.natural_size_
	box.natural_size_ = css.SizeWithAspectRatio{ width: CSSPixels.new(99), height: CSSPixels.new(99) }
	assert retained_flow_image_input(photo) == none
	box.natural_size_ = previous
	mut resources := if loader.is_initialized() {
		loader.ResourceLoader.the()
	} else {
		loader.initialize()
	}
	defer { resources.register_network_response(box.source_, loader.NetworkResponse{ status_code: 404 }) }
	resources.register_network_response(box.source_, loader.NetworkResponse{
		data:    '<svg xmlns="http://www.w3.org/2000/svg" width="8" height="6"/>'.bytes()
		headers: [http.Header{'Content-Type', 'image/svg+xml'}]
	})
	assert retained_flow_image_input(photo) == none
}

fn test_retained_flow_images_keep_generated_svg_file_and_other_replaced_content_on_builder() {
	for contents in ['<img src="data:image/svg+xml,%3Csvg/%3E">', '<img src="file:///missing.png">',
		'<canvas width="20" height="10"></canvas>', '<video width="20" height="10"></video>',
		'<svg width="20" height="10"><rect width="20" height="10"/></svg>'] {
		mut document := html.parse_document('<!doctype html><div id="changed"></div><section id="stable">${contents}<p>Text</p></section>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 400)
		before := flow_image_layout_handle(document, 'stable')
		flow_image_changed_sibling(mut document, 0)
		document.update_layout(.debugging)
		assert voidptr(flow_image_layout_handle(document, 'stable')) != voidptr(before)
		flow_image_rebuild_matches(mut document)
	}
}
