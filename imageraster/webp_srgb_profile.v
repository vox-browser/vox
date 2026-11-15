module imageraster

import math

// A conservative subset of SkColorSpace's sRGB canonicalization: RGB/XYZ
// matrix profiles with parametric sRGB curves. Inspect the numerical tags,
// never the profile's description, producer, date or encoded-image identity.
// LUTs, CICP and other transfer functions keep the color-managed decoder.
pub fn webp_lossless_srgb_profile(bytes []u8) bool {
	if bytes.len < 30 || bytes[..4].bytestr() != 'RIFF'
		|| bytes[8..16].bytestr() != 'WEBPVP8X' || webp_le32(bytes, 16) != 10
		|| u64(webp_le32(bytes, 4)) + 8 != u64(bytes.len)
		|| bytes[20] & 32 == 0 || bytes[20] & 0xc3 != 0
		|| bytes[21..24] != [u8(0), 0, 0] { return false }
	mut profile, mut image := false, false
	mut at := 30
	for at + 8 <= bytes.len {
		size := u64(webp_le32(bytes, at + 4))
		end := u64(at) + 8 + size
		if end + (size & 1) > u64(bytes.len) { return false }
		kind := bytes[at..at + 4].bytestr()
		if kind == 'ICCP' {
			if profile || image || size > 16 * 1024 * 1024
				|| !icc_matrix_is_srgb(bytes[at + 8..int(end)]) { return false }
			profile = true
		} else if kind == 'VP8L' {
			if image || size < 5 || bytes[at + 8] != 0x2f
				|| bytes[at + 12] & 0xe0 != 0 { return false }
			image = true
		} else if kind !in ['EXIF', 'XMP '] {
			return false
		}
		at = int(end + (size & 1))
	}
	return at == bytes.len && profile && image
}

fn webp_le32(bytes []u8, at int) u32 {
	return u32(bytes[at]) | u32(bytes[at + 1]) << 8 | u32(bytes[at + 2]) << 16
		| u32(bytes[at + 3]) << 24
}

fn icc_fixed(bytes []u8, at int) f32 {
	return f32(i32(png_u32(bytes, at))) / 65536
}

fn icc_matrix_is_srgb(bytes []u8) bool {
	if bytes.len < 132 || png_u32(bytes, 0) != u32(bytes.len)
		|| bytes[8] !in [u8(2), 4] || bytes[12..16].bytestr() !in ['mntr', 'scnr']
		|| bytes[16..24].bytestr() != 'RGB XYZ ' || bytes[36..40].bytestr() != 'acsp'
		|| png_u32(bytes, 64) > 3 { return false }
	count := u64(png_u32(bytes, 128))
	table_end := 132 + count * 12
	if count > 1024 || table_end > u64(bytes.len) { return false }
	// Column-major sRGB-to-XYZD50, using Skia/skcms's ICC fixed-point matrix.
	xyz := [f32(0.436065674), 0.222488403, 0.013916016,
		0.385147095, 0.716873169, 0.097076416,
		0.143066406, 0.060607910, 0.714096069]!
	mut seen := u32(0)
	mut tags := map[string]bool{}
	for i in 0 .. int(count) {
		at := 132 + 12 * i
		kind := bytes[at..at + 4].bytestr()
		start, size := u64(png_u32(bytes, at + 4)), u64(png_u32(bytes, at + 8))
		if start < table_end || start & 3 != 0 || size < 8 || start + size > u64(bytes.len)
			|| kind in tags { return false }
		tags[kind] = true
		// Avoid overriding higher-priority color representations or LUTs.
		if kind in ['A2B0', 'A2B1', 'A2B2', 'B2A0', 'B2A1', 'B2A2', 'D2B0',
			'D2B1', 'D2B2', 'D2B3', 'B2D0', 'B2D1', 'B2D2', 'B2D3', 'cicp'] {
			return false
		}
		data := bytes[int(start)..int(start + size)]
		if kind in ['rXYZ', 'gXYZ', 'bXYZ'] {
			column := if kind == 'rXYZ' { 0 } else if kind == 'gXYZ' { 1 } else { 2 }
			if size != 20 || data[..8] != 'XYZ \x00\x00\x00\x00'.bytes() { return false }
			for row in 0 .. 3 {
				if math.abs(icc_fixed(data, 8 + row * 4) - xyz[column * 3 + row]) >= f32(1.0 / 4096) { return false }
			}
			seen |= u32(1) << column
		} else if kind in ['rTRC', 'gTRC', 'bTRC'] {
			if !icc_parametric_is_srgb(data) { return false }
			seen |= if kind == 'rTRC' { u32(8) } else if kind == 'gTRC' { u32(16) } else { u32(32) }
		}
	}
	return seen == 63
}

fn icc_parametric_is_srgb(bytes []u8) bool {
	if bytes.len < 12 || bytes[..8] != 'para\x00\x00\x00\x00'.bytes()
		|| bytes[8] != 0 || bytes[9] !in [u8(3), 4] || bytes[10] != 0 || bytes[11] != 0 {
		return false
	}
	count := if bytes[9] == 3 { 5 } else { 7 }
	if bytes.len != 12 + 4 * count { return false }
	expected := [f32(2.4), f32(1.0 / 1.055), f32(0.055 / 1.055), f32(1.0 / 12.92), 0.04045, 0, 0]!
	for i in 0 .. count {
		// Stricter than SkColorSpace's 0.001 coefficient comparison.
		if math.abs(icc_fixed(bytes, 12 + 4 * i) - expected[i]) >= f32(1.0 / 4096) { return false }
	}
	return true
}
