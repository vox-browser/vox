module html

import dom

fn test_save_and_restore_round_trip() {
	mut state := &CanvasState{}
	state.drawing_state.global_alpha = 0.5
	state.save()
	assert state.drawing_state_stack_depth() == 1
	// Mutate after saving.
	state.drawing_state.global_alpha = 0.25
	state.restore()
	// The saved value is restored, and the stack is popped.
	assert state.drawing_state.global_alpha == 0.5
	assert state.drawing_state_stack_depth() == 0
}

fn test_restore_with_empty_stack_is_noop() {
	mut state := &CanvasState{}
	state.drawing_state.line_width = 7.0
	state.restore()
	assert state.drawing_state.line_width == 7.0
	assert state.drawing_state_stack_depth() == 0
}

fn test_nested_save_restore() {
	mut state := &CanvasState{}
	state.drawing_state.line_width = 1.0
	state.save()
	state.drawing_state.line_width = 2.0
	state.save()
	state.drawing_state.line_width = 3.0
	assert state.drawing_state_stack_depth() == 2
	state.restore()
	assert state.drawing_state.line_width == 2.0
	state.restore()
	assert state.drawing_state.line_width == 1.0
}

fn test_reset_clears_stack_and_state() {
	mut state := &CanvasState{}
	state.drawing_state.global_alpha = 0.1
	state.save()
	state.save()
	state.reset()
	assert state.drawing_state_stack_depth() == 0
	// Drawing state is back to defaults.
	assert state.drawing_state.global_alpha == 1.0
	assert state.drawing_state.line_width == 1.0
	assert state.drawing_state.line_cap == .butt
	assert state.drawing_state.text_baseline == .alphabetic
}

fn test_defaults() {
	state := &CanvasState{}
	assert state.is_context_lost() == false
	ds := state.drawing_state
	assert ds.fill_style.as_color()? == dom.Color{0, 0, 0, 255}
	assert ds.current_compositing_and_blending_operator == .source_over
	assert ds.transform.a == 1.0
	assert ds.transform.d == 1.0
}

fn test_fill_or_stroke_style() {
	red := dom.Color{255, 0, 0, 255}
	color_style := FillOrStrokeStyle.from_color(red)
	assert color_style.as_color()? == red

	gradient := CanvasGradient.create_linear(0, 0, 10, 10)
	gradient_style := FillOrStrokeStyle.from_gradient(gradient)
	assert gradient_style.as_color() == none
	// A non-color style falls back to black.
	assert gradient_style.to_color_but_fixme_should_accept_any_paint_style() == canvas_color_black()
}

fn test_context_lost_flag() {
	mut state := &CanvasState{}
	assert state.is_context_lost() == false
	state.set_context_lost(true)
	assert state.is_context_lost() == true
}
