module yuv

import cpuraster

@[inline]
fn libyuv_clamp(value int) u8 {
	shifted := value >> 6
	return if shifted < 0 {
		u8(0)
	} else if shifted > 255 {
		u8(255)
	} else {
		u8(shifted)
	}
}

// i420_bt601_to_rgba converts limited-range BT.601 4:2:0 planes to straight
// R, G, B, A bytes, as libyuv's I420ToABGR does (I420AlphaToABGR without
// attenuation when an alpha plane is given). Each chroma sample covers a 2x2
// block, including the last column and row of odd sizes.
@[direct_array_access]
pub fn i420_bt601_to_rgba(y &u8, y_stride int, u &u8, u_stride int, v &u8, v_stride int, a &u8, a_stride int, output &u8, stride int, width int, height int) bool {
	if isnil(y) || isnil(u) || isnil(v) || isnil(output) || width <= 0 || height <= 0
		|| width > max_int / 4 || stride < width * 4 {
		return false
	}
	scan := I420Conversion{
		y:      I420Plane{y, y_stride}
		u:      I420Plane{u, u_stride}
		v:      I420Plane{v, v_stride}
		a:      I420Plane{a, a_stride}
		output: output
		stride: stride
		width:  width
	}
	if height > 1 && scan.disjoint_output(height) {
		cpuraster.run_raster_scans(&scan, height, width, scan_i420_rows)
	} else {
		scan.convert_rows(0, height)
	}
	return true
}

struct I420Plane {
	pixels &u8
	stride int
}

struct I420Conversion {
	y      I420Plane
	u      I420Plane
	v      I420Plane
	a      I420Plane
	output &u8
	stride int
	width  int
}

// Use the original write order for overlapping buffers and for strides
// outside the native decoder's signed 32-bit metadata range.
fn (scan &I420Conversion) disjoint_output(height int) bool {
	if height > max_i32 || scan.stride > max_i32 {
		return false
	}
	destination := u64(uint(scan.output))
	length := u64(height - 1) * u64(scan.stride) + u64(scan.width) * 4
	cw, ch := scan.width / 2 + scan.width % 2, height / 2 + height % 2
	return !scan.y.overlaps(scan.width, height, destination, length)
		&& !scan.u.overlaps(cw, ch, destination, length)
		&& !scan.v.overlaps(cw, ch, destination, length)
		&& (isnil(scan.a.pixels) || !scan.a.overlaps(scan.width, height, destination, length))
}

fn (plane I420Plane) overlaps(width int, height int, destination u64, length u64) bool {
	if plane.stride < min_i32 || plane.stride > max_i32 {
		return true
	}
	offset := i64(height - 1) * i64(plane.stride)
	address := u64(uint(plane.pixels))
	start := if offset < 0 { address - u64(-offset) } else { address }
	extent := u64(width) + (if offset < 0 { u64(-offset) } else { u64(offset) })
	return if start <= destination {
		destination - start < extent
	} else {
		start - destination < length
	}
}

fn scan_i420_rows(context voidptr, first i32, end i32) {
	scan := unsafe { &I420Conversion(context) }
	scan.convert_rows(int(first), int(end))
}

@[direct_array_access]
fn (scan &I420Conversion) convert_rows(first int, end int) {
	constants := libyuv_constants(.bt601_limited)
	for row in first .. end {
		unsafe {
			y_row := scan.y.pixels + row * scan.y.stride
			u_row := scan.u.pixels + (row >> 1) * scan.u.stride
			v_row := scan.v.pixels + (row >> 1) * scan.v.stride
			a_row := if isnil(scan.a.pixels) {
				&u8(nil)
			} else {
				scan.a.pixels + row * scan.a.stride
			}
			mut out := scan.output + row * scan.stride
			for x in 0 .. scan.width {
				libyuv_pixel(constants, y_row[x], u_row[x >> 1], v_row[x >> 1], out)
				if !isnil(a_row) {
					out[3] = a_row[x]
				}
				out += 4
			}
		}
	}
}
