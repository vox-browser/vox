module yuv

import math

// JPEG's full-range BT.601 conversion with texture-style bilinear chroma
// sampling at luma pixel centers. This differs from libjpeg's fancy RGB
// upsampler. Planes are packed Y, Cb, Cr without stride padding. This
// slice accepts even 4:2:0 dimensions and full-resolution 4:4:4 planes.
pub fn jpeg_bilinear_rgba(planes []u8, width int, height int, subsampled bool) ?[]u8 {
	if width <= 0 || height <= 0 || width > 32768 || height > 32768
		|| (subsampled && (width % 2 != 0 || height % 2 != 0)) {
		return none
	}
	cw := if subsampled { (width + 1) / 2 } else { width }
	ch := if subsampled { (height + 1) / 2 } else { height }
	ys, cs := width * height, cw * ch
	if planes.len != ys + 2 * cs || ys > 64 * 1024 * 1024 { return none }
	mut out := []u8{len: ys * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			yy := f64(planes[y * width + x])
			u := jpeg_chroma_sample(planes[ys..ys + cs], cw, ch, x, y, width, height) - 128
			v := jpeg_chroma_sample(planes[ys + cs..], cw, ch, x, y, width, height) - 128
			i := (y * width + x) * 4
			out[i] = jpeg_rgb_byte(yy + 1.402 * v)
			out[i + 1] = jpeg_rgb_byte(yy - 0.344136 * u - 0.714136 * v)
			out[i + 2] = jpeg_rgb_byte(yy + 1.772 * u)
			out[i + 3] = 255
		}
	}
	return out
}

fn jpeg_rgb_byte(v f64) u8 { return u8(math.max(0, math.min(255, math.floor(v + 0.5)))) }

fn jpeg_chroma_sample(plane []u8, cw int, ch int, x int, y int, w int, h int) f64 {
	xx, yy := (f64(x) + 0.5) * f64(cw) / f64(w) - 0.5, (f64(y) + 0.5) * f64(ch) / f64(h) - 0.5
	ix, iy := int(math.floor(xx)), int(math.floor(yy))
	a, b := xx - f64(ix), yy - f64(iy)
	x0, x1 := math.max(0, math.min(cw - 1, ix)), math.max(0, math.min(cw - 1, ix + 1))
	y0, y1 := math.max(0, math.min(ch - 1, iy)), math.max(0, math.min(ch - 1, iy + 1))
	return (f64(plane[y0 * cw + x0]) * (1 - a) + f64(plane[y0 * cw + x1]) * a) * (1 - b) + (f64(plane[y1 * cw + x0]) * (1 - a) + f64(plane[y1 * cw + x1]) * a) * b
}

// Keep full-range JPEG RGB fractional until a painter combines it with clip
// coverage. An intermediate 8-bit RGB store changes photographic edge colors.
pub fn jpeg_bilinear_colors(planes []u8, width int, height int, subsampled bool) ?[]f32 {
	if width <= 0 || height <= 0 || width > 32 || height > 32 || width * height > 256
		|| (subsampled && (width % 2 != 0 || height % 2 != 0)) {
		return none
	}
	cw := if subsampled { width / 2 } else { width }
	ch := if subsampled { height / 2 } else { height }
	ys, cs := width * height, cw * ch
	if planes.len != ys + 2 * cs { return none }
	mut colors := []f32{len: ys * 4}
	for y in 0 .. height {
		for x in 0 .. width {
			yy := f64(planes[y * width + x])
			u := jpeg_chroma_sample(planes[ys..ys + cs], cw, ch, x, y, width, height) - 128
			v := jpeg_chroma_sample(planes[ys + cs..], cw, ch, x, y, width, height) - 128
			i := (y * width + x) * 4
			colors[i] = f32(math.max(0, math.min(255, yy + 1.402 * v)) / 255)
			colors[i + 1] = f32(math.max(0, math.min(255, yy - 0.344136 * u - 0.714136 * v)) / 255)
			colors[i + 2] = f32(math.max(0, math.min(255, yy + 1.772 * u)) / 255)
			colors[i + 3] = 1
		}
	}
	return colors
}
