module yuv

import math

// Chromium's scaled YUV decode promotes chroma to 4:4:4 at the upload size.
// Filter each plane before RGB conversion; filtering converted RGB changes
// both chroma reconstruction and clipping of out-of-gamut samples.
pub fn jpeg_scaled_rgba(planes []u8, width int, height int, target_width int,
	target_height int, subsampled bool) ?[]u8 {
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
	if target_width == width && target_height == height {
		return jpeg_bilinear_rgba(planes, width, height, subsampled)
	}
	mut scaled := jpeg_scale_plane(planes[..ys], width, height, target_width, target_height)
	scaled << jpeg_scale_plane(planes[ys..ys + cs], cw, ch, target_width, target_height)
	scaled << jpeg_scale_plane(planes[ys + cs..], cw, ch, target_width, target_height)
	return jpeg_bilinear_rgba(scaled, target_width, target_height, false)
}

fn jpeg_scale_plane(source []u8, width int, height int, tw int, th int) []u8 {
	mut data := source.clone()
	mut w, mut h := width, height
	ratio := math.max(f64(width) / tw, f64(height) / th)
	mut divisor := 1
	for f64(divisor * 2) <= ratio {
		nw, nh := math.max(1, w / 2), math.max(1, h / 2)
		wx := if w == 1 {
			[1]
		} else if w % 2 == 0 {
			[1, 1]
		} else {
			[1, 2, 1]
		}
		wy := if h == 1 {
			[1]
		} else if h % 2 == 0 {
			[1, 1]
		} else {
			[1, 2, 1]
		}
		mut denominator := 0
		for x in wx {
			for y in wy { denominator += x * y }
		}
		mut next := []u8{len: nw * nh}
		for y in 0 .. nh {
			for x in 0 .. nw {
				mut value := 0
				for dy, yy in wy {
					for dx, xx in wx { value += int(data[(y * 2 + dy) * w + x * 2 + dx]) * xx * yy }
				}
				next[y * nw + x] = u8(value / denominator)
			}
		}
		data = next.clone()
		w = nw
		h = nh
		divisor *= 2
	}
	if w == tw && h == th { return data }
	mut output := []u8{len: tw * th}
	sx, sy := f32(w) / tw, f32(h) / th
	for y in 0 .. th {
		for x in 0 .. tw {
			xx, yy := (f32(x) + .5) * sx - .5, (f32(y) + .5) * sy - .5
			ix, iy := int(math.floor(xx)), int(math.floor(yy))
			fx, fy := xx - ix, yy - iy
			x0, x1 := math.max(0, math.min(w - 1, ix)), math.max(0, math.min(w - 1, ix + 1))
			y0, y1 := math.max(0, math.min(h - 1, iy)), math.max(0, math.min(h - 1, iy + 1))
			top := f32(data[y0 * w + x0]) * (1 - fx) + f32(data[y0 * w + x1]) * fx
			bottom := f32(data[y1 * w + x0]) * (1 - fx) + f32(data[y1 * w + x1]) * fx
			output[y * tw + x] = u8(math.floor(top * (1 - fy) + bottom * fy + .5))
		}
	}
	return output
}
