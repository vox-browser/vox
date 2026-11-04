module layout

import dom
import html

fn flow_image_tree_document(markup string) &dom.Document {
	address := dom.URL{value:'https://image-tree.example/'}
	return html.parse_navigation_document(markup,address,address.origin(),none) or { panic(err) }
}

fn flow_image_tree_pixels(width int, height int, fill u8) html.DecodedImageData {
	return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{
		frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
			width: width
			height: height
			pitch: width * 4
			data: []u8{len: width * height * 4, init: fill}
			native_resource_replay_compatible: true
		})
	}], 0, false)
}

fn flow_image_tree_complete(document &dom.Document, width int, height int, fill u8) &html.HTMLImageElementModel {
	element := document.get_element_by_id('photo') or { panic('image') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	model.set_fetch_hook(fn [width,height,fill] (_ dom.URL) !html.DecodedImageData {
		return flow_image_tree_pixels(width,height,fill)
	})
	model.update_the_image_data(false, false)
	assert model.complete()
	return model
}

fn flow_image_tree_handle(document &dom.Document, id string) voidptr {
	element := document.get_element_by_id(id) or { panic('element') }
	mirror := element.as_node().unsafe_layout_node() or { panic('layout') }
	return mirror.real_layout_handle()
}

fn flow_image_tree_mutate_sibling(mut document dom.Document) {
	mut changed := document.get_element_by_id('changed') or { panic('changed') }
	changed.set_inner_html('<p>Changed sibling</p>') or { panic(err) }
	document.update_layout(.debugging)
}

fn flow_image_tree_full_oracle(mut document dom.Document) {
	before := (document.record_display_list() or { panic('paint') }).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list() or { panic('full paint') }).dump() == before
}

fn test_decoded_raster_image_branches_keep_tree_identity_and_refresh_geometry() {
	for rules in ['display:block', 'display:flex;gap:7px', 'display:grid;grid-template-columns:1fr 2fr'] {
		mut document := flow_image_tree_document('<!doctype html><div id="changed"></div><section id="stable" style="${rules}"><div><img id="photo" src="https://images.example/first.png" style="display:block;width:100%;height:auto"></div><p>Stable image caption</p></section>')
		defer { document.finalize() }
		flow_image_tree_complete(document,8,6,255)
		_ = layout_document_typed_in_viewport(document,400,300)
		for _ in 0 .. 2 {
			before := flow_image_tree_handle(document,'stable')
			photo_before := flow_image_tree_handle(document,'photo')
			flow_image_tree_mutate_sibling(mut document)
			assert (flow_image_tree_handle(document,'stable') == before) == !disable_retained_flow_image_trees
			assert (flow_image_tree_handle(document,'photo') == photo_before) == !disable_retained_flow_image_trees
			assert document.layout_is_up_to_date()
			// The second iteration uses the existing flow validation cache.
		}
		mut parent := document.get_element_by_id('stable') or { panic('stable') }
		parent.set_attribute_value('style','${rules};width:240px')
		document.update_layout(.debugging)
		flow_image_tree_full_oracle(mut document)
	}
}

fn test_retained_image_tree_source_and_natural_size_changes_keep_current_pixels() {
	mut document := flow_image_tree_document('<!doctype html><div id="changed"></div><section id="stable"><img id="photo" src="https://images.example/first.png" style="display:block;width:100%;height:auto"><p>Caption</p></section>')
	defer { document.finalize() }
	flow_image_tree_complete(document,8,6,255)
	_ = layout_document_typed_in_viewport(document,400,300)
	flow_image_tree_mutate_sibling(mut document)
	old_commands := display_list_commands(document.record_display_list() or { panic('paint') })
	old_images := old_commands.filter(it.kind == 'draw_replaced_image')
	assert old_images.len == 1
	old_bitmap := old_images[0].replaced_image_bitmap or { panic('pixels') }
	mut element := document.get_element_by_id('photo') or { panic('photo') }
	element.set_attribute_value('src','https://images.example/second.png')
	flow_image_tree_complete(document,8,12,128)
	document.update_layout(.debugging)
	flow_image_tree_mutate_sibling(mut document)
	images := display_list_commands(document.record_display_list() or { panic('paint') }).filter(it.kind == 'draw_replaced_image')
	assert images.len == 1
	assert images[0].image().image_url == 'https://images.example/second.png'
	bitmap := images[0].replaced_image_bitmap or { panic('pixels') }
	assert bitmap.width == 8 && bitmap.height == 12 && bitmap.data[0] == 128
	assert old_bitmap.width == 8 && old_bitmap.height == 6 && old_bitmap.data[0] == 255
	assert old_images[0].image().image_url == 'https://images.example/first.png'
	flow_image_tree_full_oracle(mut document)
}

fn test_cached_image_tree_rechecks_svg_and_broken_provider_transitions() {
	for kind in ['svg','broken'] {
		mut document := flow_image_tree_document('<!doctype html><div id="changed"></div><section id="stable"><img id="photo" src="https://images.example/first.png" alt="Fallback"><p>Caption</p></section>')
		defer { document.finalize() }
		flow_image_tree_complete(document,8,6,255)
		_ = layout_document_typed_in_viewport(document,400,300)
		flow_image_tree_mutate_sibling(mut document)
		flow_image_tree_mutate_sibling(mut document)
		mut element := document.get_element_by_id('photo') or { panic('photo') }
		mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
		if kind == 'svg' {
			mut svg_document := html.parse_document('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="6"><rect width="8" height="6" fill="red"/></svg>')
			model.set_fetch_hook(fn [svg_document] (_ dom.URL) !html.DecodedImageData {
				return html.SVGDecodedImageData.create(svg_document,8.0,6.0,8.0/6.0)
			})
		} else {
			model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return error('broken') })
		}
		element.set_attribute_value('src','https://images.example/second-${kind}')
		model.update_the_image_data(false,false)
		if kind == 'svg' {
			decoded := model.decoded_image_data() or { panic('SVG data') }
			assert decoded is html.SVGDecodedImageData
		} else {
			assert !model.is_image_available()
		}
		document.update_layout(.debugging)
		before := flow_image_tree_handle(document,'stable')
		flow_image_tree_mutate_sibling(mut document)
		assert flow_image_tree_handle(document,'stable') != before,kind
		flow_image_tree_full_oracle(mut document)
	}
}

fn test_unavailable_css_replacement_and_positioned_images_keep_full_tree_builder() {
	for content in ['<img id="photo" src="https://images.example/missing.png" alt="pending">',
		'<img id="photo" src="https://images.example/first.png" style="position:absolute">',
		'<img id="photo" src="https://images.example/first.png" style="content:url(https://images.example/css.png)">'] {
		mut document := flow_image_tree_document('<!doctype html><div id="changed"></div><section id="stable">${content}<p>Caption</p></section>')
		defer { document.finalize() }
		if !content.contains('missing.png') { flow_image_tree_complete(document,8,6,255) }
		_ = layout_document_typed_in_viewport(document,400,300)
		before := flow_image_tree_handle(document,'stable')
		flow_image_tree_mutate_sibling(mut document)
		assert flow_image_tree_handle(document,'stable') != before
		flow_image_tree_full_oracle(mut document)
	}
}
