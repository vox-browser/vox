module layout

import svg

fn test_svg_path_projection_memo_hit_matches_fresh_projection() {
	path := svg.parse_path_data('M1 2C3 4 5 6 7 8L9 2Z')
	fresh := compute_svg_path_projection(path, true, true)
	first := svg_path_projection(path, true, true)
	second := svg_path_projection(svg.parse_path_data('M1 2C3 4 5 6 7 8L9 2Z'), true, true)
	for result in [first, second] {
		assert result.serialized == fresh.serialized
		assert result.packed == fresh.packed
		bounds := result.path_bounds or { panic('missing bounds') }
		expected := fresh.path_bounds or { panic('missing fresh bounds') }
		assert bounds == expected
		paint_bounds := result.bounds or { panic('missing paint bounds') }
		expected_paint := fresh.bounds or { panic('missing fresh paint bounds') }
		assert paint_bounds == expected_paint
	}
	assert fresh.packed.len > 0
}

fn test_svg_path_projection_memo_returns_caller_owned_segments() {
	path := svg.parse_path_data('M10 10H20V20H10Z')
	mut first := svg_path_projection(path, false, false)
	expected := first.packed.clone()
	first.packed[0] = -1
	second := svg_path_projection(path, false, false)
	assert second.packed == expected
}

fn test_svg_path_projection_memo_entry_compares_complete_input() {
	path := svg.parse_path_data('M0 0L10 10')
	_ = svg_path_projection(path, false, true)
	entry := svg_path_projection_memo_.entries[svg_path_projection_key(path, false, true)] or {
		panic('path was not memoized')
	}
	assert entry.matches(path, false, true)
	assert !entry.matches(path, true, true)
	assert !entry.matches(path, false, false)
	assert !entry.matches(svg.parse_path_data('M0 0L10 11'), false, true)
	assert !entry.matches(svg.parse_path_data('m0 0L10 10'), false, true)
	assert !entry.matches(svg.parse_path_data('M0 0L10 10L1 1'), false, true)
	assert !entry.matches(svg.parse_path_data('M0 0'), false, true)
}

fn test_svg_path_projection_memo_distinguishes_fill_rule_and_precision() {
	path := svg.parse_path_data('M0.123456789 0L10.987654321 10Z')
	for even_odd in [false, true] {
		for single in [false, true] {
			fresh := compute_svg_path_projection(path, even_odd, single)
			memoized := svg_path_projection(path, even_odd, single)
			assert memoized.packed == fresh.packed
			assert memoized.serialized == fresh.serialized
		}
	}
}
