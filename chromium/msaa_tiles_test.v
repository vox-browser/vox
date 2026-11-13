module main

import layout
import css
import dom
import html
import painting
import platform

fn test_nested_svg_paths_trigger_msaa_in_the_owning_document_tile() {
	commands := [layout.PaintCommand{
		kind: 'paint_nested_display_list'
		transform: [f64(1), 0, 0, 1, 0, 10]!
		nested_viewport_paintable: &painting.NavigableContainerViewportPaintable{
			viewport_rect: painting.Rect{10, 500, 80, 80}
		}
		nested_viewport_commands: [msaa_test_svg_path(10, 30, 'svg')]
	}]
	triggers := chromium_msaa_triggers(commands)
	assert triggers.len == 1
	assert triggers[0].command_index == 0
	assert triggers[0].top == 519
	assert triggers[0].bottom == 541
	assert chromium_msaa_tiles(commands, 1, 256) == [2]
}

fn msaa_test_svg_path(top f64, bottom f64, role string) layout.PaintCommand {
	mut path_data := []f32{}
	for index, y in [top, bottom] {
		mut segment := []f32{len: layout.compatibility_clip_path_segment_stride}
		segment[0] = if index == 0 { f32(0) } else { f32(1) }
		segment[1] = 10
		segment[2] = f32(y)
		path_data << segment
	}
	return layout.PaintCommand{
		kind:            'draw_svg_path'
		force_dark_role: if role == 'border' { .border } else { .svg }
		svg_data:        &layout.PaintSVGPathData{
			path_data: path_data
		}
	}
}

fn msaa_test_underline(y f64, clips int) layout.PaintCommand {
	mut clip_outs := []f64{}
	for index in 0 .. clips {
		clip_outs << [f64(20 + index * 30), y - 0.5, f64(30 + index * 30), y + 1.5]
	}
	return layout.PaintCommand{
		kind:             'fill_rect'
		x:                10
		y:                y
		width:            100
		height:           1
		antialiased_rect: true
		clip_outs:        clip_outs
	}
}

fn test_empty_clips_do_not_change_the_document_tile_multisampling_mode() {
	for extent in [[f64(0), 20], [f64(20), 0], [f64(-1), 20], [f64(20), -1]] {
		width := extent[0]
		height := extent[1]
		for leaf in [msaa_test_svg_path(10, 30, 'svg'), msaa_test_underline(10, 2), layout.PaintCommand{
			kind:         'paint_uniform_border'
			x:            10
			y:            10
			width:        30
			height:       20
			stroke_width: 1
			corner_radii: layout.BoxRadii{ top_left: layout.CornerRadius{5, 3} }
		}] {
			clipped := layout.PaintCommand{
				...leaf
				has_clip:    true
				clip_width:  width
				clip_height: height
			}
			assert chromium_msaa_triggers([clipped]).len == 0
			assert chromium_msaa_tiles([clipped, msaa_test_svg_path(300, 310, 'svg')], 1, 256) == [1]
		}
	}
	visible := layout.PaintCommand{
		...msaa_test_svg_path(10, 30, 'svg')
		has_clip:    true
		clip_width:  40
		clip_height: 40
	}
	assert chromium_msaa_tiles([visible], 1, 256) == [0]
}

fn test_empty_nested_viewport_clips_discard_their_vector_triggers() {
	image := layout.PaintCommand{
		kind:                      'paint_nested_display_list'
		has_clip:                  true
		clip_width:                0
		clip_height:               20
		nested_viewport_paintable: &painting.NavigableContainerViewportPaintable{
			viewport_rect: painting.Rect{10, 10, 20, 20}
		}
		nested_viewport_commands:  [msaa_test_svg_path(0, 20, 'svg')]
	}
	assert chromium_msaa_triggers([image]).len == 0
	assert chromium_msaa_tiles([layout.PaintCommand{ ...image, clip_width: 20 }], 1, 256) == [0]
}

