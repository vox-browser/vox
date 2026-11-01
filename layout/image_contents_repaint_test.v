module layout

import dom
import html

fn image_contents_repaint_data(width int, height int) html.DecodedImageData {
	bitmap := &dom.Bitmap_{
		width:                             width
		height:                            height
		pitch:                             width * 4
		data:                              []u8{len: width * height * 4, init: 255}
		native_resource_replay_compatible: true
	}
	return html.BitmapDecodedImageData.create([
		html.BitmapDecodedImageFrame{
			frame: dom.DecodedImageFrame_.create(bitmap)
		},
	], 0, false)
}

fn image_contents_repaint_document(markup string) &dom.Document {
	address := dom.URL{
		value: 'https://image-contents-repaint.example.test/'
	}
	return html.parse_navigation_document(markup, address, address.origin(), none) or { panic(err) }
}

fn image_contents_repaint_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := image_contents_repaint_node(child, id) {
			return found
		}
	}
	return none
}

fn complete_image_contents_repaint_image(document &dom.Document, id string) &html.HTMLImageElementModel {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
		return image_contents_repaint_data(8, 6)
	})
	model.update_the_image_data(false, false)
	return model
}

// 4chan's catalog writes thumbnails with width and height attributes, and
// their bytes arrive in batches. As upstream, an image whose used size cannot
// depend on its natural size is repainted with its new contents; the retained
// paint box takes the natural size without another layout pass.
fn test_completed_image_with_a_definite_size_repaints_without_layout() {
	document := image_contents_repaint_document('<!doctype html><style>html,body{margin:0}img{object-fit:contain}</style><img id="fixed" src="https://thumbs.example/a.jpg" width="40" height="30">')
	layout_document_typed_in_viewport(document, 200, 100)
	assert document.layout_is_up_to_date()
	mut result := document_layout_result(document) or { panic('missing layout') }
	image_node := image_contents_repaint_node(result.root, 'fixed') or { panic('missing image box') }
	assert image_node.is_image_box()
	box := result.retained_box_for_layout(voidptr(image_node)) or { panic('missing paint box') }
	assert box.media().replaced_image_url == 'https://thumbs.example/a.jpg'
	model := complete_image_contents_repaint_image(document, 'fixed')
	assert model.complete()
	assert document.layout_is_up_to_date()
	assert result.needs_repaint
	paintable := box.media().replaced_image_paintable or { panic('missing image paintable') }
	intrinsic := paintable.intrinsic_size or { panic('missing natural size') }
	assert intrinsic.width or { CSSPixels.new(0) } == CSSPixels.new(8)
	assert intrinsic.height or { CSSPixels.new(0) } == CSSPixels.new(6)
	commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert commands.len == 1
	assert commands[0].image().image_url == 'https://thumbs.example/a.jpg'
	frame := model.current_image_frame() or { panic('missing request frame') }
	bitmap := commands[0].replaced_image_bitmap or { panic('missing shared bitmap') }
	assert voidptr(bitmap) == voidptr(frame.bitmap())
}

fn test_paint_only_image_frames_replace_shared_pixels_without_changing_old_commands() {
	document := image_contents_repaint_document('<!doctype html><img id="fixed" src="https://thumbs.example/frames.png" width="40" height="30">')
	element := document.get_element_by_id('fixed') or { panic('missing image') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
		mut frames := []html.BitmapDecodedImageFrame{}
		for index in 0 .. 3 {
			fill_byte := u8(255 - index)
			frames << html.BitmapDecodedImageFrame{
				frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
					width:                             8
					height:                            6
					pitch:                             32
					data:                              []u8{len: 8 * 6 * 4, init: fill_byte}
					native_resource_replay_compatible: index < 2
				})
			}
		}
		return html.BitmapDecodedImageData.create(frames, 0, true)
	})
	model.update_the_image_data(false, false)
	layout_document_typed_in_viewport(document, 200, 100)
	mut result := document_layout_result(document) or { panic('missing layout') }
	image_node := image_contents_repaint_node(result.root, 'fixed') or { panic('missing image box') }
	old_commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert old_commands.len == 1
	old_bitmap := old_commands[0].replaced_image_bitmap or { panic('missing old pixels') }
	assert old_bitmap.data[0] == 255
	model.animate()
	assert layout_paintable_image_contents_changed(voidptr(result), voidptr(image_node))
	assert document.layout_is_up_to_date()
	commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert commands.len == 1
	new_bitmap := commands[0].replaced_image_bitmap or { panic('missing new pixels') }
	assert voidptr(new_bitmap) != voidptr(old_bitmap)
	assert new_bitmap.data[0] == 254 && old_bitmap.data[0] == 255
	frame := model.current_image_frame() or { panic('missing current frame') }
	assert voidptr(new_bitmap) == voidptr(frame.bitmap())
	image_box := image_node.as_image_box() or { panic('missing image provider') }
	generated := ImageBox.new_content_replacement(document, element, image_box.computed_values(), 'https://thumbs.example/css.png')
	assert generated.replaced_image_bitmap() == none
	model.animate()
	assert layout_paintable_image_contents_changed(voidptr(result), voidptr(image_node))
	fallback_commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert fallback_commands.len == 1
	assert fallback_commands[0].replaced_image_bitmap == none
	assert fallback_commands[0].image().image_url == 'https://thumbs.example/frames.png'
	assert new_bitmap.data[0] == 254 && old_bitmap.data[0] == 255
}

