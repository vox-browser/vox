module main

import layout

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

// Chromium's GPU tiles cover a quarter of the viewport plus two border texels,
// in multiples of 32 rows and at least 256 rows.
fn test_chromium_gpu_raster_tiles_follow_the_viewport_height() {
	assert chromium_gpu_raster_tile_rows(768) == 256
	assert chromium_gpu_raster_tile_rows(1536) == 416
	assert chromium_gpu_raster_tile_rows(2000) == 512
}

// A skip-ink underline clipped around two or more glyphs, or an SVG path,
// multisamples every tile that rasterizes its rows. CSS borders, which Chromium
// paints as rectangles, and an underline clipped once do not.
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
