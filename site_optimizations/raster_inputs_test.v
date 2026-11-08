module main

import dom
import layout
import painting

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
		layout.PaintCommand{kind:'draw_replaced_image',replaced_image_bitmap:bitmap}]}
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
	mut app := BrowserApp{paint_commands:[layout.PaintCommand{kind:'draw_replaced_image',image_data:&layout.PaintImageData{image_url:address}}]}
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

fn test_github_raster_inputs_keep_empty_and_deferred_bitmaps_on_the_revision_key() {
	mut bitmap := &dom.Bitmap_{}
	app := BrowserApp{paint_commands:[layout.PaintCommand{kind:'draw_replaced_image',replaced_image_bitmap:bitmap}]}
	assert app.github_static_raster_inputs() == none
	bitmap.data = [u8(255),0,0,255]
	assert app.github_static_raster_inputs() != none
	deferred := dom.Bitmap_.create_deferred(1,1,fn (mut image dom.Bitmap_) {
		image.data = [u8(255),0,0,255]
	})
	deferred_app := BrowserApp{paint_commands:[layout.PaintCommand{kind:'draw_replaced_image',replaced_image_bitmap:deferred}]}
	assert deferred_app.github_static_raster_inputs() == none
	assert !deferred.has_pixels()
	deferred.ensure_pixels()
	assert deferred_app.github_static_raster_inputs() != none
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

fn test_github_raster_inputs_include_border_and_shadow_geometry() {
	for kind in ['paint_uniform_border', 'paint_rounded_border_top', 'paint_partial_rounded_border',
		'paint_inner_box_shadow', 'paint_outer_box_shadow'] {
		mut app := BrowserApp{paint_commands:[layout.PaintCommand{kind:kind,width:20,height:10,color:'red'}]}
		before := app.github_static_raster_inputs()?
		app.paint_commands[0].stroke_width = 2
		assert app.github_static_raster_inputs()? != before, kind
		app.paint_commands[0].stroke_width = 0
		app.paint_commands[0].blur = 4
		assert app.github_static_raster_inputs()? != before, kind
	}
}

fn test_github_raster_inputs_ignore_only_leaves_the_renderer_culls() {
	mut app := BrowserApp{paint_commands:[
		layout.PaintCommand{kind:'fill_rect',width:100,height:2000,color:'white'},
		layout.PaintCommand{kind:'fill_rect',x:10,y:500,width:20,height:20,color:'red'},
		layout.PaintCommand{kind:'draw_replaced_image',x:10,y:600,width:20,height:20,
			image_paintable:&painting.ImagePaintable{image_rect:painting.Rect{10,600,20,20}},
			replaced_image_bitmap:&dom.Bitmap_{}},
	]}
	assert app.github_static_raster_inputs() == none
	before := app.github_static_raster_inputs_in_canvas(0,100,100,true)?
	app.paint_commands[0].height = 3000
	app.paint_commands[1].color = 'blue'
	app.paint_commands << layout.PaintCommand{kind:'fill_rect',x:10,y:900,width:20,height:20,color:'green'}
	assert app.github_static_raster_inputs_in_canvas(0,100,100,true)? == before
	app.paint_commands[1].y = 20
	assert app.github_static_raster_inputs_in_canvas(0,100,100,true)? != before
	app.paint_commands[1].y = 500
	app.paint_commands[2].y = 30
	assert app.github_static_raster_inputs_in_canvas(0,100,100,true)? == before
	app.paint_commands[2].image_paintable = &painting.ImagePaintable{image_rect:painting.Rect{10,30,20,20}}
	assert app.github_static_raster_inputs_in_canvas(0,100,100,true) == none
	app.paint_commands[2].y = 600
	app.paint_commands[2].image_paintable = &painting.ImagePaintable{image_rect:painting.Rect{10,600,20,20}}
	assert app.github_static_raster_inputs_in_canvas(0,100,100,false) == none
}

fn test_github_raster_inputs_preserve_offscreen_filter_inputs_and_unknown_commands() {
	for begin in ['begin_css_filter_layer','begin_svg_mask_layer'] {
		app := BrowserApp{paint_commands:[
			layout.PaintCommand{kind:begin},
			layout.PaintCommand{kind:'draw_replaced_image',x:10,y:600,width:20,height:20,replaced_image_bitmap:&dom.Bitmap_{}},
		]}
		assert app.github_static_raster_inputs_in_canvas(0,100,100,true) == none, begin
	}
	unknown := BrowserApp{paint_commands:[layout.PaintCommand{kind:'future-command',y:600,width:20,height:20}]}
	assert unknown.github_static_raster_inputs_in_canvas(0,100,100,true) == none
}
