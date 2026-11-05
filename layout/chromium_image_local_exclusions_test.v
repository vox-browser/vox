module layout

import dom
import html
import painting

fn image_local_control_geometry(transform string, chromium bool, extra_css string) (bool,int) {
	address := dom.URL{value:'https://image-local.test/'}
	mut document := html.parse_navigation_document('<!doctype html><style>
		html,body{margin:0}.parent{position:relative;width:600px;height:600px}
		img{position:absolute;left:112.5px;top:75.5px;width:310.625px;height:310.625px;transform:${transform}}
		${extra_css}</style><div class="parent"><img id="photo" src="image.png"></div>',
		address,address.origin(),none) or { panic(err) }
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	element := document.get_element_by_id('photo') or { panic('missing image') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
		return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{
			frame:dom.DecodedImageFrame_.create(&dom.Bitmap_{width:500,height:500,pitch:2000,
				data:[]u8{len:1000000,init:255},native_resource_replay_compatible:true})
		}],0,false)
	})
	model.update_the_image_data(false,false)
	_ = layout_document_typed_in_viewport(document,1024,768)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	converter := painting.new_device_pixel_converter(1) or { panic('converter') }
	for command in commands {
		if command.kind != 'draw_replaced_image' { continue }
		paintable := command.image_paintable or { panic('paintable') }
		result := paintable.paint('image',painting.IntRect{0,0,500,500},converter) or { panic('image paint') }
		return command.local_image_data != unsafe { nil },result.bitmap.destination.width
	}
	panic('missing image command')
}

fn test_local_image_snapping_preserves_translation_scale_and_libweb_painting() {
	for transform in ['none','translate(4px,7px)','scale(2,1)'] {
		local,width := image_local_control_geometry(transform,true,'')
		assert !local
		assert width == 310
	}
	local,width := image_local_control_geometry('rotate(7deg)',false,'')
	assert !local
	assert width == 310
}

fn test_local_image_snapping_selects_static_rotation_and_skew() {
	for transform in ['rotate(7deg)','skewX(7deg)'] {
		local,width := image_local_control_geometry(transform,true,'')
		assert local
		assert width == 311
	}
}

fn test_local_image_snapping_retains_depth_animation_and_containment_policies() {
	depth,_ := image_local_control_geometry('rotateX(7deg) rotate(3deg)',true,'')
	assert !depth
	contained,_ := image_local_control_geometry('rotate(7deg)',true,
		'.parent{left:10.25px;top:20.25px;contain:paint}')
	assert !contained
	animated,_ := image_local_control_geometry('rotate(7deg)',true,
		'@keyframes spin{from{transform:rotate(7deg)}to{transform:rotate(14deg)}}#photo{animation:spin 2s infinite paused}')
	assert !animated
}
