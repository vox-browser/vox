module cpuraster

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
