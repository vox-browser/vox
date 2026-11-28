// vtest build: macos
module ggshape

import crypto.sha256

fn test_shadow_patch_expansion_matches_scalar_reference() {
	dimension := 205
	patch := []u8{len: dimension * dimension, init: u8(index * 83 + index / 31)}
	// Reference hashes from the original per-pixel coordinate loop. The
	// dimensions straddle the worker cutoff and include an odd row width.
	sizes := [[511, 513]!, [512, 512]!, [1921, 1081]!]
	hashes := [
		'9269ab3c593d975fa8978ea471a42ab202c30b8d124728f6e1dc289816aabfbe',
		'504a540da12c8fb4c5e38d8c9479b861e9e828fa89e61d813c91e3722d6b18ad',
		'3829e889131bc092550eaec875e3090ff1e1dd51aed5a53f5f6a7951f4a06ac4',
	]
	for i, size in sizes {
		w, h := size[0], size[1]
		output := expand_rounded_shadow_patch(patch, dimension, SurfaceRegion{width: w, height: h}, 7.375, -2.625,
			f32(w) * 0.49, f32(h) * 0.492, 102.25)
		assert sha256.sum(output).hex() == hashes[i]
	}
}
