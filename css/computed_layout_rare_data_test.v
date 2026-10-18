module css

import dom

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn rare_cache_set(mut style ComputedProperties, property PropertyID, text string) {
	style.set_property(property, parse_css_value(ParsingParams{}, text, property) or {
		panic('${property}: ${text}: ${err}')
	}, .no, .no)
}

fn rare_cache_assert_empty_defaults(values &ComputedValues) {
	assert values.grid_template_columns() == GridTrackSizeList{}
	assert values.grid_template_rows() == GridTrackSizeList{}
	assert values.grid_template_areas() == GridTemplateAreas{}
	assert values.mask() == none
	assert values.mask_image() == none
	assert values.clip_path() == none
	assert values.filter() == Filter.make_none()
	assert values.backdrop_filter() == Filter.make_none()
	assert values.rotate() == none
	assert values.scale() == none
	assert values.perspective() == none
	assert values.perspective_origin() == Position{}
	assert values.transformations().len == 0
	assert values.transform_box() == .view_box
	assert values.transform_origin() == TransformOrigin{}
	assert values.transform_style() == .flat
	assert values.translate() == none
	assert values.cx() == InitialValues.cx()
	assert values.cy() == InitialValues.cy()
	assert values.r() == InitialValues.r()
	assert values.x() == InitialValues.cx()
	assert values.y() == InitialValues.cy()
}

fn test_ordinary_layout_cache_fits_one_block_without_allocating_rare_values() {
	assert sizeof(ComputedLayoutCache) <= 3800
	println('ComputedLayoutCache=${sizeof(ComputedLayoutCache)} rare=${sizeof(ComputedLayoutRareData)}')
	for _ in 0 .. 4 {
		mut style := computed_properties_with_initial_values()
		values := unsafe { &ComputedValues(style) }
		rare_cache_assert_empty_defaults(values)
		assert style.computed_layout_cache_ == unsafe { nil }
		_ = resolve_computed_values(style)
		rare_cache_assert_empty_defaults(values)
		assert style.computed_layout_cache().rare_data_ == unsafe { nil }
		_ = resolve_computed_values_for_document(style, dom.Document.create(dom.url_about_blank()))
		rare_cache_assert_empty_defaults(values)
		assert style.computed_layout_cache().rare_data_ == unsafe { nil }
		assert !style.computed_layout_cache().rare_data_writable_
	}
}

fn rare_cache_assert_same_transformation(actual TransformationData, expected TransformationData) {
	assert actual.property_id == expected.property_id
	assert actual.values.len == expected.values.len
	for i, value in actual.values {
		assert value.css_text == expected.values[i].css_text
		if base := value.base_url {
			expected_base := expected.values[i].base_url or { panic('missing transform argument base URL') }
			assert base == expected_base
		} else {
			assert expected.values[i].base_url == none
		}
	}
}

