module cpuraster

import math
import runtime

#include "@DIR/scan_workers.h"
#flag windows -lpthread

fn C.vox_scan_workers_run(voidptr, i32, i32, fn (voidptr, i32, i32))
fn C.vox_scan_workers_disabled() bool

const scan_pixels_per_worker = 128 * 1024

// The callbacks borrow their input and output until every range has finished.
// They do not allocate or access mutable state outside their own pixel range.
fn run_raster_scans(context voidptr, lines int, pixels_per_line int, scan fn (voidptr, i32, i32)) {
	if lines <= 0 {
		return
	}
	work := i64(lines) * pixels_per_line
	mut lanes := 1
	if lines >= 2 && work >= 2 * scan_pixels_per_worker && !C.vox_scan_workers_disabled() {
		lanes = int(math.min(work / scan_pixels_per_worker, i64(C.VOX_SCAN_WORKERS_MAX)))
		lanes = math.min(lanes, math.min(lines, runtime.nr_cpus()))
	}
	if lanes <= 1 {
		scan(context, 0, i32(lines))
		return
	}
	C.vox_scan_workers_run(context, i32(lines), i32(lanes), scan)
}
