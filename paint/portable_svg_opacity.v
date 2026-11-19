module main

import layout
import math
import os
import painting

const disable_portable_svg_opacity = os.getenv('VOX_DISABLE_PORTABLE_SVG_OPACITY') == '1'
const portable_svg_opacity_diagnostics = os.getenv('VOX_PORTABLE_SVG_OPACITY_DIAGNOSTICS') == '1'

// Replay only a complete scope with a rectangular clip shared by its paths.
// A common clip lets the raster surface itself clip every path.
fn portable_svg_opacity_end(commands []layout.PaintCommand, start int, layer &layout.PaintVisualLayer) ?int {
	opening := &commands[start]
	if !portable_svg_group_clip_supported(opening, none) || start + 2 >= commands.len {
		return none
	}
	first := &commands[start + 1]
	if commands[start + 2].kind != 'draw_svg_path' {
		// A single path still needs isolation when it paints a fill and a stroke.
		if !portable_svg_group_has_stroke(first)
			|| (first.color == '' && first.fill_linear_gradient() == none
			&& first.fill_radial_gradient() == none) {
			return none
		}
	}
	limit := math.min(commands.len, start + portable_svg_group_max_paths + 2)
	for index in start + 1 .. limit {
		command := &commands[index]
		if command.kind == 'end_css_effect_layer' {
			closing := command.visual_layer_data or { return none }
			if closing.kind == layer.kind && closing.scope_id == layer.scope_id { return index }
			return none
		}
		if !portable_svg_group_path_supported(command, first, layer.opacity, none) { return none }
	}
	return none
}

fn (mut app BrowserApp) draw_portable_svg_opacity_group(commands []layout.PaintCommand,
	start int, page_x f32, page_y f32, outer_viewport ?painting.Rect) int {
	if disable_portable_svg_opacity || !app.portable_svg_group_allowed() { return start }
	opening := &commands[start]
	layer := normal_opacity_paint_layer(opening) or { return start }
	end := portable_svg_opacity_end(commands, start, layer) or { return start }
	scale := f64(app.ctx.scale)
	mut viewport := outer_viewport or { app.portable_device_viewport(page_y) }
	if clip := opening.effect_ancestor_clip() {
		viewport = viewport.intersection(portable_svg_device_clip(clip, page_x, page_y, scale))
	}
	key := app.portable_svg_group_key(commands, start, viewport, page_x, page_y)
	alpha := u8(math.round(layer.opacity * 255))
	if app.draw_cached_portable_svg_group(key, alpha) { return end + 1 }
	image := app.raster_portable_svg_group(commands[start + 1..end], viewport, page_x, page_y,
		layer.opacity) or { return start }
	if image.bounds.is_empty() { return end + 1 }
	app.draw_portable_svg_group_image(image, alpha, key)
	if portable_svg_opacity_diagnostics {
		eprintln('VOX_SVG_OPACITY paths=${image.paths} texture=${image.bounds.width}x${image.bounds.height}')
	}
	return end + 1
}