fn test_collapsed_path_clips_ignore_their_positive_reference_box() {
	for points in [
		[]f32{},
		[f32(0), 10, 10, 1, 10, 20, 5, 0, 0],
		[f32(0), 10, 10, 1, 20, 10, 5, 0, 0],
		[f32(0), 10, 10, 1, 10, 10, 5, 0, 0],
	] {
		mut packed := []f32{}
		for offset := 0; offset < points.len; offset += 3 {
			mut segment := []f32{len: layout.compatibility_clip_path_segment_stride}
			segment[0] = points[offset]
			segment[1] = points[offset + 1]
			segment[2] = points[offset + 2]
			packed << segment
		}
		command := layout.PaintCommand{
			...msaa_test_svg_path(10, 30, 'svg')
			has_clip: true
			clip_width: 100
			clip_height: 100
			clip_list: &layout.PaintClipList{items:[layout.PaintClip{
				rect: layout.LayoutRect{width:100,height:100}
				is_path: true
				path_data: packed
			}]}
		}
		assert chromium_msaa_tiles([command, msaa_test_svg_path(300, 310, 'svg')], 1, 256) == [1]
	}
}

fn test_visible_and_curved_clip_paths_keep_multisampling() {
	mut polygon := []f32{len: layout.compatibility_clip_path_segment_stride * 3}
	polygon[layout.compatibility_clip_path_segment_stride] = 1
	polygon[layout.compatibility_clip_path_segment_stride + 1] = 20
	polygon[layout.compatibility_clip_path_segment_stride * 2] = 1
	polygon[layout.compatibility_clip_path_segment_stride * 2 + 2] = 20
	for kind in [1, 2, 3, 4, 6] {
		mut path := polygon.clone()
		path[layout.compatibility_clip_path_segment_stride] = f32(kind)
		clip := layout.PaintClip{is_path:true,path_data:path}
		command := layout.PaintCommand{
			...msaa_test_svg_path(10, 30, 'svg')
			has_clip: true
			clip_width: 100
			clip_height: 100
			clip_list: &layout.PaintClipList{items:[clip]}
		}
		assert chromium_msaa_tiles([command], 1, 256) == [0]
	}
}

fn test_zero_opacity_svg_paints_do_not_multisample_neighboring_draws() {
	base := msaa_test_svg_path(10, 30, 'svg')
	for fill_opacity in [f64(0), -0.5] {
		for stroke_width in [f64(0), 2] {
			command := layout.PaintCommand{
				...base
				color: '#000'
				stroke_color: '#f00'
				stroke_width: stroke_width
				svg_data: &layout.PaintSVGPathData{
					...base.svg_data
					fill_opacity: fill_opacity
					stroke_opacity: 0
				}
			}
			assert chromium_msaa_tiles([command, msaa_test_svg_path(300, 310, 'svg')], 1, 256) == [1]
		}
	}
	unstroked := layout.PaintCommand{
		...base
		color: '#000'
		stroke_width: 2
		svg_data: &layout.PaintSVGPathData{ ...base.svg_data, fill_opacity: 0 }
	}
	assert chromium_msaa_triggers([unstroked]).len == 0
	assert chromium_msaa_triggers([layout.PaintCommand{ ...base, opacity: 0 }]).len == 0
}

fn test_svg_paint_culling_keeps_visible_fills_and_strokes() {
	base := msaa_test_svg_path(10, 30, 'svg')
	for alpha in [f64(1), 0.25, 0.00001] {
		fill := layout.PaintCommand{
			...base
			color: '#000'
			svg_data: &layout.PaintSVGPathData{ ...base.svg_data, fill_opacity: alpha }
		}
		stroke := layout.PaintCommand{
			...base
			color: '#000'
			stroke_color: '#f00'
			stroke_width: 2
			svg_data: &layout.PaintSVGPathData{
				...base.svg_data
				fill_opacity: 0
				stroke_opacity: alpha
			}
		}
		assert chromium_msaa_tiles([fill], 1, 256) == [0]
		assert chromium_msaa_tiles([stroke], 1, 256) == [0]
	}
}

