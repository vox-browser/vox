module yuv

// Plane decoding does not rotate EXIF pixels. Decline non-default or malformed
// orientation metadata before choosing that paint representation.
pub fn jpeg_plane_orientation_supported(bytes []u8) bool {
	if bytes.len < 4 || bytes[0] != 255 || bytes[1] != 216 { return false }
	mut p := 2
	for p + 1 < bytes.len {
		if bytes[p] != 255 { return false }
		for p < bytes.len && bytes[p] == 255 { p++ }
		if p >= bytes.len { return false }
		marker := bytes[p]
		p++
		if marker == 218 || marker == 217 { return true }
		if p + 2 > bytes.len { return false }
		size := int(bytes[p]) * 256 + int(bytes[p + 1])
		if size < 2 || size > bytes.len - p { return false }
		data := bytes[p + 2..p + size]
		if marker == 225 {
			if data.len < 14 || data[..6] != [u8(69), 120, 105, 102, 0, 0] { return false }
			t := data[6..]
			little := t[0] == 73 && t[1] == 73
			if !little && !(t[0] == 77 && t[1] == 77) { return false }
			if jpeg_exif_word(t, 2, little) != 42 { return false }
			offset := jpeg_exif_long(t, 4, little)
			if offset < 8 || offset > u32(t.len - 2) { return false }
			count := jpeg_exif_word(t, int(offset), little)
			if int(count) > (t.len - int(offset) - 2) / 12 { return false }
			for i in 0 .. int(count) {
				at := int(offset) + 2 + i * 12
				if jpeg_exif_word(t, at, little) == 274 {
					if jpeg_exif_word(t, at + 2, little) != 3 || jpeg_exif_long(t, at + 4, little) != 1
						|| jpeg_exif_word(t, at + 8, little) != 1 {
						return false
					}
				}
			}
		}
		p += size
	}
	return false
}

fn jpeg_exif_word(b []u8, p int, little bool) u16 {
	return if little { u16(b[p]) | u16(b[p + 1]) << 8 } else { u16(b[p]) << 8 | u16(b[p + 1]) }
}

fn jpeg_exif_long(b []u8, p int, little bool) u32 {
	return if little {
		u32(b[p]) | u32(b[p + 1]) << 8 | u32(b[p + 2]) << 16 | u32(b[p + 3]) << 24
	} else {
		u32(b[p]) << 24 | u32(b[p + 1]) << 16 | u32(b[p + 2]) << 8 | u32(b[p + 3])
	}
}
