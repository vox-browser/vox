module svg

fn test_numeric_filter_region_defaults_to_padded_object_bounds() {
	filter := Element{tag: 'filter'}
	bounds := Rect{10, 20, 40, 20}
	assert filter.numeric_filter_region(bounds)? == Rect{6, 18, 48, 24}
	assert filter.numeric_filter_region(none) == none
	assert filter.numeric_filter_region(Rect{10, 20, 40, 0}) == none
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
	assert filter.numeric_filter_region(Rect{16, 8, 20, 20})? == Rect{26, 8, 10, 30}
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
	assert filter.numeric_filter_region(none)? == Rect{6, 4, 20, 22}
	unsupported := Element{
		tag: 'filter'
		attributes: {
			'filterUnits': 'userSpaceOnUse'
			'x':           '10%'
		}
	}
	assert unsupported.numeric_filter_region(Rect{0, 0, 40, 40}) == none
}