fn test_transparent_fills_keep_gradient_and_pattern_stroke_triggers() {
	base := msaa_test_svg_path(10, 30, 'svg')
	for data in [
		&layout.PaintSVGPathData{
			...base.svg_data
			fill_opacity: 0
			svg_gradient_data: &layout.PaintSVGGradientData{
				stroke_linear_gradient: painting.SVGLinearGradientPaintStyle{}
			}
		},
		&layout.PaintSVGPathData{
			...base.svg_data
			fill_opacity: 0
			svg_gradient_data: &layout.PaintSVGGradientData{
				stroke_radial_gradient: painting.SVGRadialGradientPaintStyle{}
			}
		},
		&layout.PaintSVGPathData{
			...base.svg_data
			fill_opacity: 0
			stroke_pattern: &painting.SVGPatternPaintStyle{}
		},
	] {
		command := layout.PaintCommand{ ...base, stroke_width: 2, svg_data: data }
		assert chromium_msaa_tiles([command], 1, 256) == [0]
	}
}

fn test_transparent_svg_background_paths_do_not_trigger_document_msaa() {
	command, mut image := msaa_test_svg_background_with_opacity(10, 0)
	defer { image.finalize() }
	assert chromium_msaa_tiles([command], 1, 256) == []int{}
}

fn test_css_border_diagonal_miters_multisample_but_orthogonal_edges_do_not() {
	for index, points in [
		[f32(0), 10, 20, 1, 30, 20, 1, 30, 40, 1, 10, 40, 5, 0, 0],
		[f32(0), 10, 20, 1, 30, 21, 1, 30, 40, 5, 0, 0],
		[f32(0), 10, 20, 1, 30, 20, 1, 30, 40, 5, 0, 0],
		[f32(0), 10, 20, 3, 30, 40, 5, 0, 0],
	] {
		mut data := []f32{}
		for offset := 0; offset < points.len; offset += 3 {
			mut segment := []f32{len: layout.compatibility_clip_path_segment_stride}
			segment[0] = points[offset]
			segment[1] = points[offset + 1]
			segment[2] = points[offset + 2]
			if segment[0] == 3 {
				segment[3] = 20
				segment[4] = 20
				segment[5] = 30
				segment[6] = 40
			}
			data << segment
		}
		command := layout.PaintCommand{
			kind: 'draw_svg_path'
			force_dark_role: .border
			transform: [f64(1), 0, 0, 1, 0, 250]!
			svg_data: &layout.PaintSVGPathData{path_data: data}
		}
		assert chromium_border_has_diagonal_path(command) == (index != 0)
		assert chromium_msaa_tiles([command], 1, 256) == if index == 0 { []int{} } else { [1] }
	}
}

// Chromium's GPU tiles cover a quarter of the viewport plus two border texels,
// in multiples of 32 rows and at least 256 rows.
fn test_chromium_gpu_raster_tiles_follow_the_viewport_height() {
	assert chromium_gpu_raster_tile_rows(768) == 256
	assert chromium_gpu_raster_tile_rows(1536) == 416
	assert chromium_gpu_raster_tile_rows(2000) == 512
}

fn test_single_rounded_border_clips_multisample_their_transformed_tiles() {
	for side in ['top', 'right', 'bottom', 'left'] {
		command := layout.PaintCommand{
			kind: 'paint_rounded_border_' + side
			x: 20
			y: 250
			width: 100
			height: 20
			transform: [f64(1), 0, 0, 1, 0, 10]!
		}
		assert chromium_msaa_trigger_bounds(command)? == [f64(260), 280]
		assert chromium_msaa_tiles([command], 1, 256) == [1]
		assert chromium_msaa_tiles([command], 2, 256) == [2]
	}
}

