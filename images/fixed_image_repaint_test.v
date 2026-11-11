module main

import dom
import html
import layout

// GitHub's avatars have a fixed width and height in flow, under its global
// max-width:100% image rule. Loading one, or giving it another source, must not
// lay out the page again: only its pixels change.

fn fixed_image_repaint_bitmap(width int, height int) html.DecodedImageData {
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

fn fixed_image_repaint_document(style string) &dom.Document {
	address := dom.URL{
		value: 'https://fixed-image-repaint.example.test/'
	}
	document := html.parse_navigation_document('<!doctype html><style>html,body{margin:0}img{max-width:100%}#image{${style}}</style><div><img id="image" src="https://thumbs.example/first.jpg"><span>after</span></div><p>following</p>',
		address, address.origin(), none) or { panic(err) }
	_ = layout.layout_document_typed_in_viewport(document, 200, 100)
	assert document.layout_is_up_to_date()
	return document
}

fn fixed_image_repaint_model(document &dom.Document) (&dom.Element, &html.HTMLImageElementModel) {
	element := document.get_element_by_id('image') or { panic('missing image') }
	return element, html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
}

fn fixed_image_repaint_complete(document &dom.Document, width int, height int) {
	_, mut model := fixed_image_repaint_model(document)
	model.set_fetch_hook(fn [width, height] (_ dom.URL) !html.DecodedImageData {
		return fixed_image_repaint_bitmap(width, height)
	})
	model.update_the_image_data(false, false)
	assert model.complete()
}

fn fixed_image_repaint_replace_source(document &dom.Document, width int, height int) {
	mut element, mut model := fixed_image_repaint_model(document)
	model.set_fetch_hook(fn [width, height] (_ dom.URL) !html.DecodedImageData {
		return fixed_image_repaint_bitmap(width, height)
	})
	previous := element.get_attribute_value('src')
	element.set_attribute_value('src', 'https://thumbs.example/second.jpg')
	html.html_image_element_form_associated_element_attribute_changed(unsafe { &dom.HTMLImageElement(element) },
		'src', previous, 'https://thumbs.example/second.jpg', none)
	assert model.complete()
}

// The display list of the retained paint, which must equal one recorded after
// a full layout-tree rebuild.
fn fixed_image_repaint_commands(document &dom.Document) []layout.PaintCommand {
	mut mutable := unsafe { &dom.Document(document) }
	mutable.update_layout(.debugging)
	list := mutable.record_display_list() or { panic('missing list') }
	retained := list.dump()
	commands := layout.display_list_commands(list).filter(it.kind == 'draw_replaced_image')
	mutable.set_needs_full_layout_tree_update(true)
	mutable.update_layout(.debugging)
	rebuilt := mutable.record_display_list() or { panic('missing rebuilt list') }
	assert rebuilt.dump() == retained
	return commands
}

fn test_in_flow_fixed_size_image_with_a_percentage_maximum_repaints_without_layout() {
	for style in ['width:32px;height:32px', 'width:32px;height:32px;min-width:0;min-height:4px',
		'width:32px;height:32px;display:block;max-height:50%',
		'width:32px;height:32px}div{display:flex}#image{min-width:0;min-height:0'] {
		mut document := fixed_image_repaint_document(style)
		defer { document.finalize() }
		fixed_image_repaint_complete(document, 8, 6)
		assert document.layout_is_up_to_date(), style
		first := fixed_image_repaint_commands(document)
		assert first.len == 1, style
		first_bitmap := first[0].replaced_image_bitmap or { panic('missing pixels') }
		assert first_bitmap.width == 8 && first_bitmap.height == 6
		// Another source with another natural ratio keeps the box.
		fixed_image_repaint_replace_source(document, 16, 16)
		assert document.layout_is_up_to_date(), style
		second := fixed_image_repaint_commands(document)
		assert second.len == 1, style
		assert second[0].image().image_url == 'https://thumbs.example/second.jpg'
		second_bitmap := second[0].replaced_image_bitmap or { panic('missing new pixels') }
		assert second_bitmap.width == 16 && second_bitmap.height == 16
	}
}

fn test_in_flow_image_sized_by_its_contents_or_an_automatic_flex_minimum_needs_layout() {
	for style in ['width:32px;height:auto', 'width:50%;height:32px',
		'width:32px;height:32px;max-width:max-content', 'width:32px;height:32px;min-height:min-content',
		'width:32px;height:32px}div{display:flex'] {
		mut document := fixed_image_repaint_document(style)
		defer { document.finalize() }
		fixed_image_repaint_complete(document, 8, 6)
		assert !document.layout_is_up_to_date(), style
		assert fixed_image_repaint_commands(document).len == 1, style
	}
}