fn test_all_rare_resolved_values_match_the_raw_property_graph() {
	mut style := computed_properties_with_initial_values()
	for property, text in {
		PropertyID.grid_template_columns: '20px 1fr'
		.grid_template_rows: 'repeat(2, 7px)'
		.grid_template_areas: '"left right"'
		.mask_image: 'url("mask.svg")'
		.clip_path: 'inset(1px 2px 3px 4px)'
		.backdrop_filter: 'opacity(0.4)'
		.filter: 'blur(2px)'
		.rotate: '15deg'
		.scale: '2 3'
		.perspective: '300px'
		.perspective_origin: '20% 30%'
		.transform: 'translateX(12px) rotate(10deg)'
		.transform_box: 'fill-box'
		.transform_origin: '10% 25% 3px'
		.transform_style: 'preserve-3d'
		.translate: '4px 5px'
		.cx: '7px'
		.cy: '8%'
		.r: '9px'
		.x: '10px'
		.y: '11%'
	} {
		rare_cache_set(mut style, property, text)
	}
	values := resolve_computed_values(style)
	assert style.computed_layout_cache().rare_data_ != unsafe { nil }
	assert values.grid_template_columns() == style.grid_template_columns()
	assert values.grid_template_rows() == style.grid_template_rows()
	assert values.grid_template_areas() == style.grid_template_areas()
	assert values.mask() == computed_values_mask_reference(style)
	assert values.mask_image() == computed_values_mask_image(style)
	assert values.clip_path() == computed_values_clip_path(style)
	assert values.backdrop_filter() == style.backdrop_filter()
	assert values.filter() == style.filter()
	rare_cache_assert_same_transformation(values.rotate() or { panic("missing rotate") }, style.rotate() or { panic("missing raw rotate") })
	rare_cache_assert_same_transformation(values.scale() or { panic("missing scale") }, style.scale() or { panic("missing raw scale") })
	assert values.perspective() == style.perspective()
	assert values.perspective_origin() == style.perspective_origin()
	actual_transforms := values.transformations()
	expected_transforms := style.transformations()
	assert actual_transforms.len == expected_transforms.len
	for i, transform in actual_transforms {
		rare_cache_assert_same_transformation(transform, expected_transforms[i])
	}
	assert values.transform_box() == style.transform_box()
	assert values.transform_origin() == style.transform_origin()
	assert values.transform_style() == style.transform_style()
	rare_cache_assert_same_transformation(values.translate() or { panic("missing translate") }, style.translate() or { panic("missing raw translate") })
	assert values.cx() == computed_values_length_percentage(style, .cx, InitialValues.cx())
	assert values.cy() == computed_values_length_percentage(style, .cy, InitialValues.cy())
	assert values.r() == computed_values_length_percentage(style, .r, InitialValues.r())
	assert values.x() == computed_values_length_percentage(style, .x, InitialValues.cx())
	assert values.y() == computed_values_length_percentage(style, .y, InitialValues.cy())
}

fn test_rare_writes_detach_published_pointer_and_value_copies() {
	mut original := computed_properties_with_initial_values()
	mut values := unsafe { &MutableComputedValues(original) }
	values.set_perspective(CSSPixels.new(123))
	values.set_transform_box(.fill_box)
	published := original.computed_layout_cache()
	published_rare := published.rare_data_
	mut copy := &ComputedProperties{ ...original }
	mut by_value := *original
	values.set_transform_box(.border_box)
	assert voidptr(original.computed_layout_cache().rare_data_) != voidptr(published_rare)
	assert published_rare.computed_values_transform_box_ == .fill_box
	mut copy_values := unsafe { &MutableComputedValues(copy) }
	copy_values.set_color(Color{1, 2, 3, 255})
	assert voidptr(copy.computed_layout_cache().rare_data_) == voidptr(published_rare)
	copy_values.set_perspective(CSSPixels.new(456))
	mut by_value_values := unsafe { &MutableComputedValues(&by_value) }
	by_value_values.set_transform_box(.stroke_box)
	for _ in 0 .. 4 {
		$if gcboehm ? { C.GC_gcollect() }
		assert published_rare.computed_values_transform_box_ == .fill_box
		assert (published_rare.computed_values_perspective_ or { panic("lost perspective") }) == CSSPixels.new(123)
		assert unsafe { &ComputedValues(original) }.transform_box() == .border_box
		assert (unsafe { &ComputedValues(copy) }.perspective() or { panic("lost copy perspective") }) == CSSPixels.new(456)
		assert unsafe { &ComputedValues(&by_value) }.transform_box() == .stroke_box
	}
	// Exercise the opposite write order on a shared published rare record.
	mut second := rare_cache_with_owned_payload()
	mut second_copy := &ComputedProperties{ ...second }
	mut copied_values := unsafe { &MutableComputedValues(second_copy) }
	copied_values.set_translate(none)
	assert unsafe { &ComputedValues(second) }.translate() != none
	mut second_values := unsafe { &MutableComputedValues(second) }
	second_values.set_transform_box(.stroke_box)
	assert unsafe { &ComputedValues(second_copy) }.transform_box() == .view_box
	assert unsafe { &ComputedValues(second_copy) }.translate() == none
	assert unsafe { &ComputedValues(second) }.translate() != none

}

