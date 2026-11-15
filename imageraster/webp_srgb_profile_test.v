module imageraster

import os

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

fn test_sampled_srgb_curves_validate_every_knot_and_reject_sparse_or_other_tables() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/cnn/bodies/1f1ea2536d7f4cb1e3d805beab53611f4c990e069f1da6181ebad55725654572').to_bytes()
	icc := bytes[38..38 + int(webp_le32(bytes, 34))]
	assert icc_matrix_is_srgb(icc)
	start := int(png_u32(icc, srgb_test_tag(icc, 'rTRC') + 4))
	size := int(png_u32(icc, srgb_test_tag(icc, 'rTRC') + 8))
	curve := icc[start..start + size]
	assert png_u32(curve, 8) == 1024 && icc_curve_is_srgb(curve)
	for at in [12, 13, 412, 413, curve.len - 2, curve.len - 1] {
		mut other := curve.clone()
		other[at] ^= 64
		assert !icc_curve_is_srgb(other)
	}
	assert !icc_curve_is_srgb(curve[..curve.len - 1])
	mut sparse := []u8{len: 16}
	for i, v in 'curv'.bytes() { sparse[i] = v }
	srgb_test_put_u32(mut sparse, 8, 2)
	sparse[14], sparse[15] = 255, 255
	assert !icc_curve_is_srgb(sparse)
	mut invalid := curve.clone()
	srgb_test_put_u32(mut invalid, 8, 0xffffffff)
	assert !icc_curve_is_srgb(invalid)
}

fn test_opaque_profiled_vp8_is_separate_from_lossless_upload_eligibility() {
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/cnn/bodies/1f1ea2536d7f4cb1e3d805beab53611f4c990e069f1da6181ebad55725654572').to_bytes()
	assert webp_srgb_profile(bytes)
	assert !webp_lossless_srgb_profile(bytes)
	for n in 0 .. bytes.len { assert !webp_srgb_profile(bytes[..n]) }
	for flag in [u8(0), 2, 34, 48, 128] {
		mut other := bytes.clone()
		other[20] = flag
		assert !webp_srgb_profile(other)
	}
	// A real wide-gamut profile must retain color conversion.
	wide := $embed_file('@VMODROOT/Tests/Browser/Brave/sites/cnn/bodies/cfa5c33a248202e173bfc66fa37cc198249a14c392eea81fa08dae7c5099bb7c').to_bytes()
	assert !webp_srgb_profile(wide)
}

// Expected color-space identities come from the independent Skia oracle.
fn test_cnn_profile_catalog_matches_the_independent_srgb_classification() {
	for hash in [
		'fbe3994f267a5bfabc1f8856b9adcce31ba8350b3853265605ecbeadc6a52d12',
		'1f1ea2536d7f4cb1e3d805beab53611f4c990e069f1da6181ebad55725654572',
		'8b5b39bdd93c5525ab3d88ddc0eb79739f88e4341b666fb090eb5ebf462d050d',
		'dca1d1dfbce0412f36084f3d9a5f5416e1df1735890c26d601e88ad942fab7c0',
		'cfa5c33a248202e173bfc66fa37cc198249a14c392eea81fa08dae7c5099bb7c',
		'60ddc0e5c7450627cf98c02875674cb7fca7d665f24ac3213b683dbf1f9be065',
		'5fb5f3df35b17613ca74cdaf3d796b16b68632f28c4b3ee868691944ac276f3f',
		'0ddbc0e11904833e8ca88c7bb43bd0fed4aa3ae436712b3f0063dc91fa0acd65',
		'1ad57c195b052d8af379f8eb0e5d95dbe596440fa99692e400cd5bf62cb64b20',
		'dcb3c564bbcb7261a7b9629eb1ab211a23674224e087935803e5ef5d7dc64d68',
	] {
		bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/sites/cnn/bodies', hash))!
		assert webp_srgb_profile(bytes) == !hash.starts_with('cfa5c33a2482'), hash
		assert !webp_lossless_srgb_profile(bytes), hash
	}
}
