module layout

import css
import dom
import os
import platform

const disable_flex_measurement_reuse = os.getenv('VOX_DISABLE_FLEX_MEASUREMENT_REUSE') != ''
const disable_flex_image_measurement_reuse = os.getenv('VOX_DISABLE_FLEX_IMAGE_MEASUREMENT_REUSE') != ''
const flex_measurement_diagnostics = os.getenv('VOX_FLEX_MEASUREMENT_DIAGNOSTICS') != ''
const flex_image_measurement_diagnostics = os.getenv('VOX_FLEX_IMAGE_MEASUREMENT_DIAGNOSTICS') != ''
const disable_committed_flex_measurement_reuse = os.getenv('VOX_DISABLE_COMMITTED_FLEX_MEASUREMENT_REUSE') != ''
const committed_flex_measurement_diagnostics = os.getenv('VOX_COMMITTED_FLEX_MEASUREMENT_DIAGNOSTICS') != ''

__global flex_measurement_reuse_reported bool
__global flex_image_measurement_reuse_reported bool
__global committed_flex_measurement_reported bool

struct FlexMeasurementQuestion {
	// The complete grid measurement key also describes the scalar sizes,
	// box-model edges and external percentage bases consumed by closed flex.
	geometry GridMeasurementKey
	parent u64
	sibling int
	flex_item bool
	grid_item bool
}

@[heap]
struct FlexMeasurementLayout {
	key FlexMeasurementQuestion
	external_heights_independent bool
	inputs []RetainedInlineInput
	values []RetainedBlockValues
	font_generation u64
	font_policy dom.FontRenderingPolicy
	style_environment u64
	result FormattingContextResult
}

fn committed_flex_measurement_keys_match(a &FlexMeasurementQuestion, b &FlexMeasurementQuestion) bool {
	return a.parent == b.parent && a.sibling == b.sibling
		&& a.flex_item == b.flex_item && a.grid_item == b.grid_item
		&& committed_grid_measurement_keys_match(&a.geometry, &b.geometry)
}

fn flex_measurement_question(state &LayoutState, root &Node, used &UsedValues,
	space AvailableSpace) FlexMeasurementQuestion {
	return FlexMeasurementQuestion{
		geometry: grid_measurement_key(state, root, used, space)
		parent: if parent := root.parent() { u64(voidptr(parent)) } else { 0 }
		sibling: root.index_in_parent_
		flex_item: root.is_flex_item()
		grid_item: root.is_grid_item()
	}
}

fn run_flex_formatting_context_with_mode(mut state LayoutState, container &Node,
	mut used UsedValues, mode LayoutMode, space AvailableSpace) FormattingContextResult {
	mut pool := state.measurement_chunk_pool_
	committed := state.subtree_root == none
	if disable_flex_measurement_reuse || mode != .normal
		|| (committed && disable_committed_flex_measurement_reuse)
		|| !space.width.is_definite() || used.containing_block_used_values_ == none
		|| used.line_boxes.len != 0 || pool == unsafe { nil } || pool.closed
		|| !retained_context_allows_flex(container) || container.display().is_inline_outside()
		|| container.document().in_quirks_mode() || container.is_viewport()
		|| container.is_root_element() || container.is_body() {
		return run_uncached_flex_formatting_context_with_mode(mut state, container, mut used, mode, space)
	}
	node_key := u64(voidptr(container))
	if pool.flex_measurement_rejections_[node_key] {
		return run_uncached_flex_formatting_context_with_mode(mut state, container, mut used, mode, space)
	}
	key := flex_measurement_question(state, container, used, space)
	font_generation := css.css_style_computer_for(container.document()).font_computer().environment_generation()
	style_environment := container.document().style_environment_version()
	for cached in pool.flex_measurements_[node_key] or { []&FlexMeasurementLayout{} } {
		if (cached.key != key && !(committed && cached.external_heights_independent
			&& committed_flex_measurement_keys_match(&cached.key, &key)))
			|| cached.font_generation != font_generation
			|| cached.font_policy != container.document().font_rendering_policy()
			|| cached.style_environment != style_environment
			|| !grid_measurement_inputs_are_current(cached.inputs) { continue }
		// Normal flex clears the root's derived intrinsic baselines before it
		// publishes descendant geometry. Root offsets and percentage bases still
		// belong to this caller; only the measured descendants are restored.
		used.set_derived_baselines(none, none)
		for index in 0 .. cached.values.len {
			entry := unsafe { &cached.values[index] }
			containing := if parent := entry.containing { state.get(parent) } else { none }
			_ = state.restore_retained_values(entry.node, &entry.values, containing)
		}
		if flex_measurement_diagnostics && !flex_measurement_reuse_reported {
			flex_measurement_reuse_reported = true
			eprintln('Vox flex measurement: reused resolved within-pass geometry')
		}
		if flex_image_measurement_diagnostics && !flex_image_measurement_reuse_reported
			&& cached.inputs.any(it.image != none) {
			flex_image_measurement_reuse_reported = true
			eprintln('Vox flex images: reused decoded image measurement')
		}
		report_relative_measurement_reuse(cached.inputs)
		report_svg_measurement_reuse(cached.inputs)
		report_extended_image_measurement(cached.inputs)
		if committed && committed_flex_measurement_diagnostics && !committed_flex_measurement_reported {
			committed_flex_measurement_reported = true
			eprintln('Vox flex measurement: promoted measured flex into committed geometry')
		}
		return cached.result
	}
	// A final-layout miss must neither populate nor evict disposable entries.
	if committed {
		return run_uncached_flex_formatting_context_with_mode(mut state, container, mut used, mode, space)
	}
	mut retained_inputs := platform.enter_retained_allocations()
	mut inputs := []RetainedInlineInput{}
	mut eligible := collect_grid_measurement_inputs(container, mut inputs,
		mut pool.flex_measurement_rejections_)
	// The shared collector validates non-SVG HTML image inputs, including
	// pending requests and absolute images, against their live provider.
	// Keep the earlier text-only policy as an isolated measurement control.
	if disable_flex_image_measurement_reuse && inputs.any(it.image != none || it.measurement_image != none) { eligible = false }
	if !eligible { pool.flex_measurement_rejections_[node_key] = true }
	mut owned_inputs := []RetainedInlineInput{cap: inputs.len}
	if eligible {
		for input in inputs { owned_inputs << own_image_measurement_input(input) }
	}
	retained_inputs.finish()
	result := run_uncached_flex_formatting_context_with_mode(mut state, container, mut used, mode, space)
	// Normal flex publishes descendant geometry and the result. Never retain a
	// case which also changes keyed root/ancestor geometry or root line storage.
	if !eligible || used.line_boxes.len != 0
		|| key != flex_measurement_question(state, container, used, space)
		|| font_generation != css.css_style_computer_for(container.document()).font_computer().environment_generation()
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
	cached := &FlexMeasurementLayout{
		key: FlexMeasurementQuestion{
			...key
			geometry: GridMeasurementKey{
				...key.geometry
				external_bases: key.geometry.external_bases.clone()
			}
		}
		external_heights_independent: grid_measurement_external_heights_are_unused(owned_inputs)
		inputs: owned_inputs
		values: snapshots
		font_generation: font_generation
		font_policy: container.document().font_rendering_policy()
		style_environment: style_environment
		result: result
	}
	mut entries := pool.flex_measurements_[node_key] or { []&FlexMeasurementLayout{} }
	if entries.len == 4 { entries.delete(0) }
	entries << cached
	pool.flex_measurements_[node_key] = entries
	return result
}
