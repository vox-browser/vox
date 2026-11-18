module main

import gg
import ggshape
import layout
import math
import os

const shadowed_png_text_diagnostic = os.getenv('VOX_DIAGNOSTIC_SHADOWED_PNG_TEXT') == '1'

// The following leaf must be ordinary root text. Its own clips or effects
// cannot become a clip of the preceding image and shadow.
fn shadowed_png_text_supported(commands []layout.PaintCommand, layers []int, index int) bool {
	if !shadowed_png_group_eligible_with_scale(commands, layers, index, true)
		|| index + 2 >= commands.len { return false }
	c := &commands[index + 2]
	return layers[index + 2] == 0 && c.kind == 'draw_text' && c.glyph_run != none
		&& c.glyph_orientation == .horizontal && c.opacity == 1 && c.group_opacity == 1
		&& c.blur == 0 && !c.outer_shadow && !c.has_clip && c.clip_list == unsafe { nil }
		&& c.recording_clip == none && c.clip_outs.len == 0 && c.visual_layer_data == none
		&& c.fixed_to_viewport == commands[index + 1].fixed_to_viewport
		&& normalized_paint_transform(c.transform) == normalized_paint_transform(commands[index + 1].transform)
}

fn (mut app BrowserApp) draw_shadowed_png_text(index int, page_y f32, decoded &gg.Image,
	natural_width int, natural_height int, gpu_mips bool, image SampledPNGGeometry,
	shadow C.VoxGraphiteShape) int {
	if !shadowed_png_text_diagnostic || !app.ctx.native_rendering || app.page_zoom != 1
		|| app.scroll_y != 0 || document_png_space_is_p3() == 0
		|| C.native_raster_device_pixel_ratio() != 1 {
		return index
	}
	if !shadowed_png_text_supported(app.paint_commands, app.chromium_raster_plan.command_layers, index) {
		if index + 2 < app.paint_commands.len {
			c := &app.paint_commands[index + 2]
			eprintln('VOX_SHADOWED_PNG_TEXT decline index=${index} kind=${c.kind} clip=${c.has_clip}/${c.clip_list != unsafe { nil }}')
		}
		return index
	}
	c := &app.paint_commands[index + 2]
	ink := rounded_outer_text_ink(c) or { return index }
	if ink.x >= image.x + image.width || ink.x + ink.width <= image.x
		|| ink.y >= image.y + image.height || ink.y + ink.height <= image.y {
		return index
	}
	left := math.min(ink.x, f64(math.min(image.x, shadow.rect[0])))
	top := math.min(ink.y, f64(math.min(image.y, shadow.rect[1]))) + page_y
	right := math.max(ink.x + ink.width, f64(math.max(image.x + image.width, shadow.rect[0] + shadow.rect[2])))
	bottom := math.max(ink.y + ink.height, f64(math.max(image.y + image.height, shadow.rect[1] + shadow.rect[3]))) + page_y
	mut geometry := [7]i32{}
	mut scale := f32(1)
	if C.native_document_text_raster_begin(f32(left), f32(top), f32(right), f32(bottom),
		f32(app.ctx.width), f32(app.ctx.height), 16, &geometry[0], &scale) != 1
		|| scale != 1 || geometry[4] == 0 {
		return index
	}
	width, height := int(geometry[2]), int(geometry[3])
	if width <= 0 || height <= 0 || width > 2048 || height > 256 { return index }
	glyph := elliptical_text_coverage(c, geometry, page_y) or {
		eprintln('VOX_SHADOWED_PNG_TEXT decline index=${index} mask')
		return index
	}
	mut pixels := []u8{len: width * height * 4}
	if C.native_document_text_raster_read_backdrop(pixels.data, geometry[0], geometry[1],
		geometry[2], geometry[3], scale) == 0 { return index }
	mut clipping := image.clip
	clipping[0] -= f32(geometry[0])
	clipping[1] += page_y - f32(geometry[1])
	mut local_shadow := shadow
	local_shadow.matrix = [f32(1), 0, -f32(geometry[0]), 0, 1, page_y - f32(geometry[1]), 0, 0, 1]!
	paint := ggshape.GlyphCoverage{
		pixels: glyph.pixels
		color: document_color_to_p3_for_blending(glyph.color)
	}
	packed := unsafe { (&u8(decoded.data)).vbytes(decoded.width * decoded.height * 4) }
	swap_document_raster_channels(pixels.data, geometry[2], geometry[3], geometry[2] * 4)
	drawn := draw_document_sampled_image_tiles_with_decoration(pixels.data, geometry[2], geometry[3],
		geometry[2] * 4, 1, int(geometry[0]), int(f32(geometry[1]) - page_y), packed,
		decoded.width, decoded.height, image.x - f32(geometry[0]), page_y + image.y - f32(geometry[1]),
		image.width, image.height, natural_width, natural_height, clipping, .rgba_p3_shadow,
		gpu_mips, DocumentBitmapDecoration{ shadow: document_p3_shape(local_shadow), glyphs: [paint] })
	if drawn == 0 { return index }
	swap_document_raster_channels(pixels.data, geometry[2], geometry[3], geometry[2] * 4)
	if C.native_document_text_raster_finish(pixels.data, geometry[0], geometry[1], geometry[2], geometry[3],
		geometry[5], geometry[6], f32(app.ctx.height), 1) == 0 { return index }
	eprintln('VOX_SHADOWED_PNG_TEXT index=${index} text=${index + 2} geometry=${geometry[..]}')
	return index + 3
}
