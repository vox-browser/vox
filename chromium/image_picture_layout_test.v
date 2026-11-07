module main

import html
import dom
import layout
import os

fn test_authored_image_picture_selects_the_transparent_recording_from_real_layout() {
	markup := os.read_file(os.join_path(@VMODROOT,'Tests/Browser/Brave/input/compositor-image-only-picture.html'))!
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
				frame:dom.DecodedImageFrame_.create(&dom.Bitmap_{width:500,height:500,pitch:2000,
					data:[]u8{len:1000000,init:255},native_resource_replay_compatible:true})
			}],0,false)
		})
		model.update_the_image_data(false,false)
	}
	_ = layout.layout_document_typed_in_viewport(document,1024,768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	mut plan := layout.ChromiumRasterLayerPlan{}
	layout.update_chromium_raster_layer_plan_for_viewport(document,commands,1,
		layout.LayoutRect{0,0,1024,768},mut plan)
	mut seen := 0
	for index, command in commands {
		if command.kind != 'draw_replaced_image' { continue }
		seen++
		owner := plan.command_layers[index]
		assert owner > 0
		assert plan.layers[owner].composited_contents
		assert chromium_svg_compositor_layer_supported_for_viewport(commands,plan,owner,
			layout.LayoutRect{0,0,1024,768})
	}
	assert seen == 2
}
