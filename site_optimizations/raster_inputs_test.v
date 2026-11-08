module main

import dom
import layout

fn test_github_raster_inputs_compare_paint_values_across_recordings() {
	mut app := BrowserApp{paint_commands:[layout.PaintCommand{kind:'fill_rect',width:20,height:10,color:'red'}]}
	before := app.github_static_raster_inputs()?
	app.paint_generation++
	assert app.github_static_raster_inputs()? == before
	app.paint_commands[0].color = 'blue'
	assert app.github_static_raster_inputs()? != before
	app.paint_commands[0].color = 'red'
	app.paint_commands[0].opacity = .5
	assert app.github_static_raster_inputs()? != before
	app.paint_commands[0].opacity = 1
	app.paint_commands[0].has_clip = true
	app.paint_commands[0].clip_width = 5
	assert app.github_static_raster_inputs()? != before
}

fn test_github_raster_inputs_include_mutable_path_coordinates_and_pixels() {
	mut path := [f32(1),2,3]
	mut pixels := [u8(255),0,0,255]
	bitmap := &dom.Bitmap_{width:1,height:1,pitch:4,data:pixels}
	mut app := BrowserApp{paint_commands:[layout.PaintCommand{kind:'draw_svg_path',svg_data:&layout.PaintSVGPathData{path:'M1 2',path_data:path}},
		layout.PaintCommand{kind:'draw_image',replaced_image_bitmap:bitmap}]}
	before := app.github_static_raster_inputs()?
	path[1] = 4
	assert app.github_static_raster_inputs()? != before
	path[1] = 2
	assert app.github_static_raster_inputs()? == before
	pixels[0] = 0
	assert app.github_static_raster_inputs()? != before
}

fn test_github_raster_inputs_include_response_bytes_and_decode_availability() {
	address := 'https://avatars.githubusercontent.com/example.png'
	mut app := BrowserApp{paint_commands:[layout.PaintCommand{kind:'draw_image',image_data:&layout.PaintImageData{image_url:address}}]}
	assert app.github_static_raster_inputs() == none
	app.resource_cache[address] = PreloadedResource{url:address,body:'red pixels'}
	before := app.github_static_raster_inputs()?
	app.resource_cache[address] = PreloadedResource{url:address,body:'new pixels'}
	assert app.github_static_raster_inputs()? != before
	app.resource_cache[address] = PreloadedResource{url:address,body:'red pixels'}
	assert app.github_static_raster_inputs()? == before
	app.background_image_scope_ids[address] = 42
	assert app.github_static_raster_inputs()? != before
}

fn test_github_raster_inputs_keep_live_and_unknown_content_on_the_existing_key() {
	for kind in ['draw_canvas','draw_video','draw_nested_document','unknown-command'] {
		app := BrowserApp{paint_commands:[layout.PaintCommand{kind:kind}]}
		assert app.github_static_raster_inputs() == none, kind
	}
}

fn test_github_raster_input_policy_requires_github() {
	mut document := parse_browser_navigation_document('<!doctype html><p>text</p>',dom.URL{value:'https://github.com/vlang/v'},none)
	defer { document.finalize() }
	app := BrowserApp{document:document,paint_commands:[layout.PaintCommand{kind:'fill_rect'}]}
	assert (app.site_stationary_raster_inputs() != none) == !disable_github_raster_input_reuse
	document.url = dom.URL{value:'https://github.com.evil.test/'}
	assert app.site_stationary_raster_inputs() == none
}
