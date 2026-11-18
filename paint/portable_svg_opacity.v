module main

import cpuraster
import gg
import layout
import math
import os
import painting

const disable_portable_svg_opacity = os.getenv('VOX_DISABLE_PORTABLE_SVG_OPACITY') == '1'
const portable_svg_opacity_diagnostics = os.getenv('VOX_PORTABLE_SVG_OPACITY_DIAGNOSTICS') == '1'
const portable_svg_opacity_max_paths = 128
const portable_svg_opacity_max_pixels = 4 * 1024 * 1024

fn portable_svg_opacity_clip_supported(command &layout.PaintCommand) bool {
	if !chromium_shared_recording_clips_supported(command) || command.clip_outs.len > 0
		|| command.recording_clip != none {
		return false
	}
	if command.clip_list != unsafe { nil } {
		for clip in command.clip_list.items {
			if clip.transform[1] != 0 || clip.transform[2] != 0 || clip.corner_radii != layout.BoxRadii{} {
				return false
			}
		}
	}
	return true
}

// Replay only a complete scope with a rectangular clip shared by its paths.
// A common clip lets the raster surface itself clip every path.
fn portable_svg_opacity_end(commands []layout.PaintCommand, start int, layer &layout.PaintVisualLayer) ?int {
	opening := &commands[start]
	if !portable_svg_opacity_clip_supported(opening) || start + 3 >= commands.len
		|| commands[start + 2].kind != 'draw_svg_path' {
		return none
	}
	first := &commands[start + 1]
	limit := math.min(commands.len, start + portable_svg_opacity_max_paths + 2)
	for index in start + 1 .. limit {
		command := &commands[index]
		if command.kind == 'end_css_effect_layer' {
			closing := command.visual_layer_data or { return none }
			if closing.kind == layer.kind && closing.scope_id == layer.scope_id { return index }
			return none
		}
		if command.kind != 'draw_svg_path' || command.svg_data == unsafe { nil }
			|| command.color == '' || (command.stroke_color != '' && command.stroke_width > 0)
			|| command.svg_data.path_data.len < layout.compatibility_clip_path_segment_stride
			|| command.svg_data.svg_gradient_data != none || command.svg_data.fill_pattern != none
			|| command.blur != 0 || command.outer_shadow || command.scrollbar_axis != ''
			|| f32(command.group_opacity) != f32(layer.opacity)
			|| command.has_clip != first.has_clip || command.clip_x != first.clip_x
			|| command.clip_y != first.clip_y || command.clip_width != first.clip_width
			|| command.clip_height != first.clip_height || !portable_svg_opacity_clip_supported(command) {
			return none
		}
	}
	return none
}

struct PortableSVGOpacityPath {
	path      cpuraster.Path
	transform painting.Affine
	color     u32
}

fn (mut app BrowserApp) draw_portable_svg_opacity_group(commands []layout.PaintCommand,
	start int, page_x f32, page_y f32) int {
	if disable_portable_svg_opacity || app.ctx.native_rendering || app.page_zoom != 1
		|| app.paint_effect_depth != 0 || app.paint_svg_mask_depth != 0
		|| app.portable_background_text_clip != none {
		return start
	}
	opening := &commands[start]
	layer := normal_opacity_paint_layer(opening) or { return start }
	end := portable_svg_opacity_end(commands, start, layer) or { return start }
	scale := f64(app.ctx.scale)
	mut viewport := app.portable_device_viewport(page_y)
	if clip := opening.effect_ancestor_clip() {
		viewport = viewport.intersection(portable_svg_device_clip(clip, page_x, page_y, scale))
	}
	first := &commands[start + 1]
	if first.has_clip {
		viewport = viewport.intersection(portable_svg_device_clip(layout.LayoutRect{first.clip_x,
			first.clip_y, first.clip_width, first.clip_height}, page_x, page_y, scale))
	}
	if viewport.is_empty() { return end + 1 }
	mut ink := painting.Rect{}
	mut path_pixels := 0
	mut paths := []PortableSVGOpacityPath{cap: end - start - 1}
	for index in start + 1 .. end {
		command := &commands[index]
		data := command.svg_data
		path := cpuraster.canvas_path(data.path_data, data.fill_even_odd)
		transform := portable_device_transform(multiply_paint_transforms(command.transform,
			data.path_transform), page_x, page_y, scale)
		bounds := portable_svg_path_bounds(path, transform, viewport) or { return start }
		if bounds.is_empty() { continue }
		color := app.paint_colors.color_with_retained(command.color,
			command.opacity / layer.opacity * data.fill_opacity, command.retained_svg_fill_color())
		if color.a == 0 { continue }
		ink = ink.united(bounds)
		path_bounds := portable_pixel_bounds(bounds)
		path_pixels += path_bounds.width * path_bounds.height
		paths << PortableSVGOpacityPath{path, transform, portable_svg_argb(color)}
	}
	if paths.len == 0 { return end + 1 }
	bounds := portable_pixel_bounds(ink)
	// Leave widely separated paths on the leaf renderer instead of uploading
	// a large area of transparent pixels between them.
	pixel_count := bounds.width * bounds.height
	if pixel_count > portable_svg_opacity_max_pixels || pixel_count > path_pixels + 16384 { return start }
	pitch := bounds.width * 4
	mut surface := []u8{len: pitch * bounds.height}
	for path in paths {
		if !cpuraster.fill_canvas_path(mut surface, bounds.width, bounds.height, pitch, 2,
			path.path, portable_svg_surface_matrix(path.transform, bounds), path.color, none, 1,
			.src_over, 0, [], none) {
			return start
		}
	}
	mut pixels := []u8{len: surface.len}
	if !cpuraster.read_pixels(surface, bounds.width, bounds.height, pitch, 2, mut pixels,
		bounds.width, bounds.height, pitch, 0, 0) {
		return start
	}
	// GG applies group alpha to the resolved source-over result in one draw.
	app.draw_portable_raster_texture_with_alpha(gg.Rect{f32(f64(bounds.x) / scale),
		f32(f64(bounds.y) / scale), f32(f64(bounds.width) / scale), f32(f64(bounds.height) / scale)},
		bounds.width, bounds.height, pixels, u8(math.round(layer.opacity * 255)))
	if portable_svg_opacity_diagnostics {
		eprintln('VOX_SVG_OPACITY paths=${paths.len} texture=${bounds.width}x${bounds.height}')
	}
	return end + 1
}

fn portable_svg_device_clip(clip layout.LayoutRect, page_x f32, page_y f32, scale f64) painting.Rect {
	if clip.width <= 0 || clip.height <= 0 { return painting.Rect{} }
	left := math.floor((clip.x + f64(page_x)) * scale)
	top := math.floor((clip.y + f64(page_y)) * scale)
	right := math.ceil((clip.x + clip.width + f64(page_x)) * scale)
	bottom := math.ceil((clip.y + clip.height + f64(page_y)) * scale)
	return painting.Rect{left, top, right - left, bottom - top}
}
