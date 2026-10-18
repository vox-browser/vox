module layout

import css

fn cumulative_offset_raw_point(x int, y int) css.CSSPixelPoint {
	return css.CSSPixelPoint.new(CSSPixels.from_raw(x), CSSPixels.from_raw(y))
}

fn cumulative_offset_chain(points []css.CSSPixelPoint) &UsedValues {
	assert points.len > 0
	mut node := &UsedValues{offset:points[0]}
	for point in points[1..] {
		node = &UsedValues{offset:point,containing_block_used_values_:node}
	}
	return node
}

fn test_cumulative_offsets_preserve_root_to_leaf_saturation_order() {
	hi, lo := css.CSSPixels.max().raw_value(), css.CSSPixels.min().raw_value()
	cases := [
		[cumulative_offset_raw_point(hi - 2, lo + 2), cumulative_offset_raw_point(50, -50),
			cumulative_offset_raw_point(-60, 60)],
		[cumulative_offset_raw_point(lo, hi), cumulative_offset_raw_point(0, 0)],
		[cumulative_offset_raw_point(hi, lo), cumulative_offset_raw_point(hi, lo),
			cumulative_offset_raw_point(lo, hi)],
		[cumulative_offset_raw_point(1, -1), cumulative_offset_raw_point(-2, 3),
			cumulative_offset_raw_point(4, -5)],
	]
	for points in cases {
		mut expected := points[0]
		for point in points[1..] {
			expected = expected.plus(point)
		}
		assert cumulative_offset_chain(points).cumulative_offset() == expected
	}
	first := cumulative_offset_chain(cases[0]).cumulative_offset()
	assert first.x().raw_value() == hi - 60
	assert first.y().raw_value() == lo + 60
}

fn test_cumulative_offsets_match_ordered_fixed_point_addition_for_mixed_chains() {
	mut seed := u32(0x12345678)
	for sample in 0 .. 400 {
		mut points := []css.CSSPixelPoint{}
		for _ in 0 .. 1 + sample % 24 {
			seed = seed * u32(1664525) + u32(1013904223)
			x := if ((seed >> 16) & 7) == 0 {
				css.CSSPixels.max().raw_value()
			} else {
				int(seed % 1000001) - 500000
			}
			seed = seed * u32(1664525) + u32(1013904223)
			y := if ((seed >> 16) & 7) == 1 {
				css.CSSPixels.min().raw_value()
			} else {
				int(seed % 1000001) - 500000
			}
			points << cumulative_offset_raw_point(x, y)
		}
		mut expected := points[0]
		for point in points[1..] {
			expected = expected.plus(point)
		}
		assert cumulative_offset_chain(points).cumulative_offset() == expected
	}
}

fn test_deep_cumulative_offsets_and_live_ancestor_updates_do_not_retain_cached_positions() {
	mut root := &UsedValues{
		offset: cumulative_offset_raw_point(7, -11)
	}
	mut leaf := root
	for _ in 0 .. 4096 {
		leaf = &UsedValues{
			offset:                        cumulative_offset_raw_point(3, -5)
			containing_block_used_values_: leaf
		}
	}
	assert leaf.cumulative_offset() == cumulative_offset_raw_point(7 + 4096 * 3, -11 - 4096 * 5)
	root.set_content_offset(cumulative_offset_raw_point(-23, 41))
	assert leaf.cumulative_offset() == cumulative_offset_raw_point(-23 + 4096 * 3, 41 - 4096 * 5)
	mut alternate := &UsedValues{
		offset: cumulative_offset_raw_point(100, 200)
	}
	root.containing_block_used_values_ = alternate
	assert leaf.cumulative_offset() == cumulative_offset_raw_point(77 + 4096 * 3, 241 - 4096 * 5)
}
