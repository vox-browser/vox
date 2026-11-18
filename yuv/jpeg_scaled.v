module yuv

import math
import cpuraster

// Preserve independent full-range components until the GPU's final sample.
pub fn jpeg_scaled_upload(planes []u8, width int, height int, tw int, th int, subsampled bool) ?[]u8 {
	scaled := jpeg_scaled_planes(planes, width, height, tw, th, subsampled) or { return none }
	size := tw * th
	mut packed := []u8{len: size * 4}
	for i in 0 .. size {
		packed[i * 4] = scaled[i]
		packed[i * 4 + 1] = scaled[size + i]
		packed[i * 4 + 2] = scaled[size * 2 + i]
		packed[i * 4 + 3] = 255
	}
	return packed
}

// Chromium's scaled YUV decode promotes chroma to 4:4:4 at the upload size.
// Filter each plane before RGB conversion; filtering converted RGB changes
// both chroma reconstruction and clipping of out-of-gamut samples.
pub fn jpeg_scaled_rgba(planes []u8, width int, height int, target_width int,
	target_height int, subsampled bool) ?[]u8 {
	scaled := jpeg_scaled_planes(planes, width, height, target_width, target_height, subsampled) or { return none }
	if target_width == width && target_height == height {
		return jpeg_bilinear_rgba(planes, width, height, subsampled)
	}
	return jpeg_bilinear_rgba(scaled, target_width, target_height, false)
}

// Retain fractional RGB until texture coverage and destination blending.
pub fn jpeg_scaled_colors(planes []u8, width int, height int, tw int, th int, subsampled bool) ?[]f32 {
	scaled := jpeg_scaled_planes(planes, width, height, tw, th, subsampled) or { return none }
	size := tw * th
	mut out := []f32{len: size * 4}
	for i in 0 .. size {
		yy, u, v := f64(scaled[i]), f64(scaled[size + i]) - 128, f64(scaled[size * 2 + i]) - 128
		for c, value in [yy + 1.402 * v, yy - .344136 * u - .714136 * v, yy + 1.772 * u, f64(255)] {
			out[i * 4 + c] = f32(math.max(0, math.min(255, value)) / 255)
		}
	}
	return out
}

fn jpeg_scaled_planes(planes []u8, width int, height int, target_width int, target_height int, subsampled bool) ?[]u8 {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096 || width * height > 4 * 1024 * 1024
		|| target_width <= 0 || target_height <= 0 || target_width > width || target_height > height
		|| (subsampled && (width % 2 != 0 || height % 2 != 0)) {
		return none
	}
	cw, ch := if subsampled { width / 2 } else { width }, if subsampled {
		height / 2
	} else {
		height
	}
	ys, cs := width * height, cw * ch
	if planes.len != ys + 2 * cs { return none }
	mut scaled := jpeg_scale_plane(planes[..ys], width, height, target_width, target_height) or { return none }
	scaled << jpeg_scale_plane(planes[ys..ys + cs], cw, ch, target_width, target_height) or { return none }
	scaled << jpeg_scale_plane(planes[ys + cs..], cw, ch, target_width, target_height) or { return none }
	return scaled
}

fn jpeg_scale_plane(source []u8, width int, height int, tw int, th int) ?[]u8 {
	// Borrow the input until a mip or resize produces its own output.
	mut data := unsafe { source }
	mut w, mut h := width, height
	// Chromium enables Skia's legacy anisotropic mip selection: use the
	// geometric mean, preserving f32 rounding at power-of-two boundaries.
	sx, sy := f32(tw) / f32(width), f32(th) / f32(height)
	scale := f32(math.sqrt(f64(sx * sy)))
	mut divisor := 1
	for f32(divisor * 2) * scale <= 1 {
		data = cpuraster.halve_mipmap_plane(data, w, h)?
		w = math.max(1, w / 2)
		h = math.max(1, h / 2)
		divisor *= 2
	}
	if w == tw && h == th {
		// The caller appends the other planes to this owned array.
		return if divisor == 1 { source.clone() } else { data }
	}
	// SkYUVAPixmapInfo selects Gray8 for single-channel unorm8 CPU planes.
	return cpuraster.resize_gray8(data, w, h, tw, th)
}
