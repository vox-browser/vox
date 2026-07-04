module layout

import css

// The layout module is a large, mostly-stubbed translation of LibWeb/Layout (real layout depends on
// computed style, which is not ported yet). AvailableSize/AvailableSpace, however, are self-contained
// value types with real logic — this is the layout module's first runtime test.

fn px(value int) css.CSSPixels {
	return css.CSSPixels.new(value)
}

fn test_available_size_predicates() {
	definite := AvailableSize.make_definite(px(100))
	assert definite.is_definite()
	assert !definite.is_intrinsic_sizing_constraint()
	assert definite.to_px_or_zero().raw_value() == px(100).raw_value()

	min_content := AvailableSize.make_min_content()
	assert min_content.is_min_content()
	assert min_content.is_intrinsic_sizing_constraint()
	assert min_content.to_px_or_zero().raw_value() == 0

	max_content := AvailableSize.make_max_content()
	assert max_content.is_max_content()
	assert max_content.is_intrinsic_sizing_constraint()

	indefinite := AvailableSize.make_indefinite()
	assert indefinite.is_indefinite()
	assert !indefinite.is_intrinsic_sizing_constraint()
	assert indefinite.to_px_or_zero().raw_value() == 0
}

fn test_definite_comparisons() {
	d := AvailableSize.make_definite(px(100))
	assert d.px_is_less(px(50)) // 50 < definite(100)
	assert !d.px_is_less(px(150))
	assert d.px_is_greater(px(150)) // 150 > definite(100)
	assert !d.px_is_greater(px(50))
	assert d.is_less_than_px(px(150)) // definite(100) < 150
	assert !d.is_less_than_px(px(50))
}

fn test_min_content_is_smallest() {
	mn := AvailableSize.make_min_content()
	// Nothing is smaller than min-content; everything exceeds it.
	assert !mn.px_is_less(px(100))
	assert mn.px_is_greater(px(100))
	assert mn.is_less_than_px(px(100))
}

fn test_max_content_and_indefinite_are_largest() {
	for largest in [AvailableSize.make_max_content(), AvailableSize.make_indefinite()] {
		// Everything is smaller than max-content / an indefinite size.
		assert largest.px_is_less(px(100))
		assert !largest.px_is_greater(px(100))
		assert !largest.is_less_than_px(px(100))
	}
}

fn test_available_space_and_to_string() {
	space := AvailableSpace.new(AvailableSize.make_definite(px(100)), AvailableSize.make_max_content())
	assert space.width.is_definite()
	assert space.height.is_max_content()

	assert AvailableSize.make_min_content().to_string() == 'min-content'
	assert AvailableSize.make_indefinite().to_string() == 'indefinite'
	assert AvailableSize.make_definite(px(10)).to_string() == '10.00px'
	assert space.to_string() == 'AvailableSpace(width: 100.00px, height: max-content)'
}