// A skip-ink underline clipped around two or more glyphs, or an SVG path,
// multisamples every tile that rasterizes its rows. An orthogonal CSS border
// rectangle and an underline clipped once do not.
fn test_chromium_msaa_tiles_come_from_multiply_clipped_draws_and_svg_paths() {
	// 4chan's file link underline crosses two descenders at row 620, in the third
	// 256-row tile (rows 508 to 763).
	assert chromium_msaa_tiles([msaa_test_underline(620, 2)], 1, 256) == [2]
	assert chromium_msaa_tiles([msaa_test_underline(620, 1)], 1, 256) == []int{}
	assert chromium_msaa_tiles([msaa_test_svg_path(100, 110, 'svg')], 1, 256) == [0]
	assert chromium_msaa_tiles([msaa_test_svg_path(100, 110, 'border')], 1, 256) == []int{}
	// Rows 250 to 260 fall in tile 0 and in tile 1's top border rows.
	assert chromium_msaa_tiles([msaa_test_svg_path(250, 260, 'svg')], 1, 256) == [0, 1]
	// A Retina display rasterizes device rows.
	assert chromium_msaa_tiles([msaa_test_underline(140, 2)], 2, 256) == [1]
}

fn test_explicit_svg_ellipse_msaa_bounds_include_both_corners_and_transforms() {
	data := &layout.PaintSVGPathData{
		path_data: [f32(6), 10, 250, 20, 270, 0, 0, 0, 0, 0, 0, 0]
	}
	command := layout.PaintCommand{
		kind: 'draw_svg_path'
		force_dark_role: .svg
		svg_data: data
	}
	assert chromium_msaa_trigger_bounds(command)? == [f64(249), 271]
	assert chromium_msaa_tiles([command], 1, 256) == [0, 1]
	assert chromium_msaa_tiles([command], 2, 256) == [1, 2]
	stroked := layout.PaintCommand{ ...command, stroke_width: 2 }
	assert chromium_msaa_trigger_bounds(stroked)? == [f64(248), 272]
	rotated := layout.PaintCommand{
		...command
		transform: [f64(1), 0, 0, 1, 0, 300]!
		svg_data: &layout.PaintSVGPathData{
			...data
			path_transform: [f64(0), 1, -1, 0, 0, 0]!
		}
	}
	assert chromium_msaa_trigger_bounds(rotated)? == [f64(309), 321]
	assert chromium_msaa_tiles([rotated], 1, 256) == [1]
	assert command.svg().path_data == [f32(6), 10, 250, 20, 270, 0, 0, 0, 0, 0, 0, 0]
}

// Without the native GPU painter, the parts between the clip-outs are drawn as
// separate rectangles; a clip without antialiasing covers whole pixels.
fn test_clipped_out_rect_segments_cover_the_parts_between_clip_outs() {
	command := layout.PaintCommand{
		kind:      'fill_rect'
		x:         10
		width:     100
		clip_outs: [50.0, 0, 60.2, 2, 20.4, 0, 30.6, 2]
	}
	assert clipped_out_rect_segments(command) == [[10.0, 20.0], [31.0, 50.0], [60.0, 110.0]]
}

fn test_chromium_msaa_layer_tiles_keep_path_triggers_in_their_own_layer() {
	commands := [msaa_test_svg_path(242, 259, 'svg'), msaa_test_underline(80, 1),
		msaa_test_svg_path(570, 580, 'svg')]
	root := layout.ChromiumRasterLayer{
		command_indices: [0]
	}
	button := layout.ChromiumRasterLayer{
		bounds:          layout.LayoutRect{
			x:      936
			y:      67.5
			width:  68
			height: 33
		}
		command_indices: [1]
	}
	shifted := layout.ChromiumRasterLayer{
		bounds:          layout.LayoutRect{
			x:      20
			y:      400.5
			width:  100
			height: 200
		}
		command_indices: [2]
	}
	assert chromium_msaa_layer_tiles(commands, root, 1, 256, true) == [0, 1]
	assert chromium_msaa_layer_tiles(commands, button, 1, 256, false) == []int{}
	assert chromium_msaa_layer_tiles(commands, shifted, 1, 256, false) == [0]
	assert chromium_msaa_layer_tiles(commands, shifted, 2, 256, false) == [1]
	assert commands[2].svg().path_data[2] == 570
}

fn msaa_test_svg_background(y f64) (layout.PaintCommand,&dom.Document) {
 return msaa_test_svg_background_with_opacity(y, 1)
}

