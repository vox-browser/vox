module css

import dom

fn compositor_geometry_value(property PropertyID, text string) &dom.StyleValue {
	return parse_css_value(ParsingParams{}, text, property) or { panic('invalid ${property}: ${text}') }
}

fn compositor_geometry_fixture() (&dom.Document, &ComputedProperties) {
	document := dom.Document.create(dom.url_about_blank())
	mut style := computed_properties_with_initial_values()
	for property, text in {
		PropertyID.width:       '73px'
		.height:                '29px'
		.font_size:             '17px'
		.color:                 'rgb(31 32 33)'
		.background_color:      'currentColor'
		.background_image:      'linear-gradient(red, blue)'
		.grid_template_columns: '20px 1fr'
		.filter:                'blur(2px)'
		.opacity:               '.8'
		.transform:             'translateX(3px)'
		.translate:             '4px 5px'
		.rotate:                '7deg'
		.scale:                 '2 3'
		.transform_origin:      '10% 20% 3px'
	} {
		style.set_property(property, compositor_geometry_value(property, text), .no, .no)
	}
	_ = resolve_computed_values_for_document(style, document)
	mut computer := css_style_computer_for(document)
	computer.animation_layout_style_ = style
	computer.animation_layout_compositor_only_ = true
	assert can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	return document, style
}

fn compositor_geometry_assert_transform(actual ?TransformationData, expected ?TransformationData) {
	if a := actual {
		b := expected or { panic('missing expected transform') }
		assert a.property_id == b.property_id
		assert a.values.map(it.css_text) == b.values.map(it.css_text)
	} else {
		assert expected == none
	}
}

// A fresh cache with the same effective property graph forces the complete
// resolver, independent of the callback's permission to update selected slots.
fn compositor_geometry_check(style &ComputedProperties, document &dom.Document) {
	oracle := &ComputedProperties{
		...style
		computed_layout_cache_:      nil
		computed_values_resolved_:   false
		shared_geometry_cache_:      nil
		shared_geometry_provenance_: nil
		layout_cache_owner_serial_:  0
	}
	actual := resolve_computed_values_for_document(style, document)
	expected := resolve_computed_values_for_document(oracle, document)
	assert actual.opacity() == expected.opacity()
	a := actual.transformations()
	b := expected.transformations()
	assert a.len == b.len
	for i, value in a { compositor_geometry_assert_transform(value, b[i]) }
	compositor_geometry_assert_transform(actual.translate(), expected.translate())
	compositor_geometry_assert_transform(actual.rotate(), expected.rotate())
	compositor_geometry_assert_transform(actual.scale(), expected.scale())
	assert actual.transform_origin() == expected.transform_origin()
	assert actual.width() == expected.width()
	assert actual.height() == expected.height()
	assert actual.color() == expected.color()
	assert actual.background_color() == expected.background_color()
	assert actual.background_layers() == expected.background_layers()
	assert actual.grid_template_columns() == expected.grid_template_columns()
	assert actual.filter() == expected.filter()
	assert actual.font_size() == expected.font_size()
	assert actual.line_height() == expected.line_height()
}

fn test_compositor_geometry_matches_full_resolution_for_distinct_samples_and_removals() {
	document, mut style := compositor_geometry_fixture()
	defer { document.finalize() }
	for i in 0 .. 64 {
		style.reset_non_inherited_animated_properties()
		for property, text in {
			PropertyID.opacity: '${f64(i) / 63}'
			.transform:         'translateX(${i}px) rotate(${i * 3}deg)'
			.translate:         '${i}% ${i + 1}px'
			.rotate:            '${i * 4}deg'
			.scale:             '${f64(i) / 16} 2'
			.transform_origin:  '${i}% 30% 2px'
		} {
			style.set_animated_property(property, compositor_geometry_value(property, text), .no, .no)
		}
		assert can_reuse_compositor_geometry(style, document, style.geometry_provenance())
		compositor_geometry_check(style, document)
	}
	style.reset_non_inherited_animated_properties()
	assert can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	assert unsafe { &ComputedValues(style) }.opacity() == f32(.8)
}

