module layout

import dom
import html
import painting

fn contained_image_test_command(body string, chromium bool) PaintCommand {
	address := dom.URL{value: 'https://contained-image.test/'}
	mut document := html.parse_navigation_document('<!doctype html><style>html,body{margin:0}.parent{position:absolute;left:356.28125px;top:124.4375px;width:259.421875px;height:172.9375px;overflow:hidden}img{position:absolute;inset:0;width:100%;height:100%;object-fit:fill}</style>${body}', address, address.origin(), none) or { panic(err) }
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	image := document.get_element_by_id('image') or { panic('missing image') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(image) })
	model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
		return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{
			frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{width: 32, height: 24, pitch: 128,
				data: []u8{len: 32 * 24 * 4, init: 255}, native_resource_replay_compatible: true})
		}], 0, false)
	})
	model.update_the_image_data(false, false)
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	for command in commands {
		if command.kind == 'draw_replaced_image' { return command }
	}
	panic('missing image command')
}

fn contained_image_test_paint(command PaintCommand) painting.ImagePaintResult {
	paintable := command.image_paintable or { panic('missing image paintable') }
	converter := painting.new_device_pixel_converter(1) or { panic(err) }
	return paintable.paint('image', painting.IntRect{0, 0, 32, 24}, converter) or { panic('missing paint') }
}

fn test_chromium_images_snap_inside_paint_containment_without_changing_layout() {
	for contain in ['none', 'layout', 'paint', 'strict'] {
		command := contained_image_test_command('<div class="parent" style="contain:${contain}"><img id="image" src="image.png"></div>', true)
		assert command.x == 356.28125 && command.y == 124.4375
		assert command.width == 259.421875 && command.height == 172.9375
		paintable := command.image_paintable or { panic('paintable') }
		contained := contain in ['paint', 'strict']
		assert paintable.paint_offset_adjustment.x == if contained { -.28125 } else { 0.0 }
		assert paintable.paint_offset_adjustment.y == if contained { -.4375 } else { 0.0 }
		result := contained_image_test_paint(command)
		assert result.bitmap.destination == painting.IntRect{356, 124, if contained { 259 } else { 260 }, 173}
		assert result.bitmap.clip_rect == result.bitmap.destination
	}
}

fn test_nested_paint_containment_snaps_from_the_outer_fragment_inward() {
	command := contained_image_test_command('<div style="position:absolute;left:10.25px;top:20.25px;width:500px;height:400px;contain:paint"><div class="parent" style="left:10.25px;top:10.25px;contain:paint"><img id="image" src="image.png"></div></div>', true)
	assert command.x == 20.5 && command.y == 30.5
	result := contained_image_test_paint(command)
	assert result.bitmap.destination == painting.IntRect{20, 30, 259, 173}
}

fn test_contained_image_paint_origin_is_the_border_box_before_padding() {
	command := contained_image_test_command('<div class="parent" style="contain:paint;box-sizing:border-box;padding:2.25px;border:1.5px solid transparent"><img id="image" src="image.png"></div>', true)
	paintable := command.image_paintable or { panic('paintable') }
	assert paintable.paint_offset_adjustment == painting.Point{-.28125, -.4375}
}

fn test_libweb_contained_image_retains_its_existing_absolute_snapping() {
	command := contained_image_test_command('<div class="parent" style="contain:paint"><img id="image" src="image.png"></div>', false)
	paintable := command.image_paintable or { panic('paintable') }
	assert paintable.paint_offset_adjustment == painting.Point{}
	assert contained_image_test_paint(command).bitmap.destination == painting.IntRect{356, 124, 260, 173}
}

fn test_nested_containment_overflow_clip_uses_the_same_fragment_origin_as_images() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>html,body{margin:0}.outer{position:absolute;left:10.25px;top:20.25px;width:500px;height:400px;contain:paint}.inner{position:absolute;left:10.25px;top:10.25px;width:259.421875px;height:50px;overflow:hidden}</style><div class="outer"><div id="target" class="inner" style="contain:paint"></div><div id="ordinary" class="inner" style="top:70.25px"></div></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		result := document_layout_result(document) or { panic('layout') }
		for id in ['target', 'ordinary'] {
			element := document.get_element_by_id(id) or { panic(id) }
			handle := element.as_node().unsafe_layout_node() or { panic('node') }
			node := unsafe { &Node(handle.real_layout_handle()) }
			box := block_box_from_typed_layout_shallow(node, result.state, [6]f64{})
			clip := box.overflow_clip or { panic('clip') }
			expected_x := if !chromium { 20.5 } else if id == 'target' { 20.0 } else { 20.25 }
			expected_y := if id == 'target' { if chromium { 30.0 } else { 30.5 } } else { if chromium { 90.25 } else { 90.5 } }
			assert clip.rect == LayoutRect{expected_x, expected_y, 259.421875, 50}
		}
	}
}
