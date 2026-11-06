module layout

import css
import dom
import os
import platform

const disable_grid_measurement_reuse = os.getenv('VOX_DISABLE_GRID_MEASUREMENT_REUSE') != ''
const grid_measurement_diagnostics = os.getenv('VOX_GRID_MEASUREMENT_DIAGNOSTICS') != ''
const disable_relative_measurement_reuse = os.getenv('VOX_DISABLE_RELATIVE_MEASUREMENT_REUSE') != ''
const relative_measurement_diagnostics = os.getenv('VOX_RELATIVE_MEASUREMENT_DIAGNOSTICS') != ''
const disable_svg_measurement_reuse = os.getenv('VOX_DISABLE_SVG_MEASUREMENT_REUSE') != ''
const svg_measurement_diagnostics = os.getenv('VOX_SVG_MEASUREMENT_DIAGNOSTICS') != ''

__global grid_measurement_reuse_reported bool
__global relative_measurement_reuse_reported bool
__global svg_measurement_reuse_reported bool

fn report_svg_measurement_reuse(inputs []RetainedInlineInput) {
	if !svg_measurement_diagnostics || svg_measurement_reuse_reported { return }
	if inputs.any(it.simple_svg != none) {
		svg_measurement_reuse_reported = true
		eprintln('Vox SVG measurement: reused owned closed shape geometry')
	}
}

fn report_relative_measurement_reuse(inputs []RetainedInlineInput) {
	if !relative_measurement_diagnostics || relative_measurement_reuse_reported { return }
	if inputs.any(it.node.is_positioned()) {
		relative_measurement_reuse_reported = true
		eprintln('Vox relative measurement: reused unshifted positioned geometry')
	}
}

struct GridMeasurementKey {
	space AvailableSpace
	width CSSPixels
	height CSSPixels
	definite_width bool
	definite_height bool
	width_constraint SizeConstraint
	height_constraint SizeConstraint
	edges [16]CSSPixels
	containing_node u64
	containing_width CSSPixels
	containing_height CSSPixels
	containing_definite_width bool
	containing_definite_height bool
	external_bases []GridMeasurementBasis
}

struct GridMeasurementBasis {
	node u64
	present bool
	width CSSPixels
	height CSSPixels
	definite_width bool
	definite_height bool
}

@[heap]
struct GridMeasurementLayout {
	key GridMeasurementKey
	opacity_measurement bool
	external_heights_independent bool
	inputs []RetainedInlineInput
	values []RetainedBlockValues
	columns []CSSPixels
	rows []CSSPixels
	column_names [][]string
	row_names [][]string
	font_generation u64
	font_policy dom.FontRenderingPolicy
	style_environment u64
	result FormattingContextResult
}

fn grid_measurement_key(state &LayoutState, root &Node, used &UsedValues, space AvailableSpace) GridMeasurementKey {
	containing := used.containing_block_used_values_ or { return GridMeasurementKey{} }
	// Nested intrinsic probes also copy the external ancestor chain. Preserve
	// its resolved percentage bases. The ancestors' min/max-content question
	// does not change this normal layout at an already resolved grid width;
	// the grid's own constraints remain part of the key above.
	mut external_bases := []GridMeasurementBasis{}
	mut ancestor := root.containing_block()
	for ancestor != none {
		box := ancestor or { break }
		styled := unsafe { &NodeWithStyle(box) }
		if values := state.try_get(styled) {
			external_bases << GridMeasurementBasis{
				node: u64(voidptr(box))
				present: true
				width: values.content_width()
				height: values.content_height()
				definite_width: values.has_definite_width()
				definite_height: values.has_definite_height()
			}
		} else {
			external_bases << GridMeasurementBasis{ node: u64(voidptr(box)) }
		}
		ancestor = unsafe { &Node(box) }.containing_block()
	}
	return GridMeasurementKey{
		space: space
		width: used.content_width()
		height: used.content_height()
		definite_width: used.has_definite_width()
		definite_height: used.has_definite_height()
		width_constraint: used.width_constraint
		height_constraint: used.height_constraint
		edges: [used.margin_left, used.margin_right, used.margin_top, used.margin_bottom,
			used.border_left, used.border_right, used.border_top, used.border_bottom,
			used.padding_left, used.padding_right, used.padding_top, used.padding_bottom,
			used.inset_left, used.inset_right, used.inset_top, used.inset_bottom]!
		containing_node: u64(voidptr(containing.node_))
		containing_width: containing.content_width()
		containing_height: containing.content_height()
		containing_definite_width: containing.has_definite_width()
		containing_definite_height: containing.has_definite_height()
		external_bases: external_bases
	}
}

