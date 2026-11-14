module layout

import dom
import html

// These cases exercise the validated salvage of retained_flow_subtrees.v, which
// the builder consults below a flagged ancestor. Their unflagged branches would
// otherwise keep their boxes through clean_subtree_reuse.v first.
fn testsuite_begin() {
	clean_subtree_reuse_suspended = true
}

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

fn test_broken_css_replacement_and_fixed_images_keep_full_tree_builder() {
	for content in ['<img id="photo" src="https://images.example/missing.png" alt="pending">',
		'<img id="photo" src="https://images.example/first.png" style="position:fixed">',
		'<img id="photo" src="https://images.example/first.png" style="content:url(https://images.example/css.png)">'] {
		mut document := flow_image_tree_document('<!doctype html><div id="changed"></div><section id="stable">${content}<p>Caption</p></section>')
		defer { document.finalize() }
		if !content.contains('missing.png') { flow_image_tree_complete(document,8,6,255) }
		if content.contains('missing.png') {
			element := document.get_element_by_id('photo') or { panic('photo') }
			mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
			model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return error('broken') })
			model.update_the_image_data(false,false)
			assert !model.is_image_available() && !model.is_image_pending()
		}
		_ = layout_document_typed_in_viewport(document,400,300)
		before := flow_image_tree_handle(document,'stable')
		flow_image_tree_mutate_sibling(mut document)
		assert flow_image_tree_handle(document,'stable') != before
		flow_image_tree_full_oracle(mut document)
	}
}

fn flow_image_tree_start_pending(document &dom.Document) &html.HTMLImageElementModel {
	element := document.get_element_by_id('photo') or { panic('photo') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	model.set_async_fetch_hook(fn (_ dom.URL, _ html.HTMLImageFetchCompletion) {})
	model.update_the_image_data(false,false)
	assert model.is_image_pending() && !model.is_image_available()
	return model
}

fn test_pending_and_absolute_image_branches_retain_only_structure_across_sibling_mutations() {
	for pending in [false,true] {
		for absolute in [false,true] {
			for mode in ['block','flex','grid'] {
				image_style := if absolute { 'position:absolute;top:0;left:0;width:100%' } else { 'display:block;width:100%' }
				mut document := flow_image_tree_document('<!doctype html><div id="changed"></div><section id="stable" style="display:${mode};gap:7px;grid-template-columns:1fr 2fr"><div style="position:relative;height:90px"><img id="photo" src="https://images.example/first.png" style="${image_style}"></div><p>Image caption</p></section>')
				defer { document.finalize() }
				if pending { flow_image_tree_start_pending(document) } else { flow_image_tree_complete(document,8,6,255) }
				_ = layout_document_typed_in_viewport(document,400,300)
				for _ in 0 .. 2 {
					before := flow_image_tree_handle(document,'stable')
					photo_before := flow_image_tree_handle(document,'photo')
					image_ordinary := retained_flow_raster_image_is_ordinary(unsafe { &Node(photo_before) })
					stable_element := document.get_element_by_id('stable') or { panic('stable') }
					stable_dirty := stable_element.as_node().needs_layout_tree_update_() || stable_element.as_node().child_needs_layout_tree_update_()
					flow_image_tree_mutate_sibling(mut document)
					eligible := !disable_retained_flow_image_trees && (!disable_extended_image_trees || (!pending && !absolute))
					assert (flow_image_tree_handle(document,'stable') == before) == eligible, 'pending=${pending} absolute=${absolute} mode=${mode} image_ordinary=${image_ordinary} stable_dirty=${stable_dirty}'
					assert (flow_image_tree_handle(document,'photo') == photo_before) == eligible
					photo := unsafe { &Node(flow_image_tree_handle(document,'photo')) }
					if absolute { assert photo.is_absolutely_positioned() && !photo.is_flex_item() && !photo.is_grid_item_ }
				}
				flow_image_tree_full_oracle(mut document)
			}
		}
	}
}

fn test_pending_tree_rechecks_success_svg_and_failure_before_reusing_cached_nodes() {
	for kind in ['raster','svg','broken'] {
		mut document := flow_image_tree_document('<!doctype html><div id="changed"></div><section id="stable"><img id="photo" src="https://images.example/pending" alt="Fallback" style="display:block;width:100%"><p>Caption</p></section>')
		defer { document.finalize() }
		mut model := flow_image_tree_start_pending(document)
		_ = layout_document_typed_in_viewport(document,400,300)
		flow_image_tree_mutate_sibling(mut document)
		flow_image_tree_mutate_sibling(mut document)
		before := flow_image_tree_handle(document,'stable')
		if kind == 'svg' {
			svg_document := html.parse_document('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="6"><rect width="8" height="6" fill="green"/></svg>')
			model.set_fetch_hook(fn [svg_document] (_ dom.URL) !html.DecodedImageData { return html.SVGDecodedImageData.create(svg_document,8.0,6.0,8.0/6.0) })
		} else if kind == 'broken' {
			model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return error('broken') })
		} else {
			model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return flow_image_tree_pixels(8,12,128) })
		}
		mut element := document.get_element_by_id('photo') or { panic('photo') }
		element.set_attribute_value('src','https://images.example/complete-${kind}')
		model.update_the_image_data(false,false)
		assert model.complete() && !model.is_image_pending()
		assert model.is_image_available() == (kind != 'broken')
		if kind == 'svg' {
			decoded := model.decoded_image_data() or { panic('SVG') }
			assert decoded is html.SVGDecodedImageData
		}
		document.update_layout(.debugging)
		flow_image_tree_mutate_sibling(mut document)
		if kind != 'raster' { assert flow_image_tree_handle(document,'stable') != before,kind }
		if kind == 'raster' {
			images := display_list_commands(document.record_display_list() or { panic('paint') }).filter(it.kind == 'draw_replaced_image')
			assert images.len == 1 && images[0].image().image_url == 'https://images.example/complete-raster'
			bitmap := images[0].replaced_image_bitmap or { panic('pixels') }
			assert bitmap.width == 8 && bitmap.height == 12 && bitmap.data[0] == 128
		}
		flow_image_tree_full_oracle(mut document)
	}
}

fn test_absolute_image_tree_recomputes_containing_blocks_after_resize_and_role_changes() {
	mut document := flow_image_tree_document('<!doctype html><div id="changed"></div><section id="stable" style="display:grid;width:300px;grid-template-columns:1fr 2fr"><div id="media" style="position:relative;height:90px"><img id="photo" src="https://images.example/first.png" style="position:absolute;left:10%;top:5px;width:80%"></div><p>Caption</p></section>')
	defer { document.finalize() }
	flow_image_tree_complete(document,8,6,255)
	_ = layout_document_typed_in_viewport(document,400,300)
	for mode in ['grid','flex','block'] {
		mut stable := document.get_element_by_id('stable') or { panic('stable') }
		stable.set_attribute_value('style','display:${mode};width:220px;grid-template-columns:1fr 2fr')
		document.update_layout(.debugging)
		flow_image_tree_mutate_sibling(mut document)
		photo := unsafe { &Node(flow_image_tree_handle(document,'photo')) }
		assert photo.is_absolutely_positioned() && !photo.is_flex_item() && !photo.is_grid_item_
		containing := photo.containing_block() or { panic('containing block') }
		assert voidptr(containing) == flow_image_tree_handle(document,'media')
		flow_image_tree_full_oracle(mut document)
	}
}
