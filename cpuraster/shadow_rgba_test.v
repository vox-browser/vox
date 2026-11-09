module cpuraster

import crypto.sha256

fn shadow_rgba_rect(values []f32) RoundedRect {
	return rounded_rect(Rect{values[0], values[1], values[0] + values[2], values[1] + values[3]},
		[values[4], values[5], values[6], values[7], values[8], values[9], values[10], values[11]]!)
}

fn test_faint_shadows_use_the_native_rgba_surface_blender() {
	identity := [f32(1), 0, 0, 1, 0, 0]!
	outer := shadow_rgba_rect([f32(6.9186826), 29.3462, 9.195145, 66.073654,
		0, 0, 0, 0, 0, 0, 0, 0])
	inner := shadow_rgba_rect([f32(8.042617), 30.470135, 6.947276, 63.825783,
		100, 100, 100, 100, 100, 100, 100, 100])
	inside := rasterize_inner_shadow(15, 64, outer, inner, inner, identity, 761568228,
		19.790783, []) or { panic('faint inner shadow') }
	assert sha256.sum(inside).hex()[..16] == $if linux { 'deeb6f65e7b5859b' }
		$else { '4b3523909177b292' }
	out := rasterize_outer_shadow(64, 56,
		shadow_rgba_rect([f32(8), 6, 40, 32, 10, 10, 10, 10, 10, 10, 10, 10]),
		shadow_rgba_rect([f32(12), 10, 32, 24, 8, 8, 8, 8, 8, 8, 8, 8]),
		identity, 243986327, 18.73592, []) or { panic('faint outer shadow') }
	assert sha256.sum(out).hex()[..16] == $if linux { '7badb3a3a761b5b0' }
		$else { '97275a5983102543' }
}
