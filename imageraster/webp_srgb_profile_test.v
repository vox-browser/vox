module imageraster

fn srgb_test_icc() []u8 {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/input/decode-alpha-tagged.webp').to_bytes()
	return bytes[38..626].clone()
}

fn srgb_test_put_u32(mut bytes []u8, at int, value u32) {
	for i in 0 .. 4 { bytes[at + i] = u8(value >> ((3 - i) * 8)) }
}

fn srgb_test_tag(bytes []u8, kind string) int {
	for i in 0 .. int(png_u32(bytes, 128)) {
		at := 132 + 12 * i
		if bytes[at..at + 4].bytestr() == kind { return at }
	}
	panic('missing tag ${kind}')
}

fn test_webp_srgb_profile_interprets_numbers_and_rejects_different_primaries_and_curves() {
	icc := srgb_test_icc()
	assert icc_matrix_is_srgb(icc)
	// Descriptions, producer and timestamps are not color-space identity.
	mut renamed := icc.clone()
	for i in 4 .. 8 { renamed[i] = 65 }
	for i in 24 .. 36 { renamed[i] = 0 }
	desc := int(png_u32(icc, srgb_test_tag(icc, 'desc') + 4))
	renamed[desc + 40] ^= 1
	assert icc_matrix_is_srgb(renamed)
	for kind in ['rXYZ', 'gXYZ', 'bXYZ', 'rTRC', 'gTRC', 'bTRC'] {
		mut other := icc.clone()
		start := int(png_u32(icc, srgb_test_tag(icc, kind) + 4))
		// A meaningful numerical change must keep color management enabled.
		other[start + 9] ^= 32
		assert !icc_matrix_is_srgb(other), kind
	}
	// Type 4 with zero offsets describes the same transfer curve as type 3.
	curve_at := int(png_u32(icc, srgb_test_tag(icc, 'rTRC') + 4))
	mut type4 := icc[curve_at..curve_at + 32].clone()
	type4[9] = 4
	type4 << []u8{len: 8}
	assert icc_parametric_is_srgb(type4)
	type4[39] = 255
	assert !icc_parametric_is_srgb(type4)
	for n in 0 .. icc.len { assert !icc_matrix_is_srgb(icc[..n]) }
}

fn test_webp_srgb_profile_rejects_ambiguous_or_unsupported_color_representations() {
	icc := srgb_test_icc()
	for kind in ['A2B0', 'D2B0', 'cicp', 'rXYZ'] {
		mut other := icc.clone()
		for i, v in kind.bytes() { other[132 + i] = v }
		assert !icc_matrix_is_srgb(other)
	}
	for at in [0, 128, srgb_test_tag(icc, 'rXYZ') + 4, srgb_test_tag(icc, 'rXYZ') + 8] {
		mut other := icc.clone()
		srgb_test_put_u32(mut other, at, 0xffffffff)
		assert !icc_matrix_is_srgb(other)
	}
	for at in [8, 12, 16, 20, 36, 64] {
		mut other := icc.clone()
		other[at] = 255
		assert !icc_matrix_is_srgb(other)
	}
}

fn test_webp_srgb_profile_requires_a_complete_static_lossless_container() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/input/decode-alpha-tagged.webp').to_bytes()
	assert webp_lossless_srgb_profile(bytes)
	for n in 0 .. bytes.len { assert !webp_lossless_srgb_profile(bytes[..n]) }
	for at in [0, 4, 8, 12, 16, 21, 30, 34, 626] {
		mut other := bytes.clone()
		other[at] ^= 128
		assert !webp_lossless_srgb_profile(other), '${at}'
	}
	for flag in [u8(0), 2, 16, 34, 128] {
		mut other := bytes.clone()
		other[20] = flag
		assert !webp_lossless_srgb_profile(other)
	}
	assert !webp_lossless_srgb_profile($embed_file('@VMODROOT/Tests/Browser/Brave/input/decode-colors.webp').to_bytes())
	assert !webp_lossless_srgb_profile($embed_file('@VMODROOT/Tests/Browser/Brave/resources/engadget-webp-decode-choice.webp').to_bytes())
}