fn grid_measurement_inputs_are_current(inputs []RetainedInlineInput) bool {
	// Dirty layout bits remain set for the entire pass. Validate the actual
	// inputs, as the closed inline measurement cache does, without clearing them.
	if !inline_measurement_inputs_are_current(inputs) { return false }
	for input in inputs {
		if image := input.measurement_image {
			if (measurement_image_input(input.node) or { return false }) != image { return false }
		}
		if saved := input.simple_svg {
			owner := input.node.dom_node() or { return false }
			if saved.elements.len == 0 || voidptr(owner) != voidptr(saved.elements[0].element.as_node())
				|| !retained_simple_svg_input_is_current(saved) { return false }
		}
		if image := input.image {
			if (retained_block_image_input(input.node) or { return false }) != image { return false }
		}
		computed := input.node.computed_values()
		if computed.line_height() != input.line_height
			|| computed.root_font_size_px_ != input.root_font_size
			|| computed.root_line_height_px_ != input.root_line_height { return false }
	}
	return true
}

fn collect_grid_measurement_inputs(root &Node, mut inputs []RetainedInlineInput,
	mut rejected map[u64]bool) bool {
	if !collect_retained_block_inputs_in_svg(root, false, !disable_extended_image_measurements, true,
		mut inputs, mut rejected) { return false }
	for index, input in inputs {
		// Controls, subgrids, floats, fragmentation and shifted positions
		// keep their full algorithms. Every containing block must be inside the
		// captured subtree; only the root may depend on the keyed outer block.
		// The shared collector proves relative insets are all auto. Its
		// measurement-only exception admits validated absolute HTML images;
		// their final absolute layout still runs after restoring static positions.
		// It also admits only closed SVG shapes, with complete DOM attributes
		// and child identities retained under the caller's document owner.
		if (disable_svg_measurement_reuse && (input.node.is_svg_box() || input.simple_svg != none))
			|| (disable_relative_measurement_reuse && input.node.is_positioned())
			|| line_clamp_is_active(input.style) { return false }
		if index > 0 {
			containing := input.node.containing_block() or { return false }
			if voidptr(containing) != voidptr(root)
				&& !root.is_inclusive_ancestor_of(unsafe { &Node(containing) }) { return false }
			if !unsafe { &Node(containing) }.is_inclusive_ancestor_of(input.node) { return false }
		}
	}
	return inputs.len > 1
}

