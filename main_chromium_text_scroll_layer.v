module main

import layout

// Scrolling, fixed and sticky text rasters are transparent before the compositor
// blends them over their parent. Painting glyphs directly over that parent's pixels skips
// the intermediate premultiplied rounding. Keep this slice contiguous and
// free of nested effects, resources, and child-layer gaps.
fn chromium_text_scroll_layer_supported(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan, index int) bool {
	if index <= 0 || index >= plan.layers.len || plan.command_layers.len != commands.len {
		return false
	}
	layer := plan.layers[index]
	if layer.legacy_raster || (!layer.scroll_contents && !layer.composited_contents)
		|| layer.command_indices.len == 0 {
		return false
	}
	first := layer.command_indices.first()
	last := layer.command_indices.last()
	if first < 0 || last >= commands.len || last - first + 1 != layer.command_indices.len
		|| (first > 0 && plan.command_layers[first - 1] == index)
		|| (last + 1 < commands.len && plan.command_layers[last + 1] == index) {
		return false
	}
	for position, command_index in layer.command_indices {
		if command_index != first + position || plan.command_layers[command_index] != index {
			return false
		}
		command := unsafe { &commands[command_index] }
		if command.kind != 'draw_text' || command.opacity != 1 || command.group_opacity != 1
			|| command.blur != 0 || command.outer_shadow || command.clip_outs.len > 0
			|| command.scrollbar_axis != '' || !chromium_shared_recording_clips_supported(command) {
			return false
		}
	}
	return true
}

fn (mut app BrowserApp) begin_chromium_text_scroll_layer(index int) bool {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium
			|| (!chromium_text_scroll_layer_supported(app.paint_commands, app.chromium_raster_plan, index)
				&& !chromium_svg_compositor_layer_supported_for_viewport(app.paint_commands,
					app.chromium_raster_plan, index,
					layout.LayoutRect{0, app.scroll_y, app.viewport_width, app.viewport_height})) {
			return false
		}
		// Install a transparent destination before enabling picture recording;
		// an ordinary full-opacity CSS picture can use the parent's backdrop.
		C.native_set_chromium_layer_shared_recording(0)
		C.native_begin_css_effect_layer(1, 0)
		C.native_set_chromium_layer_shared_recording(1)
		background := app.chromium_raster_plan.layers[index].scroll_background_command
		if background >= 0 && background < app.paint_commands.len
			&& app.chromium_raster_plan.layers[index].command_indices.any(app.paint_commands[it].kind == 'fill_gradient') {
			app.draw_command(app.paint_commands[background], 0, app.page_top(), app.ctx.height)
		}
		return true
	}
	return false
}

fn end_chromium_text_scroll_layer() {
	$if macos {
		C.native_end_css_effect_layer()
		C.native_set_chromium_layer_shared_recording(0)
	}
}
