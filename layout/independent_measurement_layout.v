module layout

import css
import dom
import os
import platform

const disable_independent_measurement_reuse = os.getenv('VOX_DISABLE_INDEPENDENT_MEASUREMENT_REUSE') != ''
const independent_measurement_diagnostics = os.getenv('VOX_INDEPENDENT_MEASUREMENT_DIAGNOSTICS') != ''

__global independent_measurement_reuse_reported bool

struct MeasurementContextBasis {
	node_id u64
	width CSSPixels
	height CSSPixels
	definite_width bool
	definite_height bool
	width_constraint SizeConstraint
	height_constraint SizeConstraint
}

@[heap]
struct IndependentMeasurementLayout {
	key InlineMeasurementKey
	bases []MeasurementContextBasis
	inputs []RetainedInlineInput
	font_generation u64
	font_policy dom.FontRenderingPolicy
	style_environment u64
	root UsedValues
	values []RetainedBlockValues
	result FormattingContextResult
}

fn measurement_context_bases(used &UsedValues) []MeasurementContextBasis {
	mut result := []MeasurementContextBasis{}
	mut ancestor := used.containing_block_used_values()
	for ancestor != none {
		values := ancestor or { break }
		result << MeasurementContextBasis{
			node_id: u64(voidptr(values.node_))
			width: values.content_width()
			height: values.content_height()
			definite_width: values.has_definite_width()
			definite_height: values.has_definite_height()
			width_constraint: values.width_constraint
			height_constraint: values.height_constraint
		}
		ancestor = values.containing_block_used_values()
	}
	return result
}

fn independent_measurement_inputs_are_current(inputs []RetainedInlineInput) bool {
	if !inline_measurement_inputs_are_current(inputs) { return false }
	for input in inputs {
		if previous := input.image {
			current := retained_block_image_input(input.node) or { return false }
			if previous != current { return false }
		}
	}
	return true
}

// Unlike committed retained geometry, a probe's lines and inline-end records
// may belong to an arena which retires before the next probe starts.
fn own_measurement_context_values(mut snapshot UsedValues) {
	snapshot.containing_block_used_values_ = none
	snapshot.line_boxes = own_inline_layout_lines(snapshot.line_boxes)
	snapshot.line_boxes_are_shared_ = false
	if rare := snapshot.rare_ { snapshot.rare_ = rare.clone() }
	snapshot.rare_is_shared_ = false
	if end := snapshot.inline_end_static_position_rect() {
		snapshot.inline_end_static_position_snapshot_ = &StaticPositionRect{...end}
	}
	snapshot.inline_end_snapshot_arena_ = unsafe { nil }
}

// Repeated intrinsic probes share only this layout pass's pool. Closed
// independent contexts cannot exchange floats or positioned descendants with
// their surroundings. All other contexts keep the full algorithm.
fn run_measurement_independent_formatting_context(mut state LayoutState, box &Node,
	mut used UsedValues, mode LayoutMode, space AvailableSpace) FormattingContextResult {
	mut pool := state.measurement_chunk_pool_
	styled := box.as_node_with_style() or {
		return layout_uncached_independent_formatting_context(mut state, box, mut used, mode, space)
	}
	if pool == unsafe { nil } || pool.closed || !space.width.is_definite()
		|| box.document().in_quirks_mode() || box.is_viewport() || box.is_root_element()
		|| box.display().is_inline_outside()
		|| (!creates_block_formatting_context(styled) && !retained_context_allows_flex(box)
			&& !retained_context_allows_grid(box)) {
		return layout_uncached_independent_formatting_context(mut state, box, mut used, mode, space)
	}
	key := inline_measurement_key(used, mode, space, false)
	bases := measurement_context_bases(used)
	node_key := u64(voidptr(box))
	font_generation := css.css_style_computer_for(box.document()).font_computer().environment_generation()
	previous := pool.independent_measurements_[node_key] or { []&IndependentMeasurementLayout{} }
	for cached in previous {
		if cached.key != key || cached.bases != bases || cached.font_generation != font_generation
			|| cached.font_policy != box.document().font_rendering_policy()
			|| cached.style_environment != box.document().style_environment_version()
			|| !independent_measurement_inputs_are_current(cached.inputs) { continue }
		used.set_content_width(cached.root.content_width())
		used.set_content_height(cached.root.content_height())
		used.set_has_definite_width(cached.root.has_definite_width())
		used.set_has_definite_height(cached.root.has_definite_height())
		used.borrow_retained_line_boxes(cached.root.line_boxes)
		if end := cached.root.inline_end_static_position_rect() { used.set_inline_end_static_position_rect(end) }
		used.rare_ = if rare := cached.root.rare_ { ?&UsedValuesRareData(rare.clone()) } else { none }
		used.rare_is_shared_ = false
		for index in 0 .. cached.values.len {
			entry := unsafe { &cached.values[index] }
			mut containing := ?&UsedValues(none)
			if parent := entry.containing { containing = state.get(parent) }
			_ = state.restore_retained_values(entry.node, &entry.values, containing)
		}
		if independent_measurement_diagnostics && !independent_measurement_reuse_reported {
			independent_measurement_reuse_reported = true
			eprintln('Vox independent measurement: reused closed context within pass')
		}
		return cached.result
	}
	mut inputs := []RetainedInlineInput{}
	mut rejected := map[u64]bool{}
	if !collect_retained_block_inputs(box, mut inputs, mut rejected) {
		return layout_uncached_independent_formatting_context(mut state, box, mut used, mode, space)
	}
	result := layout_uncached_independent_formatting_context(mut state, box, mut used, mode, space)
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	mut owned_inputs := []RetainedInlineInput{cap: inputs.len}
	mut snapshots := []RetainedBlockValues{cap: inputs.len - 1}
	for index, input in inputs {
		owned_inputs << RetainedInlineInput{...input, text: input.text.clone()}
		if index == 0 { continue }
		child := input.node.as_node_with_style() or { continue }
		if values := state.try_get(child) {
			snapshots << RetainedBlockValues{
				node: child
				containing: retained_block_containing_node(values)
				values: *values
			}
			mut snapshot := unsafe { &snapshots[snapshots.len - 1].values }
			own_measurement_context_values(mut snapshot)
		}
	}
	mut cached := &IndependentMeasurementLayout{
		key: key
		bases: bases.clone()
		inputs: owned_inputs
		font_generation: font_generation
		font_policy: box.document().font_rendering_policy()
		style_environment: box.document().style_environment_version()
		root: *used
		values: snapshots
		result: result
	}
	mut owned_root := unsafe { &cached.root }
	own_measurement_context_values(mut owned_root)
	mut entries := pool.independent_measurements_[node_key] or { []&IndependentMeasurementLayout{} }
	if entries.len == 4 { entries.delete(0) }
	entries << cached
	pool.independent_measurements_[node_key] = entries
	return result
}
