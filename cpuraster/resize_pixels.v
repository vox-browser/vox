module cpuraster

// A decoded-image upload uses the same Q15 bilinear sampler as an 8-bit
// raster-pipeline image shader, including its intermediate rounding.
pub fn resize_premultiplied_rgba(pixels []u8, source_width int, source_height int,
	width int, height int) ?[]u8 {
	if source_width <= 0 || source_height <= 0 || source_width > 4096 || source_height > 4096
		|| source_width * source_height > 4 * 1024 * 1024 || pixels.len != source_width * source_height * 4
		|| width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width * height > 4 * 1024 * 1024 {
		return none
	}
	shader := ImageShader{ pixels: pixels, width: source_width, height: source_height, stride: source_width }
	sx, sy := f32(source_width) / f32(width), f32(source_height) / f32(height)
	mut output := []u8{len: width * height * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			color := shader.lowp_bilerp((f32(x) + f32(.5)) * sx, (f32(y) + f32(.5)) * sy)
			for c in 0 .. 4 { output[(y * width + x) * 4 + c] = u8(color[c]) }
		}
	}
	return output
}
