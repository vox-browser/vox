module main

import gg
import layout
import painting

fn single_svg_pattern_image(style &painting.SVGPatternPaintStyle) ?painting.SVGMaskPaintOperation {
	if (style.pattern_transform or { painting.Affine{} }) != painting.Affine{} {
		return none
	}
	tile := style.tile_rect
	if tile.width <= 0 || tile.height <= 0 || tile.width > 8192 || tile.height > 8192
		|| tile.width * tile.height > 8 * 1024 * 1024 {
		return none
	}
	list := style.tile_display_list or { return none }
	if list.operations.len != 1 || list.operations[0].kind != .image
		|| list.operations[0].image_url == '' {
		return none
	}
	return list.operations[0]
}

fn C.native_draw_svg_image_pattern(&gg.Image, &f32, int, int, &f32, &f32, &f32, &f32,
	&f32, f32, f32, f32, f32, f32, f32, int) int

fn (mut app BrowserApp) draw_svg_image_pattern(path []f32, even_odd bool, matrix [6]f64,
	page_x f32, page_y f32, scroll_y f32, canvas_height f32,
	style &painting.SVGPatternPaintStyle, opacity f64) bool {
	$if macos {
		operation := single_svg_pattern_image(style) or { return false }
		image := app.background_image(operation.image_url) or { return false }
		replay := resolved_svg_operation_image(operation.image_paintable, operation.image_rect,
			operation.image_position_x, operation.image_position_y, operation.image_rendering,
			image.width, image.height) or { return false }
		outer := [f32(matrix[0]), f32(matrix[1]), f32(matrix[2]), f32(matrix[3]), f32(matrix[4]), f32(matrix[5])]!
		m := operation.transform
		inner := [f32(m.a), f32(m.b), f32(m.c), f32(m.d), f32(m.e), f32(m.f)]!
		t := style.tile_rect
		tile := [f32(t.x), f32(t.y), f32(t.width), f32(t.height)]!
		d := replay.destination
		destination := [f32(d.x), f32(d.y), f32(d.width), f32(d.height)]!
		c := replay.clip
		clip := [f32(c.x), f32(c.y), f32(c.width), f32(c.height)]!
		app.set_chromium_image_resource_identity(operation.image_url)
		defer { clear_chromium_image_resource_identity() }
		return C.native_draw_svg_image_pattern(image, path.data, path.len / layout.compatibility_clip_path_segment_stride, int(even_odd),
			&outer[0], &inner[0], &tile[0], &destination[0], &clip[0], page_x, page_y,
			scroll_y, f32(app.ctx.width), canvas_height, f32(opacity), int(replay.scaling == .nearest_neighbor)) != 0
	}
	return false
}
