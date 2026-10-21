module css

import dom

fn scalar_snapshot_document() &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.enable_native_storage()
	document.set_scripting_enabled_by_embedder(true)
	return document
}

fn scalar_snapshot_set(mut style ComputedProperties, property PropertyID, source string) {
	style.set_property(property, parse_css_value(ParsingParams{}, source, property) or {
		panic('invalid ${property}: ${source}')
	}, .no, .no)
}

fn scalar_snapshot_style() &ComputedProperties {
	mut style := computed_properties_with_initial_values()
	mut values := unsafe { &MutableComputedValues(style) }
	_ = resolve_computed_values(style)
	values.set_transform_box(.fill_box)
	values.set_transform_origin(TransformOrigin{ x: LengthPercentage.from_length(Length.make_px(12)) })
	values.set_cx(LengthPercentage.from_percentage(Percentage.new(30)))
	return style
}

fn test_scalar_rare_snapshots_share_and_detach_before_geometry_writes() {
	mut first := scalar_snapshot_style()
	second := scalar_snapshot_style()
	assert share_idle_layout_snapshots([first, second]) == 1
	snapshot := second.computed_layout_cache()
	rare := snapshot.rare_data_
	assert voidptr(first.computed_layout_cache()) == voidptr(snapshot)
	mut values := unsafe { &MutableComputedValues(first) }
	values.set_cx(LengthPercentage.from_length(Length.make_px(73)))
	assert voidptr(first.computed_layout_cache()) != voidptr(snapshot)
	assert voidptr(first.computed_layout_cache().rare_data_) != voidptr(rare)
	assert values.cx() == LengthPercentage.from_length(Length.make_px(73))
	assert second.computed_layout_cache().rare_data().computed_values_cx_ == LengthPercentage.from_percentage(Percentage.new(30))
	assert second.computed_layout_cache().rare_data().computed_values_transform_box_ == .fill_box
}

fn test_scalar_snapshot_equality_checks_every_allowed_rare_field() {
	// Equal hot values must not merge styles with distinct SVG/transform geometry.
	for property, source in {
		PropertyID.perspective: '300px'
		.perspective_origin:    '20% 30%'
		.transform_box:         'fill-box'
		.transform_origin:      '10% 25% 3px'
		.transform_style:       'preserve-3d'
		.cx:                    '7px'
		.cy:                    '8%'
		.r:                     '9px'
		.x:                     '10px'
		.y:                     '11%'
	} {
		first := computed_properties_with_initial_values()
		_ = resolve_computed_values(first)
		mut second := computed_properties_with_initial_values()
		scalar_snapshot_set(mut second, property, source)
		_ = resolve_computed_values(second)
		assert idle_layout_snapshot_is_shareable(second.computed_layout_cache())
		assert share_idle_layout_snapshots([first, second]) == 0, '${property}'
	}
}

fn test_rare_resource_snapshots_remain_local_even_when_equal() {
	for property, source in {
		PropertyID.grid_template_columns: '20px 1fr'
		.grid_template_rows:              'repeat(2, 7px)'
		.grid_template_areas:             '"left right"'
		.mask_image:                      'url("mask.svg")'
		.clip_path:                       'inset(1px)'
		.backdrop_filter:                 'opacity(0.4)'
		.filter:                          'blur(2px)'
		.rotate:                          '15deg'
		.scale:                           '2 3'
		.transform:                       'translateX(12px)'
		.translate:                       '4px 5px'
	} {
		mut first := computed_properties_with_initial_values()
		mut second := computed_properties_with_initial_values()
		scalar_snapshot_set(mut first, property, source)
		scalar_snapshot_set(mut second, property, source)
		_ = resolve_computed_values(first)
		_ = resolve_computed_values(second)
		assert !idle_layout_snapshot_is_shareable(first.computed_layout_cache()), '${property}'
		assert share_idle_layout_snapshots([first, second]) == 0, '${property}'
	}
}

fn test_initial_scalar_snapshots_avoid_duplicate_permanent_hot_records() {
	$if !prealloc {
		return
	}
	mut document := scalar_snapshot_document()
	mut scope := document.enter_native_storage()
	mut first := computed_properties_with_initial_values()
	scalar_snapshot_set(mut first, .transform_origin, '12px 30%')
	scalar_snapshot_set(mut first, .cx, '7px')
	_ = resolve_computed_values_for_document(first, document)
	for _ in 0 .. 64 {
		mut other := computed_properties_with_initial_values()
		scalar_snapshot_set(mut other, .transform_origin, '12px 30%')
		scalar_snapshot_set(mut other, .cx, '7px')
		_ = resolve_computed_values_for_document(other, document)
		assert voidptr(first.computed_layout_cache()) == voidptr(other.computed_layout_cache())
	}
	scope.finish()
	document.release_native_storage()
}
