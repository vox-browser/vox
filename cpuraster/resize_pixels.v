module cpuraster

// A decoded-image upload uses the same Q15 bilinear sampler as an 8-bit
// raster-pipeline image shader, including its intermediate rounding.
pub fn resize_premultiplied_rgba(pixels []u8, source_width int, source_height int,
	width int, height int) ?[]u8 {
	return resize_image_pixels(pixels, source_width, source_height, width, height, .rgba)
}

enum ImageResizeFormat {
	rgba
	r8
	gray8
}

struct ImageResizeScan {
	source        []u8
	target        []u8
	source_width  int
	source_height int
	width         int
	scale_x       f32
	scale_y       f32
	format        ImageResizeFormat
}

fn resize_image_pixels(pixels []u8, source_width int, source_height int, width int, height int,
	format ImageResizeFormat) ?[]u8 {
	channels := if format == .rgba { 4 } else { 1 }
	if source_width <= 0 || source_height <= 0 || source_width > 4096 || source_height > 4096
		|| source_width * source_height > 4 * 1024 * 1024
		|| pixels.len != source_width * source_height * channels
		|| width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width * height > 4 * 1024 * 1024 {
		return none
	}
	output := []u8{len: width * height * channels}
	scan := ImageResizeScan{
		source:        pixels
		target:        output
		source_width:  source_width
		source_height: source_height
		width:         width
		scale_x:       f32(source_width) / f32(width)
		scale_y:       f32(source_height) / f32(height)
		format:        format
	}
	run_raster_scans(&scan, height, width, scan_image_resize)
	return output
}

fn scan_image_resize(context voidptr, first i32, end i32) {
	scan := unsafe { &ImageResizeScan(context) }
	if scan.format == .rgba {
		scan.resize_rgba_rows(int(first), int(end))
	} else {
		scan.resize_single_channel_rows(int(first), int(end))
	}
}

fn (scan &ImageResizeScan) resize_rgba_rows(first int, end int) {
	shader := ImageShader{
		pixels: scan.source
		width:  scan.source_width
		height: scan.source_height
		stride: scan.source_width
	}
	// Each worker keeps a local array header and writes only its assigned rows.
	mut target := unsafe { scan.target }
	for y in first .. end {
		cy := (f32(y) + f32(.5)) * scan.scale_y
		for x in 0 .. scan.width {
			color := shader.lowp_bilerp((f32(x) + f32(.5)) * scan.scale_x, cy)
			offset := (y * scan.width + x) * 4
			for c in 0 .. 4 {
				target[offset + c] = u8(color[c])
			}
		}
	}
}
