module yuv

// Scaled YUV uploads promote chroma to 4:4:4. Pack independent byte planes
// without converting their colors; RGB clipping must follow texture filtering.
pub fn webp_minified_upload(planes []u8, width int, height int, tw int, th int) ?[]u8 {
	if !webp_minified_upload_supported(width, height, tw, th) { return none }

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

// Chromium rounds both dimensions up from the same power-of-two decode level.
// A rounded dimension need not divide its source exactly.
pub fn webp_minified_upload_supported(width int, height int, tw int, th int) bool {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width * height > 4 * 1024 * 1024 || width % 2 != 0 || height % 2 != 0
		|| tw <= 0 || th <= 0 || tw > width / 2 || th > height / 2 { return false }
	for divisor := 2; divisor <= 4096; divisor *= 2 {
		w, h := (width + divisor - 1) / divisor, (height + divisor - 1) / divisor
		if tw == w && th == h { return true }
		if w < tw || h < th { return false }
	}
	return false
}
