module main

import layout
import math

// Different corner radii use a rounded fill rather than the scalar-radius
// underlay. Keep that fill and its uniform border in the same root render pass.
fn chromium_rounded_background_pair_end(commands []layout.PaintCommand, layers []int, index int) int {
	partial_end := chromium_partial_decoration_end(commands, layers, index)
	if partial_end > index { return partial_end }
	if index < 0 || index + 1 >= commands.len || layers.len != commands.len { return index }
	background := unsafe { &commands[index] }
	border := unsafe { &commands[index + 1] }
	if background.kind !in ['fill_rect', 'fill_rounded_rect']
		|| border.kind != 'paint_uniform_border' || border.stroke_width <= 0
		|| !background.shares_paint_box_with(border)
		|| normalized_paint_transform(background.transform) != normalized_paint_transform(border.transform)
		|| [background.x, background.y, background.width, background.height] !=
			[border.x, border.y, border.width, border.height] { return index }
	for i in index .. index + 2 {
		command := unsafe { &commands[i] }
		if layers[i] != 0 || command.opacity != 1 || command.outer_shadow || command.blur != 0
			|| command.clip_outs.len > 0 || !chromium_shared_recording_clips_supported(command)
			|| command.width <= 0 || command.height <= 0 { return index }
		for value in [command.x, command.y, command.width, command.height, command.stroke_width] {
			if math.is_nan(value) || math.is_inf(value, 0) { return index }
		}
		for value in normalized_paint_transform(command.transform) {
			if math.is_nan(value) || math.is_inf(value, 0) { return index }
		}
	}
	mut rounded := false
	back_radii := background.corner_radii
	border_radii := border.corner_radii
	background_corners := [back_radii.top_left, back_radii.top_right,
		back_radii.bottom_right, back_radii.bottom_left]
	border_corners := [border_radii.top_left, border_radii.top_right,
		border_radii.bottom_right, border_radii.bottom_left]
	for i, corner in border_corners {
		if math.is_nan(corner.x) || math.is_inf(corner.x, 0) || corner.x < 0
			|| corner.x != corner.y { return index }
		if background.kind == 'fill_rect' {
			if corner.x != background.radius { return index }
		} else if corner != background_corners[i] { return index }
		rounded = rounded || corner.x > 0
	}
	return if rounded { index + 2 } else { index }
}

// Reserve only rows these leaves can touch. Native recording still uses the
// full raster grid, and adds its usual two-pixel fringe before the final ink
// crop. Unknown bounds preserve the existing full-viewport transaction.
fn chromium_rounded_pair_recording_bounds(commands []layout.PaintCommand, start int, end int,
    page_y f64, viewport_width f64, viewport_height f64) ?layout.LayoutRect {
    if start < 0 || end <= start || end > commands.len || viewport_width <= 4
        || viewport_height <= 4 { return none }
    for value in [page_y, viewport_width, viewport_height] {
        if math.is_nan(value) || math.is_inf(value, 0) { return none }
    }
    mut left := math.inf(1)
    mut top := math.inf(1)
    mut right := math.inf(-1)
    mut bottom := math.inf(-1)
    for i in start .. end {
        if math.is_nan(commands[i].stroke_width) || math.is_inf(commands[i].stroke_width, 0) {
            return none
        }
        ink := chromium_partial_gap_ink(unsafe { &commands[i] }) or { return none }
        left = math.min(left, ink.x)
        top = math.min(top, ink.y)
        right = math.max(right, ink.x + ink.width)
        bottom = math.max(bottom, ink.y + ink.height)
    }
    // Commands already include their viewport scroll transform. Only browser
    // chrome shifts the final canvas rows. The extra pixel covers float32
    // native geometry rounding within paint_leaf_native_ink_bounds' guard.
    left = math.max(2.0, left - 1)
    top = math.max(page_y + 2, page_y + top - 1)
    right = math.min(viewport_width - 2, right + 1)
    bottom = math.min(page_y + viewport_height - 2, page_y + bottom + 1)
    for value in [left, top, right, bottom] {
        if math.is_nan(value) || math.is_inf(value, 0) { return none }
    }
    if right <= left || bottom <= top { return none }
    return layout.LayoutRect{x: left, y: top, width: right - left, height: bottom - top}
}

fn (mut app BrowserApp) draw_chromium_rounded_background_pair(index int, page_y f32, window_height int) int {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium
			|| app.viewport_width <= 4 || app.viewport_height <= 4 { return index }
		end := chromium_rounded_background_pair_end(app.paint_commands,
			app.chromium_raster_plan.command_layers, index)
		if end == index { return index }
		app.flush_rounded_rect_underlay(0, page_y, window_height)
        bounds := chromium_rounded_pair_recording_bounds(app.paint_commands, index, end,
            page_y, app.viewport_width, app.viewport_height) or {
            layout.LayoutRect{x: 2, y: page_y + 2,
                width: app.viewport_width - 4, height: app.viewport_height - 4}
        }
		if C.native_begin_deferred_inset_decorations(f32(bounds.x), f32(bounds.y),
			f32(bounds.width), f32(bounds.height),
			f32(app.ctx.width), f32(app.ctx.height), page_y, 0) == 0 { return index }
		for i in index .. end {
			if app.chromium_raster_plan.command_layers[i] < 0 { continue }
			app.draw_command(app.paint_commands[i], 0, page_y, window_height)
		}
		app.flush_rounded_rect_underlay(0, page_y, window_height)
		if C.native_end_deferred_inset_decorations() == 0 {
			// The native transaction restores the prefix before retrying.
			for i in index .. end { app.draw_command(app.paint_commands[i], 0, page_y, window_height) }
			app.flush_rounded_rect_underlay(0, page_y, window_height)
		}
		return end
	}
	return index
}
