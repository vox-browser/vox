module yuv

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
		|| stride < width * 4 {
		return false
	}
	constants := libyuv_constants(.bt601_limited)
	for row in 0 .. height {
		unsafe {
			y_row := y + row * y_stride
			u_row := u + (row >> 1) * u_stride
			v_row := v + (row >> 1) * v_stride
			a_row := if isnil(a) { &u8(nil) } else { a + row * a_stride }
			mut out := output + row * stride
			for x in 0 .. width {
				libyuv_pixel(constants, y_row[x], u_row[x >> 1], v_row[x >> 1], out)
				if !isnil(a_row) {
					out[3] = a_row[x]
				}
				out += 4
			}
		}
	}
	return true
}
