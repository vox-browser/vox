module layout

import dom
import html
import os

fn svg_image_tree_document() &dom.Document {
	address := dom.URL{value:'https://svg-image-tree.example/'}
	return html.parse_navigation_document('<!doctype html><div id="changed"></div><section id="stable"><p><a href="https://example.org/"><img id="badge" src="https://images.example/badge.svg"></a> caption</p></section>', address, address.origin(), none) or { panic(err) }
}

fn svg_image_tree_decode(document &dom.Document, svg bool) {
	mut element := document.get_element_by_id('badge') or { panic('image') }
	if !svg { element.set_attribute_value('src', 'https://images.example/badge.png') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	if svg {
		svg_document := html.parse_document('<svg xmlns="http://www.w3.org/2000/svg" width="40" height="12"><rect width="40" height="12" fill="green"/></svg>')
		model.set_fetch_hook(fn [svg_document] (_ dom.URL) !html.DecodedImageData {
			return html.SVGDecodedImageData.create(svg_document, 40.0, 12.0, 40.0 / 12.0)
		})
	} else {
		model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
			return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{
				frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
					width: 20
					height: 6
					pitch: 80
					data: []u8{len: 480, init: 255}
					native_resource_replay_compatible: true
				})
			}], 0, false)
		})
	}
	model.update_the_image_data(false, false)
	assert model.complete()
	decoded := model.decoded_image_data() or { panic('image data') }
	assert (decoded is html.SVGDecodedImageData) == svg
}

fn svg_image_tree_handle(document &dom.Document, id string) voidptr {
	element := document.get_element_by_id(id) or { panic(id) }
	node := element.as_node()
	mirror := node.unsafe_layout_node() or { panic('layout') }
	return mirror.real_layout_handle()
}

fn svg_image_tree_update_sibling(mut document dom.Document, text string) {
	mut changed := document.get_element_by_id('changed') or { panic('changed') }
	changed.set_inner_html('<p>${text}</p>') or { panic(err) }
	document.update_layout(.debugging)
}

fn svg_image_tree_matches_full_rebuild(mut document dom.Document) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before
}

// An image showing a decoded SVG document keeps its boxes, and its
// ancestors theirs, across a layout tree update elsewhere.
fn test_svg_image_branches_keep_their_boxes_until_the_image_changes_kind() {
	mut document := svg_image_tree_document()
	defer { document.finalize() }
	svg_image_tree_decode(document, true)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	keeps := os.getenv('VOX_RETAIN_SVG_IMAGE_TREE_REBUILDS') == ''
	for index in 0 .. 2 {
		stable := svg_image_tree_handle(document, 'stable')
		badge := svg_image_tree_handle(document, 'badge')
		svg_image_tree_update_sibling(mut document, 'changed ${index}')
		assert (svg_image_tree_handle(document, 'stable') == stable) == keeps, 'pass ${index}'
		assert (svg_image_tree_handle(document, 'badge') == badge) == keeps, 'pass ${index}'
		svg_image_tree_matches_full_rebuild(mut document)
	}
	// After the element decodes to a raster image, no kept box shows the
	// SVG document.
	svg_image_tree_decode(document, false)
	document.update_layout(.debugging)
	svg_image_tree_update_sibling(mut document, 'raster')
	box := unsafe { &Node(svg_image_tree_handle(document, 'badge')) }
	image := box.as_image_box() or { panic('image box') }
	if _ := image.svg_image_document() {
		assert false, 'kept the SVG document'
	}
	svg_image_tree_matches_full_rebuild(mut document)
}
