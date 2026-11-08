module layout

import os

const disable_previous_inline_measurements = os.getenv('VOX_DISABLE_PREVIOUS_INLINE_MEASUREMENTS') != ''
const previous_inline_measurement_diagnostics = os.getenv('VOX_PREVIOUS_INLINE_MEASUREMENT_DIAGNOSTICS') != ''

__global previous_inline_measurement_hits u64

// Only closed inline roots reach this lookup. A committed answer from the last
// pass can answer the same measurement question after validating every live
// style, tree, text and font input. Probe scratch never becomes a cache owner.
fn previous_inline_measurement(mut state LayoutState, containing_block &BlockContainer,
	mut used UsedValues, context ?&BlockFormattingContext,
	pool &MeasurementUsedValuesChunkPool, key InlineMeasurementKey, node_key u64,
	font_generation u64) ?InlineFormattingResult {
	if disable_previous_inline_measurements || key.width_only { return none }
	cached := pool.previous_inline_measurements_[node_key] or { return none }
	old := cached.same_pass_key
	previous_key := InlineMeasurementKey{
		...old
		mode: if disable_closed_inline_measurement_question_reuse { old.mode } else { LayoutMode.normal }
		space: if disable_closed_inline_measurement_question_reuse { old.space } else {
			AvailableSpace.new(old.space.width, AvailableSize.make_indefinite())
		}
		height: if !retain_inline_measurement_indefinite_height && !old.definite_height {
			CSSPixels.from_raw(0)
		} else { old.height }
	}
	root := unsafe { &Node(containing_block) }
	if previous_key != key || cached.font_generation != font_generation
		|| cached.font_policy != root.document().font_rendering_policy()
		|| cached.style_environment != root.document().style_environment_version()
		|| !inline_measurement_inputs_are_current(cached.inputs)
		|| !retained_layout_fonts_are_current(cached.inputs) {
		return none
	}
	used.borrow_retained_line_boxes(cached.lines)
	used.set_inline_end_static_position_rect(cached.inline_end)
	containing_values := state.get(unsafe { &NodeWithStyle(containing_block) })
	for index in 0 .. cached.values.len {
		entry := unsafe { &cached.values[index] }
		_ = state.restore_retained_values(entry.node, &entry.values, containing_values)
	}
	if mut bfc := context {
		delta := bfc.commit_pending_margin_before_inline_content()
		assert delta.raw_value() == 0
	}
	if previous_inline_measurement_diagnostics {
		previous_inline_measurement_hits++
		if previous_inline_measurement_hits == 1 {
			eprintln('Vox previous inline measurements: reused validated committed lines')
		}
	}
	return cached.result
}
