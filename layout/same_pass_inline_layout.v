module layout

import os

const disable_same_pass_inline_reuse = os.getenv('VOX_DISABLE_SAME_PASS_INLINE_REUSE') != ''
const same_pass_inline_diagnostics = os.getenv('VOX_SAME_PASS_INLINE_DIAGNOSTICS') != ''

__global same_pass_inline_reuse_reported bool

// A normal layout can revisit an inline context before its state retires.
// Keep even an indefinite root's numeric height exact for this question.
fn exact_inline_layout_key(used &UsedValues, mode LayoutMode, space AvailableSpace) InlineMeasurementKey {
	key := inline_measurement_key(used, mode, space, false)
	return InlineMeasurementKey{ ...key, height: used.content_height() }
}

fn same_pass_inline_inputs_are_current(inputs []RetainedInlineInput) bool {
	// Layout dirty flags stay set throughout a pass. Compare live membership,
	// style revisions, text and font owners instead, while keeping every clamp
	// on its ordinary path because it also changes the block context's state.
	if !inline_measurement_inputs_are_current(inputs) { return false }
	for input in inputs {
		if line_clamp_is_active(input.style) { return false }
	}
	return true
}

fn report_same_pass_inline_reuse() {
	if same_pass_inline_diagnostics && !same_pass_inline_reuse_reported {
		same_pass_inline_reuse_reported = true
		eprintln('Vox same-pass inline: reused current retained line geometry')
	}
}

fn restore_retained_inline_layout(mut state LayoutState, containing_block &BlockContainer,
	mut used UsedValues, context ?&BlockFormattingContext, key u64,
	cached &RetainedInlineLayout) InlineFormattingResult {
	used.borrow_retained_line_boxes(cached.lines)
	used.set_inline_end_static_position_rect(cached.inline_end)
	containing_values := state.get(unsafe { &NodeWithStyle(containing_block) })
	for index in 0 .. cached.values.len {
		entry := unsafe { &cached.values[index] }
		_ = state.restore_retained_values(entry.node, &entry.values, containing_values)
	}
	if mut bfc := context {
		// The ordinary line builder consumes this pending margin before
		// its first content. The eligibility guard makes its local delta zero.
		assert bfc.commit_pending_margin_before_inline_content().raw_value() == 0
	}
	state.inline_layouts_[key] = cached
	return cached.result
}