fn test_compositor_geometry_rejects_mixed_domains_and_restores_removed_values() {
	document, mut style := compositor_geometry_fixture()
	defer { document.finalize() }
	style.set_animated_property(.width, compositor_geometry_value(.width, '101px'), .no, .no)
	style.set_animated_property(.transform, compositor_geometry_value(.transform, 'scale(0)'), .no, .no)
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	// Even an unchanged animated width excludes the shortcut. Removing it must
	// materialize the raw width before compositor-only updates become eligible.
	style.set_animated_property(.transform, compositor_geometry_value(.transform, 'scale(2)'), .no, .no)
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	style.remove_animated_property(.width)
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	assert can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	style.set_animated_custom_property('--width', &dom.StyleValue{ css_text: '8px' })
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	style.reset_animated_custom_properties()
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
}

fn test_compositor_geometry_rejects_raw_alias_revert_and_precedence_mutations() {
	document, mut style := compositor_geometry_fixture()
	defer { document.finalize() }
	mut alias := *style
	alias.set_property_without_modifying_flags(.width, compositor_geometry_value(.width, '41px'))
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	mut reverted := computed_properties_with_initial_values()
	reverted.set_property(.width, compositor_geometry_value(.width, '53px'), .no, .no)
	style.revert_property(.width, reverted)
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	style.set_animated_property(.opacity, compositor_geometry_value(.opacity, '.2'), .no, .no)
	compositor_geometry_check(style, document)
	style.set_property_important(.opacity, .yes)
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	assert unsafe { &ComputedValues(style) }.opacity() == f32(.8)
	style.set_animated_property(.opacity, compositor_geometry_value(.opacity, '.3'), .yes, .no)
	compositor_geometry_check(style, document)
	assert unsafe { &ComputedValues(style) }.opacity() == f32(.3)
	style.set_property_inherited(.width, .yes)
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	style.computed_property_graph_token_.raw_generation = ~u64(0)
	style.set_property_without_modifying_flags(.height, compositor_geometry_value(.height, '31px'))
	assert style.computed_property_graph_token_.raw_generation == 0
	compositor_geometry_check(style, document)
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
}

fn test_compositor_geometry_rejects_context_changes_and_full_refresh() {
	mut document, mut style := compositor_geometry_fixture()
	defer { document.finalize() }
	mut computer := css_style_computer_for(document)
	computer.animation_layout_compositor_only_ = false
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	computer.animation_layout_compositor_only_ = true
	style.viewport_rect_ = CSSPixelRect.new(0, 0, 900, 700)
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	style.root_font_size_px_ = 23
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	style.root_line_height_px_ = 37
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	style.clear_computed_font_list_cache()
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	document.set_layout_coordinate_scale(2)
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	document.set_layout_coordinate_scale(1)
	previous := style.geometry_provenance()
	mut values := unsafe { &MutableComputedValues(style) }
	values.set_width(Size.make_px(CSSPixels.nearest_value_for(97)))
	// A callback could invalidate a cache after its old proof was captured.
	assert !can_reuse_compositor_geometry(style, document, previous)
	assert !can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
}

fn test_compositor_geometry_detaches_a_shared_snapshot_before_updating() {
	document, mut style := compositor_geometry_fixture()
	defer { document.finalize() }
	style.share_computed_layout_cache()
	snapshot := &ComputedProperties{ ...style }
	old := snapshot.computed_layout_cache()
	old_rare := old.rare_data()
	style.set_animated_property(.opacity, compositor_geometry_value(.opacity, '.1'), .no, .no)
	style.set_animated_property(.transform, compositor_geometry_value(.transform, 'translateX(99px)'), .no, .no)
	assert can_reuse_compositor_geometry(style, document, style.geometry_provenance())
	compositor_geometry_check(style, document)
	assert voidptr(style.computed_layout_cache()) != voidptr(old)
	assert old.computed_values_opacity_ == f32(.8)
	assert old.rare_data().computed_values_transformations_[0].values[0].css_text == '3px'
	assert voidptr(old.rare_data()) == voidptr(old_rare)
}
