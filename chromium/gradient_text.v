module main

import layout

// Both the gradient and every glyph must remain represented until DstIn.
// Mixed backgrounds, fallback text and nested effects use the bitmap path.
fn chromium_gradient_text_input_supported(commands []layout.PaintCommand, start int) bool {
	if start < 0 || start >= commands.len { return false }
	opening := commands[start]
	if opening.kind != 'begin_background_text_clip' || opening.text_clip_runs.len == 0 {
		return false
	}
	for run in opening.text_clip_runs {
		glyphs := run.glyph_run or { return false }
		if run.glyph_orientation != .horizontal || glyphs.face() == .emoji
			|| glyphs.glyph_indices().len == 0
			|| glyphs.glyph_positions().len != glyphs.glyph_indices().len * 2 {
			return false
		}
	}
	if start + 2 >= commands.len || commands[start + 2].kind != 'end_background_text_clip' {
		return false
	}
	command := unsafe { &commands[start + 1] }
	if command.kind != 'fill_gradient' || command.clip_outs.len != 0
		|| !chromium_shared_recording_clips_supported(command) {
		return false
	}
	gradient := command.gradient or { return false }
	if !chromium_gradient_has_gpu_geometry(gradient)
		|| chromium_gradient_stop_analysis(gradient) == none {
		return false
	}
	return command.image_data == unsafe { nil }
		|| command.image_data.background_blend_mode == .normal
}
