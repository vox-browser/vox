module layout

import css
import os
import platform

const disable_previous_measurement_reuse = os.getenv('VOX_DISABLE_PREVIOUS_MEASUREMENT_REUSE') != ''
const previous_measurement_diagnostics = os.getenv('VOX_PREVIOUS_MEASUREMENT_DIAGNOSTICS') != ''
__global previous_measurement_reported bool

// Entries already own their complete geometry outside the producer's scratch
// arena. Carry only entries visited and still valid in the immediately preceding
// layout. A rebuilt root starts a new history.
@[heap]
struct PreviousMeasurementLayouts {
	root &Node
	grids map[u64][]&GridMeasurementLayout
	flexes map[u64][]&FlexMeasurementLayout
	locations map[u64]PreviousMeasurementLocation
}

struct PreviousMeasurementLocation {
	parent u64
	sibling int
	flex_item bool
	grid_item bool
}

fn previous_measurement_location(root &Node) PreviousMeasurementLocation {
	return PreviousMeasurementLocation{
		parent: if parent := root.parent() { u64(voidptr(parent)) } else { 0 }
		sibling: root.index_in_parent_
		flex_item: root.is_flex_item()
		grid_item: root.is_grid_item()
	}
}

fn (mut state LayoutState) seed_previous_measurements(previous &LayoutState, root &Node) {
	if disable_previous_measurement_reuse || state.measurement_chunk_pool_ == unsafe { nil }
		|| previous.measurement_layouts_ == unsafe { nil }
		|| voidptr(previous.measurement_layouts_.root) != voidptr(root) { return }
	state.measurement_chunk_pool_.previous_layouts_ = previous.measurement_layouts_
}

fn collect_current_measurement_nodes(root &Node, mut nodes map[u64]bool) {
	nodes[u64(voidptr(root))] = true
	for child in root.children() { collect_current_measurement_nodes(child, mut nodes) }
}

fn previous_measurement_inputs_are_current(inputs []RetainedInlineInput, nodes map[u64]bool) bool {
	// Pending and absolute-image snapshots have a within-pass-only contract.
	// Keep that boundary even when their live request happens to be unchanged.
	if inputs.len < 2 || inputs.any(it.measurement_image != none) { return false }
	// Check every pointer against the live tree before dereferencing any saved
	// node. An old tree's detached nodes can have retired with their owner.
	for input in inputs {
		if !nodes[u64(voidptr(input.node))] { return false }
	}
	for index, input in inputs {
		if index == 0 { continue }
		parent := input.node.parent() or { return false }
		children := parent.children()
		if input.sibling_index < 0 || input.sibling_index >= children.len
			|| voidptr(children[input.sibling_index]) != voidptr(input.node) { return false }
	}
	return grid_measurement_inputs_are_current(inputs)
}

fn (mut pool MeasurementUsedValuesChunkPool) seed_previous_grid_measurements(root &Node,
	font_generation u64, environment u64) {
	key := u64(voidptr(root))
	if disable_previous_measurement_reuse || pool.previous_layouts_ == unsafe { nil }
		|| key in pool.grid_measurements_ || pool.previous_grid_attempts_[key] { return }
	entries := pool.previous_layouts_.grids[key] or { return }
	location := pool.previous_layouts_.locations[key] or { return }
	if location != previous_measurement_location(root) { return }
	mut nodes := map[u64]bool{}
	collect_current_measurement_nodes(root, mut nodes)
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	pool.previous_grid_attempts_[key] = true
	mut current := []&GridMeasurementLayout{}
	for entry in entries {
		if entry.inputs.len == 0 || voidptr(entry.inputs[0].node) != voidptr(root)
			|| entry.font_generation != font_generation || entry.style_environment != environment
			|| entry.font_policy != root.document().font_rendering_policy()
			|| !previous_measurement_inputs_are_current(entry.inputs, nodes) { continue }
		current << entry
		pool.previous_measurement_entries_[u64(voidptr(entry))] = false
	}
	if current.len > 0 { pool.grid_measurements_[key] = current }
}