fn msaa_test_svg_background_with_opacity(y f64, alpha f64) (layout.PaintCommand,&dom.Document) {
 mut image:=dom.Document.create(dom.URL{value:'https://msaa.test/path.svg'})
 image.set_content_type('image/svg+xml')
 image.set_document_type(.xml)
 image.set_is_svg_image_document(true)
 image.set_font_rendering_policy(.chromium)
 html.parse_xml_document_source(image,'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><path fill-opacity="${alpha}" d="M0 0L64 64L0 64Z"/></svg>') or {panic(err)}
 command:=layout.PaintCommand{kind:'draw_background_image',transform:[f64(1),0,0,1,0,0]!,x:51,y:y,width:17.1,height:17.1,image_data:&layout.PaintImageData{
  background_svg_document:image,image_url:'https://msaa.test/path.svg',image_clip_x:51,image_clip_y:y,image_clip_width:17.1,image_clip_height:17.1,
  background_layer_data:&layout.PaintBackgroundLayerData{layer:css.BackgroundLayerData{repeat_x:.no_repeat,repeat_y:.no_repeat,size_x:css.LengthPercentageOrAuto.from_length(css.Length.make_px(17.1)),size_y:css.LengthPercentageOrAuto.from_length(css.Length.make_px(17.1))},resolution_context:css.LengthResolutionContext.default()}
 }}
 return command,image
}

fn test_svg_background_paths_trigger_msaa_in_the_parent_raster_layer() {
 command,mut image:=msaa_test_svg_background(242)
 defer {image.finalize()}
 ranges:=chromium_svg_background_msaa_ranges(command)
 assert ranges.len==1
 assert ranges[0][0]==242 && ranges[0][1]==259
 assert chromium_msaa_tiles([command],1,256)==[0,1]
 assert chromium_msaa_layer_tiles([command],layout.ChromiumRasterLayer{bounds:layout.LayoutRect{y:230},command_indices:[0]},1,256,false)==[0]
 assert image.cached_display_list()!=none
}

fn test_rounded_svg_backgrounds_use_parent_msaa_without_triggering_it() {
	command, mut image := msaa_test_svg_background(242)
	defer { image.finalize() }
	radius := layout.CornerRadius{8, 8}
	rounded := layout.PaintCommand{
		...command
		image_data: &layout.PaintImageData{
			...command.image_data
			image_clip_radii: layout.BoxRadii{
				top_left: radius
				top_right: radius
				bottom_right: radius
				bottom_left: radius
			}
		}
	}
	assert chromium_svg_background_outer_clip(&rounded) != none
	assert chromium_msaa_tiles([rounded], 1, 256).len == 0
	assert image.cached_display_list() == none
	// A separate path selects only its own tile, even when the rounded image
	// overlaps the boundary between that tile and the next one.
	neighbor := msaa_test_svg_path(60, 120, 'svg')
	assert chromium_msaa_tiles([rounded, neighbor], 1, 256) == [0]
	assert chromium_msaa_tiles([command, neighbor], 1, 256) == [0, 1]
}

fn test_svg_msaa_preparation_skips_distant_pictures_and_keeps_offscreen_tile_paths() {
 far,mut distant_image:=msaa_test_svg_background(3000)
 defer {distant_image.finalize()}
 viewport:=ChromiumMSAAViewport{scroll_y:0,height:768,fringe:256}
 assert distant_image.cached_display_list()==none
 assert chromium_msaa_triggers_for_viewport([far],viewport).len==0
 assert distant_image.cached_display_list()==none
 near,mut nearby_image:=msaa_test_svg_background(900)
 defer {nearby_image.finalize()}
 assert nearby_image.cached_display_list()==none
 triggers:=chromium_msaa_triggers_for_viewport([near],viewport)
 assert triggers.len==1 && triggers[0].top==900
 assert nearby_image.cached_display_list()!=none
 scrolled:=ChromiumMSAAViewport{scroll_y:2500,height:768,fringe:256}
 assert chromium_svg_background_intersects_raster_viewport(far,scrolled)
 fixed:=layout.PaintCommand{...far,fixed_to_viewport:true}
 assert !chromium_svg_background_intersects_raster_viewport(fixed,scrolled)
}