// Ordinary grid layout is repeated inside disposable intrinsic probes. Keep
// completed local geometry in the shared pass owner, never in a producer's
// scratch arena. Final layout can consume an existing owned result; scalar and
// width-only probes retain their complete algorithms.
fn run_grid_formatting_context_internal(mut state LayoutState, container &Node,
	mut used UsedValues, mode LayoutMode, space AvailableSpace, width_only bool) FormattingContextResult {
	mut pool := state.measurement_chunk_pool_
	committed := state.subtree_root == none
	if disable_grid_measurement_reuse || mode != .normal || width_only
		|| !space.width.is_definite() || (committed && disable_committed_grid_measurement_reuse)
		|| used.containing_block_used_values_ == none || pool == unsafe { nil } || pool.closed
		|| !retained_context_allows_grid(container) || container.document().in_quirks_mode()
		|| container.is_viewport() || container.is_root_element() || container.is_body() {
		return run_uncached_grid_formatting_context_internal(mut state, container, mut used,
			mode, space, width_only)
	}
	node_key := u64(voidptr(container))
	if pool.grid_measurement_rejections_[node_key] {
		return run_uncached_grid_formatting_context_internal(mut state, container, mut used,
			mode, space, width_only)
	}
	key := grid_measurement_key(state, container, used, space)
	font_generation := css.css_style_computer_for(container.document()).font_computer().environment_generation()
	style_environment := container.document().style_environment_version()
	mut previous := pool.grid_measurements_[node_key] or { []&GridMeasurementLayout{} }
	for cache_index, cached in previous {
		keys_match := cached.key == key || (committed && cached.external_heights_independent
			&& committed_grid_measurement_keys_match(&cached.key, &key))
		unused_heights := !keys_match && !disable_unused_measurement_heights
			&& cached.external_heights_independent
			&& grid_measurement_keys_match_with_height_policy(&cached.key, &key, true)
		if (!keys_match && !unused_heights)
			|| cached.font_generation != font_generation
			|| cached.font_policy != container.document().font_rendering_policy()
			|| cached.style_environment != style_environment { continue }
		if !grid_measurement_inputs_are_current(cached.inputs) {
			if cached.opacity_measurement {
				mut retained := platform.enter_retained_allocations()
				pool.grid_measurement_rejections_[node_key] = true
				retained.finish()
				return run_uncached_grid_formatting_context_internal(mut state, container,
					mut used, mode, space, width_only)
			}
			continue
		}
		// The caller owns the root's size, offset and relative-position basis.
		// The normal definite-width grid algorithm publishes only these tracks.
		used.set_grid_template_columns(cached.columns)
		used.set_grid_template_rows(cached.rows)
		used.set_grid_line_names(cached.column_names, cached.row_names)
		used.set_grid_subgridded_axes(false, false)
		for index in 0 .. cached.values.len {
			entry := unsafe { &cached.values[index] }
			containing := if parent := entry.containing { state.get(parent) } else { none }
			_ = state.restore_retained_values(entry.node, &entry.values, containing)
		}
		if grid_measurement_diagnostics && !grid_measurement_reuse_reported {
			grid_measurement_reuse_reported = true
			eprintln('Vox grid measurement: reused resolved within-pass geometry')
		}
		if committed { report_committed_grid_measurement_reuse() }
		report_relative_measurement_reuse(cached.inputs)
		report_svg_measurement_reuse(cached.inputs)
		report_extended_image_measurement(cached.inputs)
		report_opacity_measurement_reuse(cached.inputs)
		if unused_heights { report_unused_measurement_heights() }
		if !committed { retain_recent_measurement(mut previous, cache_index, container) }
		return cached.result
	}
	// A committed miss must not populate, reject or evict disposable entries.
	if committed {
		return run_uncached_grid_formatting_context_internal(mut state, container, mut used,
			mode, space, width_only)
	}
	mut retained_inputs := platform.enter_retained_allocations()
	mut inputs := []RetainedInlineInput{}
	mut eligible := collect_grid_measurement_inputs(container, mut inputs, mut pool.grid_measurement_rejections_)
	if !eligible { pool.grid_measurement_rejections_[node_key] = true }
	opacity_measurement := eligible && measurement_inputs_have_animated_opacity(inputs)
	if opacity_measurement && !pool.admit_opacity_measurement(node_key) { eligible = false }
	mut owned_inputs := []RetainedInlineInput{cap: inputs.len}
	if eligible {
		for input in inputs { owned_inputs << own_image_measurement_input(input) }
	}
	retained_inputs.finish()
	result := run_uncached_grid_formatting_context_internal(mut state, container, mut used,
		mode, space, width_only)
	if !eligible || font_generation != css.css_style_computer_for(container.document()).font_computer().environment_generation()
		|| style_environment != container.document().style_environment_version()
		|| !grid_measurement_inputs_are_current(owned_inputs) { return result }
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	mut snapshots := []RetainedBlockValues{cap: owned_inputs.len - 1}
	for input in owned_inputs[1..] {
		styled := input.node.as_node_with_style() or { continue }
		values := state.try_get(styled) or { continue }
		append_owned_measurement_values(mut snapshots, styled, values)
	}
	cached := &GridMeasurementLayout{
		key: GridMeasurementKey{ ...key, external_bases: key.external_bases.clone() }
		opacity_measurement: opacity_measurement
		external_heights_independent: grid_measurement_external_heights_are_unused(owned_inputs)
		inputs: owned_inputs
		values: snapshots
		columns: used.grid_template_columns().clone()
		rows: used.grid_template_rows().clone()
		column_names: own_grid_line_names(used.grid_column_line_names())
		row_names: own_grid_line_names(used.grid_row_line_names())
		font_generation: font_generation
		font_policy: container.document().font_rendering_policy()
		style_environment: style_environment
		result: result
	}
	mut entries := pool.grid_measurements_[node_key] or { []&GridMeasurementLayout{} }
	if entries.len == 4 { entries.delete(0) }
	entries << cached
	pool.grid_measurements_[node_key] = entries
	return result
}
