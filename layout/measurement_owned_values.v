module layout

import svg
import platform

struct FlexGridMeasurementCacheEntry {
mut:
	arena &platform.Arena = unsafe { nil }
	entry platform.ArenaEntry
	retained platform.RetainedAllocationScope
}

fn (mut pool MeasurementUsedValuesChunkPool) enter_flex_grid_measurement_cache() FlexGridMeasurementCacheEntry {
	$if prealloc {
		if pool.scratch_enabled_ {
			if pool.flex_grid_measurement_cache_ == unsafe { nil } {
				mut owner := platform.enter_retained_allocations()
				pool.flex_grid_measurement_cache_ = platform.new_arena('flex and grid measurements')
				owner.finish()
			}
			mut arena := pool.flex_grid_measurement_cache_
			return FlexGridMeasurementCacheEntry{arena: arena, entry: arena.enter()}
		}
	}
	return FlexGridMeasurementCacheEntry{retained: platform.enter_retained_allocations()}
}

fn (mut cache FlexGridMeasurementCacheEntry) finish() {
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

// Copy probe data into the caller's measurement cache before the probe retires.
fn append_owned_measurement_values(mut snapshots []RetainedBlockValues,
	node &NodeWithStyle, values &UsedValues) {
	mut snapshot := *values
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
		if path := rare.computed_svg_path_ {
			rare.computed_svg_path_ = own_measurement_svg_path(path)
		}
		rare.used_grid_column_line_names = own_grid_line_names(rare.used_grid_column_line_names)
		rare.used_grid_row_line_names = own_grid_line_names(rare.used_grid_row_line_names)
		snapshot.rare_ = rare
		snapshot.rare_is_shared_ = false
	}
	snapshots << RetainedBlockValues{
		node: node
		containing: retained_block_containing_node(values)
		values: snapshot
	}
}

// Other probes may borrow immutable cache payloads. A committed consumer
// outlives the pool and owns every part of the replayed geometry.
fn (mut state LayoutState) restore_flex_grid_measurement_values(entry &RetainedBlockValues,
	containing ?&UsedValues, publish bool) {
	if !publish {
		_ = state.restore_retained_values(entry.node, &entry.values, containing)
		return
	}
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	mut values := state.restore_retained_values(entry.node, &entry.values, containing)
	values.borrow_retained_line_boxes(clone_inline_layout_lines(entry.values.line_boxes, false))
	if position := values.inline_end_static_position_rect() {
		values.set_inline_end_static_position_rect(position)
	}
	if mut rare := values.rare_ {
		rare.used_grid_column_line_names = own_grid_line_names(rare.used_grid_column_line_names)
		rare.used_grid_row_line_names = own_grid_line_names(rare.used_grid_row_line_names)
	}
}