fn test_chromium_msaa_triggers_are_grouped_by_their_command_layer_in_order() {
	plan := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{},
			layout.ChromiumRasterLayer{}]
		command_layers: [0, 2, 2, 0]
	}
	triggers := [
		ChromiumMSAATrigger{3, 1, 2, 0, 1},
		ChromiumMSAATrigger{1, 3, 4, 0, 1},
		ChromiumMSAATrigger{0, 5, 6, 0, 1},
		ChromiumMSAATrigger{2, 7, 8, 0, 1},
		ChromiumMSAATrigger{9, 9, 10, 0, 1},
	]
	grouped := chromium_msaa_triggers_by_layer(triggers, plan)
	assert grouped.len == 3
	assert grouped[0].map(it.command_index) == [3, 0]
	assert grouped[1].len == 0
	assert grouped[2].map(it.command_index) == [1, 2]
}

fn test_msaa_preparation_reuses_layer_storage_and_clears_removed_triggers() {
	commands := [msaa_test_svg_path(250, 260, 'svg'), msaa_test_underline(620, 2)]
	plan := layout.ChromiumRasterLayerPlan{
		layers: [layout.ChromiumRasterLayer{bounds: layout.LayoutRect{width: 1024, height: 1000}},
			layout.ChromiumRasterLayer{bounds: layout.LayoutRect{width: 100, height: 700}}]
		command_layers: [0, 1]
	}
	legacy := layout.ChromiumRasterLayerPlan{
		layers: [layout.ChromiumRasterLayer{legacy_raster: true}]
		command_layers: [0, 0]
	}
	empty := []layout.PaintCommand{}
	mut storage := ChromiumMSAAStorage{}
	storage.update(commands, plan, 1024, 684, 0, 1)
	assert storage.tiles[0] == [i32(0), 1]
	assert storage.tiles[1] == [i32(2)]
	assert storage.grids[0].native_cells == storage.grids[0].cells.map(i32(it))
	assert storage.grids[1].columns > 0
	tiles := storage.tiles[1].data
	cells := storage.grids[1].native_cells.data
	// Warm up the shared legacy vector and then restore independent layers.
	storage.update(commands, legacy, 1024, 684, 0, 1)
	assert storage.tiles[0] == [i32(0), 1, 2]
	assert storage.grids[0].columns == 0
	storage.update(commands, plan, 1024, 684, 0, 1)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 100 {
		storage.update(empty, legacy, 1024, 684, 0, 1)
		assert storage.tiles[0].len == 0
		assert storage.grids[0].columns == 0
		storage.update(commands, plan, 1024, 684, 0, 1)
		assert storage.tiles[0].len == 2
		assert storage.tiles[1].len == 1
		assert storage.tiles[1][0] == 2
		assert storage.tiles[1].data == tiles
		assert storage.grids[1].native_cells.data == cells
		assert storage.grids[0].columns > 0
	}
	$if prealloc { assert platform.thread_arena_usage().used == before }
}

fn test_replaced_images_select_msaa_for_nonanalytic_rounded_clips() {
	for radii in [painting.BorderRadiusData{4.5, 10}, painting.BorderRadiusData{4.5, 4.5},
		painting.BorderRadiusData{0.25, 10}, painting.BorderRadiusData{}] {
		command := layout.PaintCommand{
			kind: 'draw_replaced_image'
			image_paintable: &painting.ImagePaintable{
				image_rect: painting.Rect{16, 260, 9, 20}
				border_radii: painting.BorderRadiiData{radii, radii, radii, radii}
			}
		}
		expected := if radii == painting.BorderRadiusData{4.5, 10} { [1] } else { []int{} }
		assert chromium_msaa_tiles([command], 1, 256) == expected
		shifted := layout.PaintCommand{...command, transform: [f64(1), 0, 0, 1, 0, 254]!}
		assert chromium_msaa_tiles([shifted], 1, 256) == if expected.len == 1 { [2] } else { []int{} }
	}
}