fn test_bulk_rare_writes_reuse_only_the_unpublished_snapshot() {
	mut style := computed_properties_with_initial_values()
	mut values := unsafe { &MutableComputedValues(style) }
	owns := values.begin_computed_layout_cache_write()
	assert owns
	values.set_perspective(CSSPixels.new(123))
	rare := style.computed_layout_cache().rare_data_
	nested := values.begin_computed_layout_cache_write()
	assert !nested
	values.set_transform_box(.fill_box)
	values.finish_computed_layout_cache_write(nested)
	values.set_transform_style(.preserve_3d)
	assert voidptr(style.computed_layout_cache().rare_data_) == voidptr(rare)
	values.finish_computed_layout_cache_write(owns)
	assert !style.computed_layout_cache().rare_data_writable_
	copy := &ComputedProperties{ ...style }
	values.set_transform_box(.border_box)
	assert voidptr(style.computed_layout_cache().rare_data_) != voidptr(rare)
	assert unsafe { &ComputedValues(copy) }.transform_box() == .fill_box
	assert unsafe { &ComputedValues(copy) }.transform_style() == .preserve_3d
}

fn rare_cache_with_owned_payload() &ComputedProperties {
	mut style := computed_properties_with_initial_values()
	mut values := unsafe { &MutableComputedValues(style) }
	value := parse_css_value(ParsingParams{}, '97px', .width) or { panic(err) }
	values.set_translate(TransformationData{ property_id: .translate, values: [value] })
	values.set_mask(MaskReference.from_url(URL.from_url('owned-mask.svg')))
	values.set_mask_image(ImageStyleValue.create_from_url_string('owned-image.svg'))
	return style
}

fn test_rare_record_retains_owned_payloads_and_optional_resets_keep_old_snapshots() {
	mut style := rare_cache_with_owned_payload()
	old := &ComputedProperties{ ...style }
	mut values := unsafe { &MutableComputedValues(style) }
	values.set_cached_mask(none)
	values.set_cached_mask_image(none)
	values.set_cached_clip_path(none)
	values.set_translate(none)
	for _ in 0 .. 4 {
		$if gcboehm ? { C.GC_gcollect() }
		old_values := unsafe { &ComputedValues(old) }
		translation := old_values.translate() or { panic('lost transformation') }
		assert translation.values[0].css_text == '97px'
		assert old_values.mask() != none
		assert old_values.mask_image() != none
		assert unsafe { &ComputedValues(style) }.mask() == none
		assert unsafe { &ComputedValues(style) }.mask_image() == none
		assert unsafe { &ComputedValues(style) }.translate() == none
	}
}

fn test_rare_defaults_and_raw_reresolution_preserve_geometry_provenance() {
	document := dom.Document.create(dom.url_about_blank())
	mut style := computed_properties_with_initial_values()
	_ = resolve_computed_values_for_document(style, document)
	initial_cache := style.computed_layout_cache()
	assert initial_cache.resolution_provenance != unsafe { nil }
	mut values := unsafe { &MutableComputedValues(style) }
	values.set_translate(none)
	assert voidptr(style.computed_layout_cache()) != voidptr(initial_cache)
	assert style.computed_layout_cache().resolution_provenance == unsafe { nil }
	assert style.computed_layout_cache().rare_data_ == unsafe { nil }
	rare_cache_set(mut style, .transform, 'translateX(17px)')
	_ = resolve_computed_values_for_document(style, document)
	published := style.computed_layout_cache()
	before := unsafe { &ComputedValues(style) }.transformations()
	assert published.resolution_provenance != unsafe { nil }
	_ = resolve_computed_values_for_document(style, document)
	assert voidptr(style.computed_layout_cache()) == voidptr(published)
	rare_cache_set(mut style, .transform, 'translateX(29px)')
	_ = resolve_computed_values_for_document(style, document)
	assert voidptr(style.computed_layout_cache().rare_data_) != voidptr(published.rare_data_)
	assert unsafe { &ComputedValues(style) }.transformations() != before
	assert published.rare_data().computed_values_transformations_ == before
	assert style.computed_layout_cache().resolution_provenance != unsafe { nil }
	assert !style.computed_layout_cache().rare_data_writable_
}
