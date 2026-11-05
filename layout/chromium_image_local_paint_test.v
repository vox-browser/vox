module layout

import math
import html
import dom
import os
import painting

fn test_rotated_replaced_images_snap_their_size_inside_the_transform_fragment() {
	markup := os.read_file(os.join_path(@DIR,'../Tests/Browser/Brave/input/compositor-image-only-picture.html'))!
	address := dom.URL{value:'https://image-picture.test/'}
	mut document := html.parse_navigation_document(markup.replace('<img src=', '<img id="first" src=')
		.replace('<img class="second"','<img id="second" class="second"'),address,address.origin(),none) or { panic(err) }
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for id in ['first','second'] {
		element := document.get_element_by_id(id) or { panic('missing image element') }
		mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
		model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
			return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{
				frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{width:500,height:500,pitch:2000,
					data:[]u8{len:1000000,init:255},native_resource_replay_compatible:true})
			}],0,false)
		})
		model.update_the_image_data(false,false)
	}
	_ = layout_document_typed_in_viewport(document,1024,768)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	converter := painting.new_device_pixel_converter(1) or { panic('converter') }
	mut seen := 0
	for command in commands {
		if command.kind != 'draw_replaced_image' { continue }
		seen++
		paintable := command.image_paintable or { panic('missing image') }
		result := paintable.paint('image',painting.IntRect{0,0,500,500},converter) or { panic('missing image paint') }
		assert result.bitmap.destination.width == 311
		assert result.bitmap.destination.height == 311
		if seen == 2 {
			// Chromium's LayerTree snapshot records the rotation at (119.085510,
			// 40.229843) inside a picture translated to (13,17).
			assert math.abs(command.transform[4] - 132.08551025390625) < 0.00001
			assert math.abs(command.transform[5] - 57.22984313964844) < 0.00001
		}
	}
	assert seen == 2
}
