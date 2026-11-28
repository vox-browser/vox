module cpuraster

// swap_rgba_red_blue exchanges RGBA and BGRA in place, leaving row padding alone.
// The caller provides a writable raster with at least width * 4 bytes in every row.
@[unsafe]
pub fn swap_rgba_red_blue(pixels &u8, width i32, height i32, pitch i32) {
	if pixels == unsafe { nil } || width <= 0 || height <= 0 || i64(pitch) < i64(width) * 4 {
		return
	}
	scan := SwapRGBAScan{
		pixels: pixels
		width:  int(width)
		pitch:  int(pitch)
	}
	// At smaller sizes dispatch can cost as much as the entire in-place swap.
	if i64(width) * height < 4 * scan_pixels_per_worker {
		scan_swap_rgba_rows(&scan, 0, height)
		return
	}
	run_raster_scans(&scan, int(height), int(width), scan_swap_rgba_rows)
}

struct SwapRGBAScan {
	pixels &u8
	width  int
	pitch  int
}

fn scan_swap_rgba_rows(context voidptr, first i32, end i32) {
	scan := unsafe { &SwapRGBAScan(context) }
	pixels := scan.pixels
	unsafe {
		for row in int(first) .. int(end) {
			start := row * scan.pitch
			row_end := start + scan.width * 4
			for offset := start; offset < row_end; offset += 4 {
				red := pixels[offset]
				pixels[offset] = pixels[offset + 2]
				pixels[offset + 2] = red
			}
		}
	}
}
