module svg

fn test_numeric_filter_region_defaults_to_padded_object_bounds() {
	filter := Element{tag: 'filter'}
	bounds := Rect{10, 20, 40, 20}
	assert filter.numeric_filter_region(bounds, none)? == Rect{6, 18, 48, 24}
	assert filter.numeric_filter_region(none, none) == none
	assert filter.numeric_filter_region(Rect{10, 20, 40, 0}, none) == none
}

fn test_numeric_filter_region_resolves_object_fractions_and_percentages() {
	filter := Element{
		tag: 'filter'
		attributes: {
			'filterUnits': 'objectBoundingBox'
			'x':           '50%'
			'y':           '0'
			'width':       '50%'
			'height':      '1.5'
		}
	}
	assert filter.numeric_filter_region(Rect{16, 8, 20, 20}, Point{400, 100})? == Rect{26, 8, 10, 30}
}

fn test_numeric_filter_region_keeps_explicit_user_space_coordinates() {
	filter := Element{
		tag: 'filter'
		attributes: {
			'filterUnits': 'userSpaceOnUse'
			'x':           '6'
			'y':           '4'
			'width':       '20'
			'height':      '22'
		}
	}
	assert filter.numeric_filter_region(none, none)? == Rect{6, 4, 20, 22}
}

fn test_numeric_filter_region_resolves_user_space_percentages_by_axis() {
	filter := Element{
		tag: 'filter'
		attributes: {
			'filterUnits': 'userSpaceOnUse'
			'x':           '2%'
			'y':           '8%'
			'width':       '6%'
			'height':      '20'
		}
	}
	assert filter.numeric_filter_region(none, Point{400, 100})? == Rect{8, 8, 24, 20}
	assert filter.numeric_filter_region(Rect{0, 0, 40, 40}, none) == none
	assert filter.numeric_filter_region(none, Point{0, 100}) == none
}

fn test_numeric_filter_region_applies_user_space_percentage_defaults() {
	filter := Element{tag: 'filter', attributes: {'filterUnits': 'userSpaceOnUse'}}
	assert filter.numeric_filter_region(none, Point{400, 100})? == Rect{-40, -10, 480, 120}
}

fn test_numeric_filter_offset_uses_primitive_units_independently_of_region_units() {
	filter := Element{
		tag: 'filter'
		attributes: {
			'filterUnits':    'userSpaceOnUse'
			'primitiveUnits': 'objectBoundingBox'
		}
	}
	primitive := Element{tag: 'feOffset', attributes: {'dx': '0.4', 'dy': '-0.4'}}
	assert filter.numeric_filter_offset(&primitive, Rect{10, 24, 20, 10})? == Point{8, -4}
	assert filter.numeric_filter_offset(&primitive, Rect{4, 0, 30, 20})? == Point{12, -8}
	assert filter.numeric_filter_offset(&primitive, none) == none
	assert filter.numeric_filter_offset(&primitive, Rect{0, 0, 20, 0}) == none
}

fn test_numeric_filter_offset_preserves_user_space_numbers_and_defaults() {
	filter := Element{tag: 'filter'}
	primitive := Element{tag: 'feOffset', attributes: {'dx': '3.5'}}
	assert filter.numeric_filter_offset(&primitive, Rect{0, 0, 20, 10})? == Point{3.5, 0}
	percentage := Element{tag: 'feOffset', attributes: {'dx': '50%'}}
	assert filter.numeric_filter_offset(&percentage, none) == none
}

fn test_numeric_source_filter_subregion_inherits_omitted_coordinates() {
	filter := Element{tag: 'filter'}
	primitive := Element{tag: 'feOffset', attributes: {'x': '5%', 'height': '12%'}}
	region := Rect{4, 4, 32, 24}
	assert filter.numeric_source_filter_subregion(&primitive, region, none, Point{400, 100})? == Rect{20, 4, 32, 12}
	assert filter.numeric_source_filter_subregion(&primitive, region, none, none) == none
	zero := Element{tag: 'feOffset', attributes: {'width': '0'}}
	assert filter.numeric_source_filter_subregion(&zero, region, none, none)? == Rect{4, 4, 0, 24}
}

fn test_numeric_source_filter_subregion_uses_object_coordinates() {
	filter := Element{tag: 'filter', attributes: {'primitiveUnits': 'objectBoundingBox'}}
	primitive := Element{tag: 'feOffset', attributes: {'x': '25%', 'y': '.5', 'width': '.5'}}
	region := Rect{4, 4, 32, 24}
	assert filter.numeric_source_filter_subregion(&primitive, region, Rect{10, 30, 40, 20}, none)? == Rect{20, 40, 20, 24}
}
