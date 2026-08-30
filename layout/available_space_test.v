module layout

import css

// AvailableSize and AvailableSpace are the self-contained constraint value
// types shared by the translated formatting-context algorithms.

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

fn test_available_size_preserves_upstream_sentinel_values_and_ordering() {
	min_content := AvailableSize.make_min_content()
	max_content := AvailableSize.make_max_content()
	indefinite := AvailableSize.make_indefinite()
	definite := AvailableSize.make_definite(px(100))

	assert min_content.value.raw_value() == 0
	assert max_content.value.raw_value() == css.CSSPixels.max().raw_value()
	assert indefinite.value.raw_value() == css.CSSPixels.max().raw_value()
	assert min_content.less_than(definite)
	assert definite.less_than(max_content)
	assert !max_content.less_than(indefinite)
}

fn test_available_space_and_to_string() {
	space := AvailableSpace.new(AvailableSize.make_definite(px(100)),
		AvailableSize.make_max_content())
	assert space.width.is_definite()
	assert space.height.is_max_content()

	assert AvailableSize.make_min_content().to_string() == 'min-content'
	assert AvailableSize.make_indefinite().to_string() == 'indefinite'
	assert AvailableSize.make_definite(px(10)).to_string() == 'definite(10)'
	assert space.to_string() == 'definite(100) x max-content'
}

fn test_static_position_rect_alignment() {
	rect := css.CSSPixelRect.new(10, 20, 100, 80)
	size := css.CSSPixelSize.from_values(20, 10)
	centered := StaticPositionRect{
		rect:                 rect
		horizontal_alignment: .center
		vertical_alignment:   .center
	}.aligned_position_for_box_with_size(size)
	assert centered.x().to_double() == 50
	assert centered.y().to_double() == 55
	ended := StaticPositionRect{
		rect:                 rect
		horizontal_alignment: .end
		vertical_alignment:   .end
	}.aligned_position_for_box_with_size(size)
	assert ended.x().to_double() == 90
	assert ended.y().to_double() == 90
}
