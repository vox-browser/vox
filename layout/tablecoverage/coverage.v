module tablecoverage

import cpuraster
import math
import os
import platform

const parallel_table_cell_fixup = os.getenv('VOX_PARALLEL_TABLE_CELL_FIXUP') == '1'
const table_cell_fixup_diagnostics = os.getenv('VOX_TABLE_CELL_FIXUP_DIAGNOSTICS') == '1'
const table_cell_coverage_max_slots = 1_048_576
const table_cell_coverage_rows_per_lane = 16

pub fn use_dense_coverage(rows int, columns int) bool {
	return rows >= 2 * table_cell_coverage_rows_per_lane && columns > 0
		&& rows <= table_cell_coverage_max_slots / columns
}

pub struct CellSpan {
pub:
	row         int
	column      int
	row_span    int = 1
	column_span int = 1
}

struct TableCellCoverageWork {
	placements []CellSpan
	occupied   &bool
	threads    &u64
	columns    int
}

// Placements are sorted by originating row. A range includes cells originating
// earlier if their span reaches it. Only the owner reads the completed grid or
// modifies the layout tree.
fn mark_table_cell_coverage_range(context voidptr, first i32, end i32) {
	work := unsafe { &TableCellCoverageWork(context) }
	if work.threads != unsafe { nil } {
		unsafe { work.threads[first] = platform.native_thread_identity() }
	}
	for placement in work.placements {
		if placement.row >= int(end) { break }
		last_row := math.min(int(end), placement.row + placement.row_span)
		if last_row <= int(first) { continue }
		first_row := math.max(int(first), placement.row)
		for row in first_row .. last_row {
			offset := row * work.columns
			for column in placement.column .. placement.column + placement.column_span {
				unsafe { work.occupied[offset + column] = true }
			}
		}
	}
}

// The caller bounds the grid and uses the column count from the placement
// pass. In particular, column + column_span never exceeds that count.
pub fn build(placements []CellSpan, rows int, columns int) []bool {
	mut occupied := []bool{len: rows * columns}
	mut threads := []u64{}
	if table_cell_fixup_diagnostics { threads = []u64{len: rows} }
	work := TableCellCoverageWork{
		placements: placements
		occupied: unsafe { &bool(occupied.data) }
		threads: unsafe { if threads.len != 0 { &u64(threads.data) } else { &u64(nil) } }
		columns: columns
	}
	mut lanes := 0
	if parallel_table_cell_fixup {
		lanes = cpuraster.run_raster_ranges_with_caller(&work, rows,
			math.min(4, rows / table_cell_coverage_rows_per_lane), mark_table_cell_coverage_range)
	}
	if lanes == 0 { mark_table_cell_coverage_range(&work, 0, i32(rows)) }
	if table_cell_fixup_diagnostics {
		caller := platform.native_thread_identity()
		worker_ranges := threads.count(it != 0 && it != caller)
		eprintln('VOX_TABLE_CELL_FIXUP rows=${rows} columns=${columns} placements=${placements.len} lanes=${lanes} worker_ranges=${worker_ranges}')
	}
	return occupied
}
