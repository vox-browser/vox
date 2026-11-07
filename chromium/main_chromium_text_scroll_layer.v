module main

import layout

fn C.native_set_chromium_opaque_layer_continuation(i32)

// Scrolling, fixed and sticky text rasters are transparent before the compositor
// blends them over their parent. Painting glyphs directly over that parent's pixels skips
// the intermediate premultiplied rounding. Keep this slice contiguous and
// free of nested effects, resources, and child-layer gaps. Solid underlines
// belong to the same transparent raster as their glyphs, including skip-ink.
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
	mut has_text := false
	for position, command_index in layer.command_indices {
		if command_index != first + position || plan.command_layers[command_index] != index {
			return false
		}
		command := unsafe { &commands[command_index] }
		decoration := command.kind == 'fill_rect' && command.antialiased_rect
			&& command.radius == 0 && command.corner_radii == layout.BoxRadii{}
		if (command.kind != 'draw_text' && !decoration)
			|| command.opacity != 1 || command.group_opacity != 1
			|| command.blur != 0 || command.outer_shadow
			|| !chromium_svg_compositor_clip_outs_supported(command)
			|| command.scrollbar_axis != '' || !chromium_shared_recording_clips_supported(command) {
			return false
		}
		has_text = has_text || command.kind == 'draw_text'
	}
	return has_text
}

fn (mut app BrowserApp) begin_chromium_text_scroll_layer(index int, command_index int) bool {
	$if macos {
		if !app.ctx.native_rendering || app.page_zoom != 1 || app.document == unsafe { nil }
			|| app.document.font_rendering_policy() != .chromium {
			return false
		}
		if chromium_direct_image_layer_supported(app.paint_commands, app.chromium_raster_plan, index) {
			return false
		}
		recorded := chromium_text_scroll_layer_supported(app.paint_commands, app.chromium_raster_plan, index)
			|| chromium_svg_compositor_layer_supported_for_viewport(app.paint_commands,
				app.chromium_raster_plan, index,
				layout.LayoutRect{0, app.scroll_y, app.viewport_width, app.viewport_height})
		if !recorded && !chromium_leaf_compositor_layer_supported(app.paint_commands,
			app.chromium_raster_plan, index) {
			return false
		}
		// New slices start transparent. An opaque continuation can instead
		// retain the native parent's prefix in its GPU picture.
		opaque_effect := recorded && chromium_compositor_opaque_effect_resume(app.paint_commands,
			app.chromium_raster_plan, index, command_index)
		resume := opaque_effect || (recorded && chromium_compositor_opaque_mask_resume(app.paint_commands,
			app.chromium_raster_plan, index, command_index))
		C.native_set_chromium_opaque_layer_continuation(i32(resume))
		C.native_set_chromium_layer_shared_recording(i32(resume))
		C.native_begin_css_effect_layer(1, 0)
		C.native_set_chromium_layer_shared_recording(i32(recorded
            && C.native_gpu_canvas_nested_layer_active() == 0))
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
