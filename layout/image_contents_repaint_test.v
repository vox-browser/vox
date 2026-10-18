module layout

import dom
import html

fn image_contents_repaint_data(width int, height int) html.DecodedImageData {
	bitmap := &dom.Bitmap_{
		width:  width
		height: height
		pitch:  width * 4
		data:   []u8{len: width * height * 4, init: 255}
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
	assert box.replaced_image_url == 'https://thumbs.example/a.jpg'
	model := complete_image_contents_repaint_image(document, 'fixed')
	assert model.complete()
	assert document.layout_is_up_to_date()
	assert result.needs_repaint
	paintable := box.replaced_image_paintable or { panic('missing image paintable') }
	intrinsic := paintable.intrinsic_size or { panic('missing natural size') }
	assert intrinsic.width or { CSSPixels.new(0) } == CSSPixels.new(8)
	assert intrinsic.height or { CSSPixels.new(0) } == CSSPixels.new(6)
	commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert commands.len == 1
	assert commands[0].image().image_url == 'https://thumbs.example/a.jpg'
}

// An image sized by its natural dimensions, or one with only a percentage
// size, is laid out again when its contents arrive. So is a flex item, whose
// automatic minimum size depends on its content.
fn test_completed_image_sized_by_its_contents_needs_layout() {
	for style in ['', 'width:40px', 'width:40px;height:50%', 'width:40px;height:30px;max-width:max-content',
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
