module yuv

// Scaled YUV uploads promote chroma to 4:4:4. Pack independent byte planes
// without converting their colors; RGB clipping must follow texture filtering.
pub fn webp_minified_upload(planes []u8, width int, height int, tw int, th int) ?[]u8 {
	if width % 2 != 0 || height % 2 != 0 || tw <= 0 || th <= 0 || tw > width / 2 || th > height / 2 {
		return none
	}
	if width % tw != 0 || height % th != 0 || width / tw != height / th { return none }
	factor := width / tw
	if factor & (factor - 1) != 0 { return none }
	scaled := jpeg_scaled_planes(planes, width, height, tw, th, true) or { return none }
	size := tw * th
	mut pixels := []u8{len: size * 4}
	for i in 0 .. size {
		pixels[i * 4] = scaled[i]
		pixels[i * 4 + 1] = scaled[size + i]
		pixels[i * 4 + 2] = scaled[size * 2 + i]
		pixels[i * 4 + 3] = 255
	}
	return pixels
}