// An image sized by its natural dimensions, or one with only a percentage
// size, is laid out again when its contents arrive. So is a flex item, whose
// automatic minimum size depends on its content.
fn test_completed_image_sized_by_its_contents_needs_layout() {
	for style in ['', 'width:40px', 'width:40px;height:50%',
		'width:40px;height:30px;max-width:max-content',
		'width:40px;height:30px;display:block}body{display:flex'] {
		document := image_contents_repaint_document('<!doctype html><style>html,body{margin:0}img{${style}}</style><img id="natural" src="https://thumbs.example/b.jpg">')
		layout_document_typed_in_viewport(document, 200, 100)
		assert document.layout_is_up_to_date()
		complete_image_contents_repaint_image(document, 'natural')
		assert !document.layout_is_up_to_date(), style
	}
}

// A fixed-size image that switches to another source keeps the retained paint
// box's old URL until layout records the new one.
fn test_fixed_size_image_with_a_new_source_needs_layout() {
	document := image_contents_repaint_document('<!doctype html><style>html,body{margin:0}</style><img id="fixed" src="https://thumbs.example/a.jpg" width="40" height="30">')
	layout_document_typed_in_viewport(document, 200, 100)
	complete_image_contents_repaint_image(document, 'fixed')
	assert document.layout_is_up_to_date()
	mut element := document.get_element_by_id('fixed') or { panic('missing image') }
	element.set_attribute_value('src', 'https://thumbs.example/c.jpg')
	html.html_image_element_form_associated_element_attribute_changed(unsafe { &dom.HTMLImageElement(element) },
		'src', 'https://thumbs.example/a.jpg', 'https://thumbs.example/c.jpg', none)
	assert !document.layout_is_up_to_date()
	mut root := layout_document_typed_in_viewport(document, 200, 100)
	commands := root.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert commands.len == 1
	assert commands[0].image().image_url == 'https://thumbs.example/c.jpg'
}

fn positioned_image_repaint_fixture(style string) &dom.Document {
	document := image_contents_repaint_document('<!doctype html><style>html,body{margin:0}#parent{position:relative;width:160px;height:120px}#image{${style}}</style><div id="parent"><img id="image" src="https://thumbs.example/first.jpg"></div><div>following content</div>')
	complete_image_contents_repaint_image(document, 'image')
	layout_document_typed_in_viewport(document, 200, 200)
	assert document.layout_is_up_to_date()
	return document
}

fn replace_positioned_image_repaint_source(document &dom.Document, width int, height int) {
	mut element := document.get_element_by_id('image') or { panic('missing image') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	model.set_fetch_hook(fn [width, height] (_ dom.URL) !html.DecodedImageData {
		return image_contents_repaint_data(width, height)
	})
	previous := element.get_attribute_value('src')
	element.set_attribute_value('src', 'https://thumbs.example/second.jpg')
	html.html_image_element_form_associated_element_attribute_changed(unsafe { &dom.HTMLImageElement(element) },
		'src', previous, 'https://thumbs.example/second.jpg', none)
	assert model.complete()
}

fn test_positioned_image_source_replacement_keeps_geometry_only_with_the_same_natural_ratio() {
	mut document := positioned_image_repaint_fixture('position:absolute;width:100%;height:auto;object-fit:contain')
	defer { document.finalize() }
	result := document_layout_result(document)?
	old_commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert old_commands.len == 1
	old_bitmap := old_commands[0].replaced_image_bitmap?
	assert old_bitmap.width == 8 && old_bitmap.height == 6
	replace_positioned_image_repaint_source(document, 16, 12)
	assert document.layout_is_up_to_date() == !disable_positioned_image_ratio_reuse
	document.update_layout(.debugging)
	actual := (document.record_display_list()?).dump()
	if !disable_positioned_image_ratio_reuse {
		assert voidptr(document_layout_result(document)?) == voidptr(result)
	}
	commands := (document_layout_result(document)?).paint_tree.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert commands.len == 1
	assert commands[0].image().image_url == 'https://thumbs.example/second.jpg'
	new_bitmap := commands[0].replaced_image_bitmap?
	assert new_bitmap.width == 16 && new_bitmap.height == 12
	assert voidptr(new_bitmap) != voidptr(old_bitmap)
	assert old_commands[0].image().image_url == 'https://thumbs.example/first.jpg'
	assert old_bitmap.width == 8
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list()?).dump() == actual
}

fn test_positioned_image_repaint_rejects_changed_ratio_and_intrinsic_constraints() {
	for style in ['position:absolute;width:100%;height:auto',
		'position:relative;width:100%;height:auto',
		'position:absolute;width:auto;height:auto',
		'position:absolute;width:100%;height:auto;max-width:max-content',
		'position:absolute;width:100%;height:auto;min-width:min-content'] {
		mut document := positioned_image_repaint_fixture(style)
		defer { document.finalize() }
		changed_ratio := style == 'position:absolute;width:100%;height:auto'
		replace_positioned_image_repaint_source(document, 16, if changed_ratio { 16 } else { 12 })
		assert !document.layout_is_up_to_date(), style
		document.update_layout(.debugging)
		actual := (document.record_display_list()?).dump()
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		rebuilt := (document.record_display_list()?).dump()
		if rebuilt != actual { eprintln('Image repaint rebuild differs for ${style}') }
		assert rebuilt == actual
	}
}

fn test_positioned_image_repaint_preserves_pending_attribute_selector_relayout() {
	mut document := positioned_image_repaint_fixture('position:absolute;width:100%;height:auto}#image[src$="second.jpg"]{width:80px')
	defer { document.finalize() }
	replace_positioned_image_repaint_source(document, 16, 12)
	document.update_style()
	assert !document.layout_is_up_to_date()
	document.update_layout(.debugging)
	actual := (document.record_display_list()?).dump()
	document.set_needs_full_layout_tree_update(true)
	document.update_layout(.debugging)
	assert (document.record_display_list()?).dump() == actual
}
