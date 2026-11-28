module layout

import svg
import platform

struct MeasurementCacheScope {
mut:
	arena &platform.Arena = unsafe { nil }
	entry platform.ArenaEntry
	retained platform.RetainedAllocationScope
}

fn (mut pool MeasurementUsedValuesChunkPool) enter_measurement_cache() MeasurementCacheScope {
	$if prealloc {
		if pool.scratch_enabled_ {
			if pool.measurement_cache_arena_ == unsafe { nil } {
				mut owner := platform.enter_retained_allocations()
				pool.measurement_cache_arena_ = platform.new_arena('layout measurements')
				owner.finish()
			}
			mut arena := pool.measurement_cache_arena_
			return MeasurementCacheScope{arena: arena, entry: arena.enter()}
		}
	}
	return MeasurementCacheScope{retained: platform.enter_retained_allocations()}
}

fn (mut cache MeasurementCacheScope) finish() {
	if cache.arena != unsafe { nil } {
		cache.arena.leave(cache.entry)
	} else {
		cache.retained.finish()
	}
}

// Shape-generated paths can belong to the producer's scratch arena. Own both
// array levels; a restored consumer also gets its own writable path arrays.
fn own_measurement_svg_path(path svg.Path) svg.Path {
	mut instructions := []svg.PathInstruction{cap: path.instructions.len}
	for instruction in path.instructions {
		instructions << svg.PathInstruction{ ...instruction, data: instruction.data.clone() }
	}
	return svg.Path{ instructions: instructions }
}

// The cold records already belong to this copy. Give their nested buffers
// independent storage before the source workspace retires.
fn (mut rare UsedValuesRareData) own_svg_path() {
	if mut geometry := rare.svg_geometry_ {
		if path := geometry.path {
			geometry.path = own_measurement_svg_path(path)
		}
	}
}

fn (mut rare UsedValuesRareData) own_grid_names() {
	if mut grid := rare.grid_geometry_ {
		grid.column_line_names = own_grid_line_names(grid.column_line_names)
		grid.row_line_names = own_grid_line_names(grid.row_line_names)
	}
}

// Copy probe data into the caller's measurement cache before the probe retires.
fn append_owned_measurement_values(mut snapshots []RetainedBlockValues,
	node &NodeWithStyle, values &UsedValues) {
	snapshots << RetainedBlockValues{
		node: node
		containing: retained_block_containing_node(values)
		values: *values
	}
	mut snapshot := unsafe { &snapshots[snapshots.len - 1].values }
	own_measurement_snapshot(mut snapshot, values)
}

fn own_measurement_snapshot(mut snapshot UsedValues, values &UsedValues) {
	snapshot.containing_block_used_values_ = none
	snapshot.line_boxes = clone_inline_layout_lines(values.line_boxes, false)
	snapshot.line_boxes_are_shared_ = false
	snapshot.inline_end_static_position_snapshot_ = unsafe { nil }
	snapshot.inline_end_snapshot_arena_ = unsafe { nil }
	if position := values.inline_end_static_position_rect() {
		snapshot.set_inline_end_static_position_rect(position)
	}
	if source := snapshot.rare_ {
		mut rare := source.clone()
		rare.own_svg_path()
		rare.own_grid_names()
		snapshot.rare_ = rare
		snapshot.rare_is_shared_ = false
	}
}

fn (mut values UsedValues) publish_measurement_lines(state &LayoutState,
	node &NodeWithStyle, measured []LineBox) {
	previous := previous_pass_line_boxes(state, node) or { []LineBox{} }
	lines := if published_line_boxes_equal(previous, measured) {
		previous
	} else {
		own_inline_layout_lines(measured)
	}
	values.borrow_retained_line_boxes(lines)
}

// Other probes may borrow immutable cache payloads. A committed consumer
// outlives the pool and owns every part of the replayed geometry.
fn (mut state LayoutState) restore_measurement_values(node &NodeWithStyle, snapshot &UsedValues,
	containing ?&UsedValues, publish bool) {
	if !publish {
		_ = state.restore_retained_values(node, snapshot, containing)
		return
	}
	mut retained := platform.enter_retained_allocations()
	mut values := state.restore_retained_values(node, snapshot, containing)
	if position := values.inline_end_static_position_rect() {
		values.set_inline_end_static_position_rect(position)
	}
	if mut rare := values.rare_ {
		rare.own_grid_names()
	}
	retained.finish()
	values.publish_measurement_lines(state, node, snapshot.line_boxes)
}
