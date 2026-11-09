module cpuraster

import crypto.sha256

fn test_inner_shadow_preserves_rounded_content_and_hole() {
	content := rounded_rect(Rect{4, 4, 28, 28}, [f32(8), 8, 8, 8, 8, 8, 8, 8]!)
	inner := rounded_rect(Rect{8, 8, 24, 24}, [f32(4), 4, 4, 4, 4, 4, 4, 4]!)
	pixels := rasterize_inner_shadow(32, 32, rounded_rect(Rect{0, 0, 32, 32}, [8]f32{}),
		inner, content, [f32(1), 0, 0, 1, 0, 0]!, 0xff0000ff, 4, []) or { panic('inner shadow') }
	assert pixels[(4 * 32 + 4)*4+3] == 0
	assert pixels[(16 * 32 + 6)*4+3] > 180
	assert pixels[(16 * 32 + 10)*4+3] > 0
	assert pixels[(16 * 32 + 16)*4+3] == 0
}

fn test_inner_shadow_joins_nearly_degenerate_contour_edges() {
	r := rounded_rect(Rect{-11.881291, 55.24685, f32(-11.881291) + f32(50.11394),
		f32(55.24685) + f32(25.078695)}, [f32(5.1424384), 2.165244, 28.41053, 16.73715,
		33.31346, 11.266986, 7.164704, 37.8889]!)
	path := shadow_boolean_contour(r)
	assert path.verbs == [.move, .conic, .conic, .line, .conic, .line, .conic, .line, .close]
	assert path.points[0] == Point{-8.661509, 55.24685}
	assert path.points[2] == Point{-11.881291, 56.602554}
}

fn test_inner_shadow_declines_intersecting_contours() {
	outer := rounded_rect(Rect{0, 0, 10, 10}, [8]f32{})
	inner := rounded_rect(Rect{5, 0, 15, 10}, [8]f32{})
	if _ := rasterize_inner_shadow(20, 20, outer, inner, outer,
		[f32(1), 0, 0, 1, 0, 0]!, 0xff000000, 4, []) { assert false }
}

fn inner_shadow_test_rect(values []f32) RoundedRect {
	return rounded_rect(Rect{values[0], values[1], values[0] + values[2], values[1] + values[3]},
		[values[4], values[5], values[6], values[7], values[8], values[9], values[10], values[11]]!)
}

fn test_nested_rounded_outer_shadows_match_native_paths() {
	outers := [
		[f32(-8), -8, 80, 72, 16, 16, 16, 16, 16, 16, 16, 16],
		[f32(0), 0, 64, 56, 18, 14, 12, 20, 22, 14, 16, 18],
		[f32(-5), -5, 74, 66, 37, 33, 37, 33, 37, 33, 37, 33],
		[f32(3.25), 4.5, 54, 45, 13, 9, 11, 16, 12, 14, 8, 10],
		[f32(3.25), 4.5, 54, 45, 13, 9, 11, 16, 12, 14, 8, 10],
		[f32(4), 4, 56, 48, 28, 24, 28, 24, 28, 24, 28, 24],
	]
	inners := [
		[f32(12), 10, 40, 30, 8, 6, 7, 4, 3, 9, 10, 5],
		[f32(10), 10, 44, 36, 8, 8, 8, 8, 8, 8, 8, 8],
		[f32(15), 12, 34, 30, 10, 10, 10, 10, 10, 10, 10, 10],
		[f32(16), 16, 28, 20, 5, 5, 5, 5, 5, 5, 5, 5],
		[f32(6.25), 7.5, 48, 39, 10, 6, 8, 13, 9, 11, 5, 7],
		[f32(6), 6, 52, 44, 26, 22, 26, 22, 26, 22, 26, 22],
	]
	contents := [
		[f32(4), 4, 56, 44, 9, 11, 9, 11, 9, 11, 9, 11],
		outers[1],
		[f32(2), 2, 60, 48, 12, 12, 12, 12, 12, 12, 12, 12],
		outers[3], outers[4], outers[5],
	]
	colors := [u32(0x804080c0), 0xc0e04010, 0xff204080, 0x80ff00ff, 0xc0306090, 0x804080c0]
	blurs := [f32(4), 6.5, 3, 0, 4, 6]
	hashes := $if linux {
		['883f172b4d99012d', 'ffe733dccd5bd96f', '55ca45b11915426a',
		 '0eb29f0256d0c181', '6a1d6087eca72401', 'b1515516d61cae7c']
	} $else {
		['62b9e388d577040d', '33844d7d5e684240', 'e8859d5d90b39fe9',
		 '0eb29f0256d0c181', 'dd6fbeed97c40dc1', 'c5b95d2f6b2d939b']
	}
	for i, values in outers {
		transform := if i == 1 { [f32(1.25), 0, 0, .75, 2, 4]! }
			else if i == 2 { [f32(.9), .4, -.4, .9, 5, 2]! }
			else { [f32(1), 0, 0, 1, 0, 0]! }
		pixels := rasterize_inner_shadow(64, 56, inner_shadow_test_rect(values),
			inner_shadow_test_rect(inners[i]), inner_shadow_test_rect(contents[i]), transform,
			colors[i], blurs[i], []) or { panic('rounded inner shadow fixture ${i}') }
		assert sha256.sum(pixels).hex()[..16] == hashes[i], 'rounded inner shadow fixture ${i}'
	}
}

fn test_inner_shadow_declines_intersecting_rounded_corners() {
	outer := rounded_rect(Rect{0, 0, 20, 20}, [f32(10), 10, 10, 10, 10, 10, 10, 10]!)
	inner := rounded_rect(Rect{1, 1, 19, 19}, [f32(1), 1, 1, 1, 1, 1, 1, 1]!)
	if _ := rasterize_inner_shadow(20, 20, outer, inner, outer,
		[f32(1), 0, 0, 1, 0, 0]!, 0xff000000, 4, []) { assert false }
}
