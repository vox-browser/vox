module layout

import dom
import html

fn animated_frame_document(style string) &dom.Document {
	address := dom.URL{value: 'https://animated-image.example/'}
	return html.parse_navigation_document('<!doctype html><p>before</p><img id="photo" src="https://images.example/a.gif" style="${style}"><p>after</p>',
		address, address.origin(), none) or { panic(err) }
}

fn animated_frame_bitmap(fill u8) &dom.Bitmap_ {
	return &dom.Bitmap_{
		width:  4
		height: 2
		pitch:  16
		data:   []u8{len: 32, init: fill}
		native_resource_replay_compatible: true
	}
}

fn animated_frame_complete(document &dom.Document, session i64) &html.AnimatedDecodedImageData {
	element := document.get_element_by_id('photo') or { panic('image') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	data := html.AnimatedDecodedImageData.create(session, 2, 0, 4, 2, .srgb, [u32(100), 100],
		[animated_frame_bitmap(10), animated_frame_bitmap(200)], none, none)
	model.set_fetch_hook(fn [data] (_ dom.URL) !html.DecodedImageData {
		return html.DecodedImageData(data)
	})
	model.update_the_image_data(false, false)
	assert model.complete()
	return data
}

fn animated_frame_shown(document &dom.Document) voidptr {
	result := document_layout_result(document) or { panic('layout') }
	commands := result.paint_tree.paint_commands().filter(it.kind == 'draw_replaced_image')
	assert commands.len == 1
	bitmap := commands[0].replaced_image_bitmap or { panic('bitmap') }
	return voidptr(bitmap)
}

// A new animation frame changes pixels, never the box: the decoded-data
// client repaints without a relayout, whether or not the box's size depends
// on the image's natural size.
fn test_animated_image_frames_repaint_without_relayout() {
	for index, style in ['display:block;width:40px;height:20px', 'display:block'] {
		mut document := animated_frame_document(style)
		mut data := animated_frame_complete(document, 9100 + i64(index))
		_ = layout_document_typed_in_viewport(document, 200, 100)
		_ = (document.record_display_list() or { panic('paint') }).dump()
		assert animated_frame_shown(document) == voidptr((data.frame(0) or { panic('frame 0') }).bitmap())
		element := document.get_element_by_id('photo') or { panic('image') }
		mirror := element.as_node().unsafe_layout_node() or { panic('layout') }
		image_box := unsafe { &Node(mirror.real_layout_handle()) }
		assert !image_box.needs_layout_update()
		data.advance_animation()
		assert !image_box.needs_layout_update(), style
		assert document.layout_is_up_to_date(), style
		painted := (document.record_display_list() or { panic('repaint') }).dump()
		// The display list dump does not name bitmaps; the paint command does.
		assert animated_frame_shown(document) == voidptr((data.frame(1) or { panic('frame 1') }).bitmap()), style
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		assert (document.record_display_list() or { panic('full paint') }).dump() == painted
		assert animated_frame_shown(document) == voidptr((data.frame(1) or { panic('frame 1') }).bitmap()), style
		data.finalize()
		document.finalize()
	}
}
