module layout

import css
import os
import platform

const disable_grid_placement_reuse = os.getenv('VOX_DISABLE_GRID_PLACEMENT_REUSE') != ''
const grid_placement_diagnostics = os.getenv('VOX_GRID_PLACEMENT_DIAGNOSTICS') != ''

__global grid_placement_reuse_reported bool

struct GridPlacementChildInput {
	node     &Node
	style    &css.ComputedValues
	revision u64
	included bool
}

@[heap]
struct GridPlacementCache {
	style              &css.ComputedValues
	revision           u64
	children           []GridPlacementChildInput
	column_lines       [][]css.GridLineName
	row_lines          [][]css.GridLineName
	subgridded_columns bool
	subgridded_rows    bool
	result             GridPlacementResult
}

fn grid_placement_includes_child(child &Node) bool {
	return child.is_box() && !child.is_absolutely_positioned()
		&& !can_skip_anonymous_text_run(child)
}

fn (cached &GridPlacementCache) inputs_are_current(container &Node) bool {
	computed := container.computed_values()
	if voidptr(computed) != voidptr(cached.style) || computed.mutation_revision() != cached.revision
		|| computed.has_animated_properties() || container.child_count() != cached.children.len {
		return false
	}
	for index, child in container.children() {
		input := cached.children[index]
		current := child.computed_values()
		if voidptr(child) != voidptr(input.node) || voidptr(current) != voidptr(input.style)
			|| current.mutation_revision() != input.revision || current.has_animated_properties()
			|| grid_placement_includes_child(child) != input.included {
			return false
		}
	}
	return true
}

fn own_grid_placement_lines(lines [][]css.GridLineName) [][]css.GridLineName {
	mut result := [][]css.GridLineName{cap: lines.len}
	for line in lines {
		mut names := []css.GridLineName{cap: line.len}
		for name in line {
			names << css.GridLineName{ name: name.name.clone(), implicit: name.implicit }
		}
		result << names
	}
	return result
}

// Placement reads the immediate children's order/positions and the resolved
// line definitions, not track sizes or descendant geometry. Share that work
// across intrinsic questions within one layout pass, including subgrids and
// auto-repeat only when their fully expanded lines still match. The pool owns
// all arrays and names; callers receive a writable placement vector of their own.
fn place_grid_items_in_state(mut state LayoutState, container &Node,
	column_lines [][]css.GridLineName, row_lines [][]css.GridLineName,
	subgridded_columns bool, subgridded_rows bool) GridPlacementResult {
	mut pool := state.measurement_chunk_pool_
	if disable_grid_placement_reuse || pool == unsafe { nil } || pool.closed {
		return place_grid_items(container, column_lines, row_lines, subgridded_columns, subgridded_rows)
	}
	key := u64(voidptr(container))
	previous := pool.grid_placements_[key] or { []&GridPlacementCache{} }
	for cached in previous {
		if cached.subgridded_columns != subgridded_columns || cached.subgridded_rows != subgridded_rows
			|| cached.column_lines != column_lines || cached.row_lines != row_lines
			|| !cached.inputs_are_current(container) {
			continue
		}
		// ordered_grid_items() marks every participating box, even when another
		// layout question has reset its item flags since the previous call.
		for placement in cached.result.placements {
			mut item := unsafe { &Node(placement.item) }
			item.set_grid_item(true)
		}
		if grid_placement_diagnostics && !grid_placement_reuse_reported {
			grid_placement_reuse_reported = true
			eprintln('Vox grid placement: reused owned within-pass item placement')
		}
		return GridPlacementResult{ ...cached.result, placements: cached.result.placements.clone() }
	}
	result := place_grid_items(container, column_lines, row_lines, subgridded_columns, subgridded_rows)
	computed := container.computed_values()
	if computed.mutation_revision() == 0 || computed.has_animated_properties() { return result }
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	mut children := []GridPlacementChildInput{cap: container.child_count()}
	for child in container.children() {
		style := child.computed_values()
		if style.mutation_revision() == 0 || style.has_animated_properties() { return result }
		children << GridPlacementChildInput{
			node:     child
			style:    style
			revision: style.mutation_revision()
			included: grid_placement_includes_child(child)
		}
	}
	cached := &GridPlacementCache{
		style:              computed
		revision:           computed.mutation_revision()
		children:           children
		column_lines:       own_grid_placement_lines(column_lines)
		row_lines:          own_grid_placement_lines(row_lines)
		subgridded_columns: subgridded_columns
		subgridded_rows:    subgridded_rows
		result:             GridPlacementResult{ ...result, placements: result.placements.clone() }
	}
	mut entries := pool.grid_placements_[key] or { []&GridPlacementCache{} }
	if entries.len == 4 { entries.delete(0) }
	entries << cached
	pool.grid_placements_[key] = entries
	return result
}
