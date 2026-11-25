module cpuraster

import math
import runtime

#include "@DIR/scan_workers.h"
// Use MinGW's static pthread runtime, which V also selects for its own helpers.
#flag windows -l:libpthread.a

fn C.vox_scan_workers_run(voidptr, i32, i32, fn (voidptr, i32, i32))
fn C.vox_scan_workers_disabled() bool

$if macos {
	fn C.vox_scan_workers_with_caller(voidptr, i32, i32, fn (voidptr, i32, i32)) bool
	fn C.vox_scan_worker_start(voidptr, i32, i32, fn (voidptr, i32, i32)) voidptr
	fn C.vox_scan_worker_join(voidptr) bool
}

// Run the final range on the caller and join the explicitly submitted worker
// ranges. Return zero without calling scan if parallel work cannot start.
pub fn run_raster_ranges_with_caller(context voidptr, lines int, requested_lanes int,
	scan fn (voidptr, i32, i32)) int {
	$if macos {
		lanes := raster_range_lanes(lines, requested_lanes)
		if lanes >= 2 && C.vox_scan_workers_with_caller(context, i32(lines), i32(lanes), scan) {
			return lanes
		}
	}
	return 0
}

const scan_pixels_per_worker = 128 * 1024
const packed_rgba_scan_pixels = 1024
const packed_rgba_scan_bytes = packed_rgba_scan_pixels * 4

// Return the byte offset of the final partial batch. The caller handles it
// after the full batches have joined.
fn run_packed_rgba_scans(context voidptr, byte_count int, scan fn (voidptr, i32, i32)) int {
	batches := byte_count / packed_rgba_scan_bytes
	if batches > max_i32 {
		return 0
	}
	run_raster_scans(context, batches, packed_rgba_scan_pixels, scan)
	return batches * packed_rgba_scan_bytes
}

// run_raster_scans joins all ranges before returning. The line count fits in
// i32. Callers keep borrowed buffers alive and provide nonoverlapping write
// ranges. Callbacks do not allocate or access mutable state outside their range.
pub fn run_raster_scans(context voidptr, lines int, pixels_per_line int, scan fn (voidptr, i32, i32)) {
	if lines <= 0 {
		return
	}
	work := i64(lines) * pixels_per_line
	mut lanes := 1
	if lines >= 2 && work >= 2 * scan_pixels_per_worker {
		lanes = int(math.min(work / scan_pixels_per_worker, i64(C.VOX_SCAN_WORKERS_MAX)))
	}
	run_raster_ranges(context, lines, lanes, scan)
}

// Same worker contract as run_raster_scans, with a caller-supplied lane budget
// for non-pixel work. Return the number of scheduled ranges for diagnostics.
pub fn run_raster_ranges(context voidptr, lines int, requested_lanes int, scan fn (voidptr, i32, i32)) int {
	if lines <= 0 { return 0 }
	lanes := raster_range_lanes(lines, requested_lanes)
	if lanes <= 1 {
		scan(context, 0, i32(lines))
		return 1
	}
	C.vox_scan_workers_run(context, i32(lines), i32(lanes), scan)
	return lanes
}

fn raster_range_lanes(lines int, requested_lanes int) int {
	if lines < 2 || lines > max_i32 || requested_lanes < 2 || C.vox_scan_workers_disabled() {
		return 1
	}
	return math.min(requested_lanes, math.min(int(C.VOX_SCAN_WORKERS_MAX), math.min(lines, runtime.nr_cpus())))
}

// Start a borrowed range on a background worker. A non-nil ticket must be
// joined before the caller reads the results or releases the backing storage.
// A nil ticket leaves the range unprocessed.
pub fn start_background_raster_range(context voidptr, lines i32, scan fn (voidptr, i32, i32)) voidptr {
	$if macos {
		if lines > 0 && !C.vox_scan_workers_disabled() && runtime.nr_cpus() > 1 {
			return C.vox_scan_worker_start(context, lines, 1, scan)
		}
	}
	return unsafe { nil }
}

// Submit every range to a worker. The caller can do independent work before
// joining with join_background_raster_range.
pub fn start_background_raster_ranges(context voidptr, lines int, requested_lanes int,
	scan fn (voidptr, i32, i32)) (voidptr, int) {
	$if macos {
		lanes := raster_range_lanes(lines, requested_lanes)
		if lanes >= 2 {
			ticket := C.vox_scan_worker_start(context, i32(lines), i32(lanes), scan)
			if ticket != unsafe { nil } { return ticket, lanes }
		}
	}
	return unsafe { nil }, 0
}

// Join the range and report whether it was already finished at the join.
pub fn join_background_raster_range(ticket voidptr) bool {
	$if macos {
		if ticket != unsafe { nil } { return C.vox_scan_worker_join(ticket) }
	}
	return false
}
