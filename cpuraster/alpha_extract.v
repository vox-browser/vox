module cpuraster

// copy_rgba_alpha extracts a packed A8 mask from four-byte pixels with alpha
// in the last byte. A trailing incomplete pixel does not produce an output.
pub fn copy_rgba_alpha(source []u8) []u8 {
	output := []u8{len: source.len / 4}
	scan := RgbaAlphaScan{
		source: source.data
		output: output.data
	}
	// Dispatch only once the source covers at least 2 MiB. Smaller masks
	// finish faster in one scan because extraction does little arithmetic.
	complete := if output.len >= 4 * scan_pixels_per_worker {
		run_packed_rgba_scans(&scan, output.len * 4, scan_rgba_alpha) / 4
	} else {
		0
	}
	scan.copy_pixels(complete, output.len)
	return output
}

struct RgbaAlphaScan {
	source &u8
	output &u8
}

fn scan_rgba_alpha(context voidptr, first i32, end i32) {
	scan := unsafe { &RgbaAlphaScan(context) }
	scan.copy_pixels(int(first) * packed_rgba_scan_pixels, int(end) * packed_rgba_scan_pixels)
}

@[inline]
fn (scan &RgbaAlphaScan) copy_pixels(first int, end int) {
	source := scan.source
	output := scan.output
	unsafe {
		for i in first .. end {
			output[i] = source[i * 4 + 3]
		}
	}
}
