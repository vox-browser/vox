module main

import layout

// A single generated gradient can retain its drawing commands through blur.
// Other inputs keep the bitmap filter path until every operation is recorded.
fn chromium_gradient_blur_input_supported(commands []layout.PaintCommand, start int) bool {
	if start < 0 || start >= commands.len { return false }
	opening := commands[start]
	if opening.kind != 'begin_css_filter_layer' { return false }
	layer := opening.visual_layer_data or { return false }
	filter := layer.filter or { return false }
	if filter.operations.len != 1 || filter.operations[0].kind != 'blur'
		|| filter.operations[0].first <= 0 || filter.nodes.len > 0 {
		return false
	}
	mut gradients := 0
	for index in start + 1 .. commands.len {
		command := unsafe { &commands[index] }
		if command.kind == 'end_css_filter_layer' {
			end := command.visual_layer_data or { return false }
			return gradients == 1 && end.scope_id == layer.scope_id
		}
		if command.kind != 'fill_gradient' || command.clip_outs.len != 0
			|| !chromium_shared_recording_clips_supported(command) {
			return false
		}
		gradient := command.gradient or { return false }
		if !chromium_gradient_has_gpu_geometry(gradient)
			|| chromium_gradient_stop_analysis(gradient) == none {
			return false
		}
		if command.image_data != unsafe { nil } {
			if command.image_data.background_blend_mode != .normal { return false }
		}
		gradients++
		if gradients > 1 { return false }
	}
	return false
}
