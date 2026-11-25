module cpuraster

import math
import runtime

#include "@DIR/scan_workers.h"
// Use MinGW's static pthread runtime, which V also selects for its own helpers.
#flag windows -l:libpthread.a

fn C.vox_scan_workers_run(voidptr, i32, i32, fn (voidptr, i32, i32))
fn C.vox_scan_workers_disabled() bool

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
	mut lanes := 1
	if requested_lanes > 1 && lines <= max_i32 && !C.vox_scan_workers_disabled() {
		lanes = math.min(requested_lanes, math.min(int(C.VOX_SCAN_WORKERS_MAX), math.min(lines, runtime.nr_cpus())))
	}
	if lanes <= 1 {
		scan(context, 0, i32(lines))
		return 1
	}
	C.vox_scan_workers_run(context, i32(lines), i32(lanes), scan)
	return lanes
}
