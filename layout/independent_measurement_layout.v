module layout

import css
import os

const disable_independent_measurement_reuse = os.getenv('VOX_DISABLE_INDEPENDENT_MEASUREMENT_REUSE') != ''
const independent_measurement_diagnostics = os.getenv('VOX_INDEPENDENT_MEASUREMENT_DIAGNOSTICS') != ''

__global independent_measurement_reuse_reported bool

struct MeasurementContextBasis {
	node_id           u64
	width             CSSPixels
	height            CSSPixels
	definite_width    bool
	definite_height   bool
}

fn measurement_context_bases(state &LayoutState, used &UsedValues) []MeasurementContextBasis {
	mut result := []MeasurementContextBasis{}
	mut ancestor := used.containing_block_used_values()
	for ancestor != none {
		values := ancestor or { break }
		result << MeasurementContextBasis{
			node_id:           u64(voidptr(values.node_))
			width:             values.content_width()
			height:            values.content_height()
			definite_width:    values.has_definite_width()
			definite_height:   values.has_definite_height()
		}
		// populate_node_from() deliberately severs copied geometry pointers.
		// Follow the layout node's logical chain in either kind of state.
		parent := unsafe { &Node(values.node_) }.containing_block() or { break }
		styled := unsafe { &Node(parent) }.as_node_with_style() or { break }
		ancestor = state.try_get(styled)
	}
	// A probe marker belongs to the box being measured. Closed child contexts
	// consume their own constraints and supplied available space, not a sizing
	// constraint on an ancestor whose resolved dimensions are unchanged.
	return result
}

// Probes only read the saved chain. Do not allocate a replacement vector for
// every lookup; those short-lived allocations can outweigh a small text layout.
fn measurement_context_bases_are_current(bases []MeasurementContextBasis,
	state &LayoutState, used &UsedValues) bool {
	mut ancestor := used.containing_block_used_values()
	mut index := 0
	for ancestor != none {
		values := ancestor or { break }
		if index >= bases.len { return false }
		basis := unsafe { &bases[index] }
		if basis.node_id != u64(voidptr(values.node_))
			|| basis.width != values.content_width() || basis.height != values.content_height()
			|| basis.definite_width != values.has_definite_width()
			|| basis.definite_height != values.has_definite_height() { return false }
		index++
		parent := unsafe { &Node(values.node_) }.containing_block() or { break }
		styled := unsafe { &Node(parent) }.as_node_with_style() or { break }
		ancestor = state.try_get(styled)
	}
	return index == bases.len
}

fn independent_measurement_inputs_are_current(inputs []RetainedInlineInput) bool {
	// A dirty bit remains set throughout the producing pass. Check the actual
	// inputs, including image availability, instead of rejecting that same bit.
	if !inline_measurement_inputs_are_current(inputs) { return false }
	for input in inputs {
		if previous := input.image {
			current := retained_block_image_input(input.node) or { return false }
			if previous != current { return false }
		}
	}
	return true
}

fn completed_context_for_measurement(state &LayoutState, box &Node,
	used &UsedValues, mode LayoutMode, space AvailableSpace) ?&RetainedBlockLayout {
	pool := state.measurement_chunk_pool_
	if mode != .normal || state.subtree_root == none || pool == unsafe { nil } || pool.closed
		|| pool.source_state_ == unsafe { nil } || pool.source_state_.subtree_root != none
		|| !space.width.is_definite() {
		return none
	}
	// Only completed contexts in this pass are admitted. The ordinary retained
	// cache already proves they are closed, and owns their geometry outside the
	// shorter-lived measurement arenas. A producer cannot publish itself until
	// its layout has returned, including all nested intrinsic probes.
	cached := pool.source_state_.block_layouts_[u64(voidptr(box))] or { return none }
	if cached.space != space || cached.width != used.content_width()
		|| cached.height != used.content_height()
		|| cached.definite_width != used.has_definite_width()
		|| cached.definite_height != used.has_definite_height()
		|| cached.width_constraint != used.width_constraint
		|| cached.height_constraint != used.height_constraint
		|| !measurement_context_bases_are_current(cached.input_bases, state, used)
		|| cached.font_policy != box.document().font_rendering_policy()
		|| cached.style_environment != box.document().style_environment_version()
		|| !independent_measurement_inputs_are_current(cached.inputs) {
		return none
	}
	font_generation := css.css_style_computer_for(box.document()).font_computer().environment_generation()
	if cached.font_generation != font_generation && !retained_layout_fonts_are_current(cached.inputs) {
		return none
	}
	return cached
}

fn run_measurement_independent_formatting_context(mut state LayoutState, box &Node,
	mut used UsedValues, mode LayoutMode, space AvailableSpace) FormattingContextResult {
	cached := completed_context_for_measurement(state, box, used, mode, space) or {
		return layout_uncached_independent_formatting_context(mut state, box, mut used, mode, space)
	}
	used.set_content_width(cached.output_width)
	used.set_content_height(cached.output_height)
	used.set_has_definite_width(cached.output_definite_width)
	used.set_has_definite_height(cached.output_definite_height)
	used.borrow_retained_line_boxes(cached.lines)
	if end := cached.inline_end { used.set_inline_end_static_position_rect(end) }
	if rare := cached.grid_container_rare {
		used.rare_ = rare.clone()
		used.rare_is_shared_ = false
	}
	for index in 0 .. cached.values.len {
		entry := unsafe { &cached.values[index] }
		mut containing := ?&UsedValues(none)
		if parent := entry.containing { containing = state.get(parent) }
		_ = state.restore_retained_values(entry.node, &entry.values, containing)
	}
	if independent_measurement_diagnostics && !independent_measurement_reuse_reported {
		independent_measurement_reuse_reported = true
		eprintln('Vox independent measurement: reused completed context with matching bases')
	}
	return cached.result
}
