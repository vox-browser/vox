module cpuraster

// Copy a visible rectangle between distinct filter buffers. The row starts
// already include the clip origin. Keep small rectangles on the caller.
fn copy_filter_rectangle(source []u8, mut destination []u8, source_pitch int, destination_pitch int, row_bytes int, rows int) {
	input := source[..(rows - 1) * source_pitch + row_bytes]
	output := destination[..(rows - 1) * destination_pitch + row_bytes]
	scan := FilterCopyScan{
		source:            input.data
		destination:       output.data
		source_pitch:      source_pitch
		destination_pitch: destination_pitch
		row_bytes:         row_bytes
	}
	if rows <= max_i32 && i64(row_bytes) * rows >= 4 * 1024 * 1024 {
		run_raster_scans(&scan, rows, row_bytes / 4, scan_filter_copy)
	} else {
		scan.copy_rows(0, rows)
	}
}

struct FilterCopyScan {
	source            &u8
	destination       &u8
	source_pitch      int
	destination_pitch int
	row_bytes         int
}

fn scan_filter_copy(context voidptr, first i32, end i32) {
	scan := unsafe { &FilterCopyScan(context) }
	scan.copy_rows(int(first), int(end))
}

fn (scan &FilterCopyScan) copy_rows(first int, end int) {
	unsafe {
		if scan.row_bytes == scan.source_pitch && scan.row_bytes == scan.destination_pitch {
			offset := first * scan.row_bytes
			vmemcpy(scan.destination + offset, scan.source + offset, (end - first) * scan.row_bytes)
			return
		}
		for row in first .. end {
			vmemcpy(scan.destination + row * scan.destination_pitch,
				scan.source + row * scan.source_pitch, scan.row_bytes)
		}
	}
}
