module cpuraster

// Single-channel image planes use the highp raster pipeline: normalize bytes,
// accumulate four bilinear taps with fused multiply-add, then store to UNORM8.
// The RGBA8 lowp sampler has different intermediate rounding.
pub fn resize_r8(pixels []u8, source_width int, source_height int, width int, height int) ?[]u8 {
	if source_width <= 0 || source_height <= 0 || source_width > 4096 || source_height > 4096
		|| source_width * source_height > 4 * 1024 * 1024 || pixels.len != source_width * source_height
		|| width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width * height > 4 * 1024 * 1024 {
		return none
	}
	sx, sy := f32(source_width) / width, f32(source_height) / height
	mut output := []u8{len: width * height}
	for y in 0 .. height {
		for x in 0 .. width {
			cx, cy := (f32(x) + .5) * sx, (f32(y) + .5) * sy
			fx, fy := fract_f32(cx + .5), fract_f32(cy + .5)
			mut value := f32(0)
			for row in 0 .. 2 {
				oy := if row == 0 { f32(-.5) } else { f32(.5) }
				wy := if row == 0 { f32(1) - fy } else { fy }
				py := int(fmin(fmax(cy + oy, 0), f32(source_height - 1)))
				for col in 0 .. 2 {
					ox := if col == 0 { f32(-.5) } else { f32(.5) }
					wx := if col == 0 { f32(1) - fx } else { fx }
					px := int(fmin(fmax(cx + ox, 0), f32(source_width - 1)))
					sample := f32(pixels[py * source_width + px]) * f32(1.0 / 255.0)
					scale := wx * wy
					value = mad(scale, sample, value)
				}
			}
			output[y * width + x] = u8(to_unorm(value, 255))
		}
	}
	return output
}
