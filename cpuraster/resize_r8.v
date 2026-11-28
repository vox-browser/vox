module cpuraster

// R8 image planes use the highp raster pipeline: normalize bytes,
// accumulate four bilinear taps with fused multiply-add, then store to UNORM8.
// The RGBA8 lowp sampler has different intermediate rounding.
pub fn resize_r8(pixels []u8, source_width int, source_height int, width int, height int) ?[]u8 {
	return resize_image_pixels(pixels, source_width, source_height, width, height, .r8)
}

fn (scan &ImageResizeScan) resize_single_channel_rows(first int, end int) {
	mut target := unsafe { scan.target }
	for y in first .. end {
		cy := (f32(y) + .5) * scan.scale_y
		fy := fract_f32(cy + .5)
		for x in 0 .. scan.width {
			cx := (f32(x) + .5) * scan.scale_x
			fx := fract_f32(cx + .5)
			mut value := f32(0)
			for row in 0 .. 2 {
				oy := if row == 0 { f32(-.5) } else { f32(.5) }
				wy := if row == 0 { f32(1) - fy } else { fy }
				py := int(fmin(fmax(cy + oy, 0), f32(scan.source_height - 1)))
				for col in 0 .. 2 {
					ox := if col == 0 { f32(-.5) } else { f32(.5) }
					wx := if col == 0 { f32(1) - fx } else { fx }
					px := int(fmin(fmax(cx + ox, 0), f32(scan.source_width - 1)))
					sample := f32(scan.source[py * scan.source_width + px]) * f32(1.0 / 255.0)
					scale := wx * wy
					value = mad(scale, sample, value)
				}
			}
			pixel := FloatPixel{r: value, g: value, b: value, a: 1}
			stored := if scan.format == .gray8 { pixel.luminance() } else { value }
			target[y * scan.width + x] = u8(to_unorm(stored, 255))
		}
	}
}
