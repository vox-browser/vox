module layout

import dom
import html

fn definite_image_repaint_verify_rebuild(document &dom.Document) {
	document.update_layout(.debugging)
	list := document.record_display_list() or { panic('missing list') }
	actual := list.dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	rebuilt := document.record_display_list() or { panic('missing rebuilt list') }
	assert rebuilt.dump() == actual
}

fn test_positioned_definite_image_changed_natural_ratio_refreshes_paint_and_keeps_old_pixels() {
	for fit in ['contain', 'cover', 'fill', 'scale-down', 'none'] {
		mut document := positioned_image_repaint_fixture('position:absolute;inset:0;width:100%;height:100%;object-fit:${fit};object-position:25% 75%')
		defer { document.finalize() }
		result := document_layout_result(document) or { panic('layout') }
		old_commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_replaced_image')
		assert old_commands.len == 1
		old_bitmap := old_commands[0].replaced_image_bitmap or { panic('pixels') }
		assert old_bitmap.width == 8 && old_bitmap.height == 6
		replace_positioned_image_repaint_source(document, 16, 16)
		assert document.layout_is_up_to_date() == !disable_positioned_definite_image_reuse
		document.update_layout(.debugging)
		if !disable_positioned_definite_image_reuse {
			current := document_layout_result(document) or { panic('current layout') }
			assert voidptr(current) == voidptr(result)
		}
		current := document_layout_result(document) or { panic('current layout') }
		commands := current.paint_tree.paint_commands().filter(it.kind == 'draw_replaced_image')
		assert commands.len == 1
		new_bitmap := commands[0].replaced_image_bitmap or { panic('new pixels') }
		assert new_bitmap.width == 16 && new_bitmap.height == 16
		assert voidptr(new_bitmap) != voidptr(old_bitmap)
		assert old_bitmap.width == 8 && old_bitmap.height == 6
		assert old_commands[0].image().image_url == 'https://thumbs.example/first.jpg'
		assert commands[0].image().image_url == 'https://thumbs.example/second.jpg'
		definite_image_repaint_verify_rebuild(document)
	}
}

fn test_positioned_definite_image_first_decode_keeps_percentage_geometry_and_replaces_placeholder() {
	mut document := image_contents_repaint_document('<!doctype html><style>html,body{margin:0}#parent{position:relative;width:160px;height:120px}#image{position:absolute;width:100%;height:100%;object-fit:cover}</style><div id="parent"><img id="image" src="https://thumbs.example/a.jpg"></div><p>Following text</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 200)
	result := document_layout_result(document) or { panic('layout') }
	old_commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert old_commands.len == 1 && old_commands[0].replaced_image_bitmap == none
	model := complete_image_contents_repaint_image(document, 'image')
	assert model.complete()
	assert document.layout_is_up_to_date() == !disable_positioned_definite_image_reuse
	document.update_layout(.debugging)
	current := document_layout_result(document) or { panic('current layout') }
	if !disable_positioned_definite_image_reuse { assert voidptr(current) == voidptr(result) }
	commands := current.paint_tree.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert commands.len == 1
	bitmap := commands[0].replaced_image_bitmap or { panic('new pixels') }
	assert bitmap.width == 8 && bitmap.height == 6
	assert old_commands[0].replaced_image_bitmap == none
	definite_image_repaint_verify_rebuild(document)
}

fn test_positioned_definite_image_repaint_keeps_intrinsic_constraints_and_indefinite_bases_on_layout() {
	for style in ['position:absolute;width:100%;height:auto',
		'position:relative;width:100%;height:100%',
		'position:absolute;width:100%;height:100%;max-width:max-content',
		'position:absolute;width:100%;height:100%;min-height:min-content',
		'position:absolute;width:100%;height:50%}#parent{height:auto'] {
		mut document := positioned_image_repaint_fixture(style)
		defer { document.finalize() }
		replace_positioned_image_repaint_source(document, 16, 16)
		assert !document.layout_is_up_to_date(), style
		definite_image_repaint_verify_rebuild(document)
	}
}

fn test_positioned_definite_image_repaint_rejects_svg_broken_and_pending_selector_geometry_changes() {
	for kind in ['svg', 'broken', 'selector'] {
		style := 'position:absolute;width:100%;height:100%' + if kind == 'selector' { '}#image[src$="second.jpg"]{width:80px' } else { '' }
		mut document := positioned_image_repaint_fixture(style)
		defer { document.finalize() }
		mut element := document.get_element_by_id('image') or { panic('image') }
		mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
		if kind == 'svg' {
			mut svg_document := html.parse_document('<!doctype html><svg xmlns="http://www.w3.org/2000/svg" width="8" height="6"><rect width="8" height="6" fill="green"/></svg>')
			svg_document.set_is_svg_image_document(true)
			model.set_fetch_hook(fn [svg_document] (_ dom.URL) !html.DecodedImageData { return html.SVGDecodedImageData.create(svg_document,8.0,6.0,8.0/6.0) })
		} else if kind == 'broken' {
			model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return error('broken image') })
		} else {
			model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return image_contents_repaint_data(16,16) })
		}
		previous := element.get_attribute_value('src')
		element.set_attribute_value('src','https://thumbs.example/second.jpg')
		html.html_image_element_form_associated_element_attribute_changed(unsafe { &dom.HTMLImageElement(element) }, 'src', previous, 'https://thumbs.example/second.jpg', none)
		document.update_style()
		assert !document.layout_is_up_to_date(), kind
		definite_image_repaint_verify_rebuild(document)
	}
}