fn (mut pool MeasurementUsedValuesChunkPool) seed_previous_flex_measurements(root &Node,
	font_generation u64, environment u64) {
	key := u64(voidptr(root))
	if disable_previous_measurement_reuse || pool.previous_layouts_ == unsafe { nil }
		|| key in pool.flex_measurements_ || pool.previous_flex_attempts_[key] { return }
	entries := pool.previous_layouts_.flexes[key] or { return }
	location := pool.previous_layouts_.locations[key] or { return }
	if location != previous_measurement_location(root) { return }
	mut nodes := map[u64]bool{}
	collect_current_measurement_nodes(root, mut nodes)
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	pool.previous_flex_attempts_[key] = true
	mut current := []&FlexMeasurementLayout{}
	for entry in entries {
		if entry.inputs.len == 0 || voidptr(entry.inputs[0].node) != voidptr(root)
			|| entry.font_generation != font_generation || entry.style_environment != environment
			|| entry.font_policy != root.document().font_rendering_policy()
			|| !previous_measurement_inputs_are_current(entry.inputs, nodes) { continue }
		current << entry
		pool.previous_measurement_entries_[u64(voidptr(entry))] = false
	}
	if current.len > 0 { pool.flex_measurements_[key] = current }
}

fn (mut state LayoutState) retain_measurements_for_next_layout(root &Node) {
	state.measurement_layouts_ = unsafe { nil }
	if disable_previous_measurement_reuse || state.measurement_chunk_pool_ == unsafe { nil } { return }
	pool := state.measurement_chunk_pool_
	if pool.grid_measurements_.len == 0 && pool.flex_measurements_.len == 0 { return }
	mut nodes := map[u64]bool{}
	collect_current_measurement_nodes(root, mut nodes)
	font_generation := css.css_style_computer_for(root.document()).font_computer().environment_generation()
	environment := root.document().style_environment_version()
	policy := root.document().font_rendering_policy()
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	mut grids := map[u64][]&GridMeasurementLayout{}
	mut flexes := map[u64][]&FlexMeasurementLayout{}
	mut locations := map[u64]PreviousMeasurementLocation{}
	for key, entries in pool.grid_measurements_ {
		mut current := []&GridMeasurementLayout{}
		for entry in entries {
			if entry.font_generation == font_generation && entry.style_environment == environment
				&& entry.font_policy == policy
				&& previous_measurement_inputs_are_current(entry.inputs, nodes) { current << entry }
		}
		if current.len > 0 {
			grids[key] = current
			locations[key] = previous_measurement_location(current[0].inputs[0].node)
		}
	}
	for key, entries in pool.flex_measurements_ {
		mut current := []&FlexMeasurementLayout{}
		for entry in entries {
			if entry.font_generation == font_generation && entry.style_environment == environment
				&& entry.font_policy == policy
				&& previous_measurement_inputs_are_current(entry.inputs, nodes) { current << entry }
		}
		if current.len > 0 {
			flexes[key] = current
			locations[key] = previous_measurement_location(current[0].inputs[0].node)
		}
	}
	if grids.len > 0 || flexes.len > 0 {
		state.measurement_layouts_ = &PreviousMeasurementLayouts{root: root, grids: grids, flexes: flexes, locations: locations}
	}
}

fn (mut pool MeasurementUsedValuesChunkPool) report_previous_measurement_hit(identity u64) {
	if identity !in pool.previous_measurement_entries_ { return }
	// Distinguish a validated seed from geometry actually consumed by layout.
	// Map assignment may grow its backing storage even for an existing key.
	if !pool.previous_measurement_entries_[identity] {
		mut retained := platform.enter_retained_allocations()
		pool.previous_measurement_entries_[identity] = true
		retained.finish()
	}
	if previous_measurement_diagnostics && !previous_measurement_reported {
		previous_measurement_reported = true
		eprintln('Vox measurement history: reused validated geometry from previous pass')
	}
}
