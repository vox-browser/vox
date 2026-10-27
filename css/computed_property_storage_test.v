module css

import dom

$if gcboehm ? {
	fn C.GC_gcollect()
	fn C.GC_get_total_bytes() uint
}

fn storage_test_width(text string) &dom.StyleValue {
	return parse_css_value(ParsingParams{}, text, .width) or { panic('invalid test width') }
}

fn storage_test_all_absent(style &ComputedProperties) bool {
	return style.animated_property_storage_ == unsafe { nil }
		&& style.animated_custom_storage_ == unsafe { nil }
		&& style.inheritance_specified_storage_ == unsafe { nil }
		&& style.font_variation_storage_ == unsafe { nil }
}

fn test_absent_computed_metadata_reads_and_removals_do_not_allocate() {
	mut style := computed_properties_with_initial_values()
	mut values := unsafe { &MutableComputedValues(style) }
	empty_variations := map[string]f64{}
	initial_width := style.property(.width, .no) or { panic('missing initial width') }
	style.reset_non_inherited_animated_properties()
	style.reset_animated_custom_properties()
	style.remove_animated_property(.width)
	values.set_font_variation_settings(empty_variations)
	mut misses := 0
	mut before := uint(0)
	$if gcboehm ? {
		C.GC_gcollect()
		before = C.GC_get_total_bytes()
	}
	for _ in 0 .. 1024 {
		if !style.has_animated_properties() && !style.has_animated_property(.width)
			&& style.animated_property_value(.width) == none
			&& !style.has_animated_custom_properties()
			&& style.animated_custom_property_value('--missing') == none {
			misses++
		}
		style.reset_non_inherited_animated_properties()
		style.reset_animated_custom_properties()
		style.remove_animated_property(.width)
		values.set_font_variation_settings(empty_variations)
		_ = style.property(.width, .yes)
	}
	mut allocated := uint(0)
	$if gcboehm ? {
		allocated = C.GC_get_total_bytes() - before
	}
	assert misses == 1024
	assert allocated == 0
	assert storage_test_all_absent(style)
	assert (style.property(.width, .yes) or { panic('missing width') }) == initial_width
}

fn storage_test_independent_styles() []&ComputedProperties {
	value := storage_test_width('31px')
	mut animation := computed_properties_with_initial_values()
	animation.set_animated_property(.width, value, .no, .no)
	mut custom := computed_properties_with_initial_values()
	custom.set_animated_custom_property('--stored', value)
	mut inheritance := computed_properties_with_initial_values()
	inheritance.add_inheritance_dependent_specified_value(.width, value)
	variation := computed_properties_with_initial_values()
	mut variation_values := unsafe { &MutableComputedValues(variation) }
	variation_values.set_font_variation_settings({
		'wght': f64(650)
	})
	return [animation, custom, inheritance, variation]
}

fn test_each_computed_metadata_first_write_owns_only_its_map_and_survives_gc() {
	styles := storage_test_independent_styles()
	for _ in 0 .. 3 {
		$if gcboehm ? {
			C.GC_gcollect()
		}
	}
	for i, style in styles {
		assert (style.animated_property_storage_ != unsafe { nil }) == (i == 0)
		assert (style.animated_custom_storage_ != unsafe { nil }) == (i == 1)
		assert (style.inheritance_specified_storage_ != unsafe { nil }) == (i == 2)
		assert (style.font_variation_storage_ != unsafe { nil }) == (i == 3)
	}
	assert (styles[0].animated_property_value(.width) or { panic('missing animation') }).css_text == '31px'
	assert (styles[1].animated_custom_property_value('--stored') or { panic('missing custom animation') }).css_text == '31px'
	assert styles[2].inheritance_dependent_specified_values()[PropertyID.width].css_text == '31px'
	variation := unsafe { &ComputedValues(styles[3]) }
	assert variation.font_variation_settings()['wght'] == 650
	fresh := computed_properties_with_initial_values()
	assert storage_test_all_absent(fresh)
	plain := ComputedProperties.new()
	assert storage_test_all_absent(plain)
}

fn test_computed_metadata_public_snapshots_are_independent_of_later_writes() {
	mut style := computed_properties_with_initial_values()
	first := storage_test_width('17px')
	second := storage_test_width('29px')
	style.set_animated_property(.width, first, .no, .no)
	style.set_animated_custom_property('--stored', first)
	style.add_inheritance_dependent_specified_value(.width, first)
	mut animated := style.animated_property_values()
	mut custom := style.animated_custom_property_values()
	mut inherited := style.inheritance_dependent_specified_values()
	animated[PropertyID.width] = second
	custom['--stored'] = second
	inherited[PropertyID.width] = second
	assert (style.animated_property_value(.width) or { panic('missing animation') }) == first
	assert (style.animated_custom_property_value('--stored') or { panic('missing custom animation') }) == first
	assert style.inheritance_dependent_specified_values()[PropertyID.width] == first
	style.set_animated_property(.width, second, .yes, .yes)
	style.set_animated_custom_property('--stored', second)
	style.add_inheritance_dependent_specified_value(.width, second)
	animated.delete(PropertyID.width)
	custom.clear()
	inherited.clear()
	assert style.has_animated_property(.width)
	assert style.has_animated_custom_properties()
	assert style.inheritance_dependent_specified_values()[PropertyID.width] == second
	mut empty := computed_properties_with_initial_values()
	mut empty_snapshot := empty.animated_property_values()
	empty_snapshot[PropertyID.width] = first
	assert storage_test_all_absent(empty)
	assert !empty.has_animated_property(.width)
}

fn test_lazy_animation_storage_preserves_important_transition_and_reset_flags() {
	mut style := computed_properties_with_initial_values()
	base := storage_test_width('13px')
	animated := storage_test_width('41px')
	style.set_property(.width, base, .no, .yes)
	style.set_animated_property(.width, animated, .no, .no)
	style.set_animated_property(.height, animated, .no, .yes)
	assert (style.property(.width, .no) or { panic('missing base') }) == base
	assert (style.property(.width, .yes) or { panic('missing important') }) == base
	assert (style.property(.height, .yes) or { panic('missing inherited animation') }) == animated
	style.set_animated_property(.width, animated, .yes, .no)
	assert (style.property(.width, .yes) or { panic('missing transition') }) == animated
	assert style.is_animated_property_result_of_transition(.width)
	assert !style.is_animated_property_inherited(.width)
	assert style.is_animated_property_inherited(.height)
	storage := style.animated_property_storage_
	style.reset_non_inherited_animated_properties()
	assert !style.has_animated_property(.width)
	assert style.has_animated_property(.height)
	assert style.is_animated_property_result_of_transition(.width)
	style.remove_animated_property(.height)
	assert !style.has_animated_properties()
	assert style.animated_property_storage_ == storage
	style.set_animated_property(.width, animated, .no, .yes)
	assert style.animated_property_storage_ == storage
	assert !style.is_animated_property_result_of_transition(.width)
	assert style.is_animated_property_inherited(.width)
	style.set_animated_custom_property('--x', animated)
	custom_storage := style.animated_custom_storage_
	style.reset_animated_custom_properties()
	assert !style.has_animated_custom_properties()
	assert style.animated_custom_storage_ == custom_storage
}

fn test_lazy_font_variation_maps_clone_inputs_snapshots_and_inheritance_then_clear() {
	mut source := computed_properties_with_initial_values()
	mut source_values := unsafe { &MutableComputedValues(source) }
	mut input := {
		'wght': f64(525)
	}
	source_values.set_font_variation_settings(input)
	input['wght'] = 900
	immutable_source := unsafe { &ComputedValues(source) }
	mut snapshot := immutable_source.font_variation_settings()
	snapshot['wght'] = 200
	assert immutable_source.font_variation_settings()['wght'] == 525
	mut target := computed_properties_with_initial_values()
	mut target_values := unsafe { &MutableComputedValues(target) }
	target_values.inherit_from(immutable_source)
	assert voidptr(target.font_variation_storage_) != voidptr(source.font_variation_storage_)
	assert target.font_variation_storage_.values['wght'] == 525
	source_values.set_font_variation_settings({
		'wght': f64(740)
	})
	assert target.font_variation_storage_.values['wght'] == 525
	plain := computed_properties_with_initial_values()
	target_values.inherit_from(unsafe { &ComputedValues(plain) })
	assert target.font_variation_storage_ == unsafe { nil }
	assert storage_test_all_absent(plain)
	source_values.set_font_variation_settings(map[string]f64{})
	assert source.font_variation_storage_ == unsafe { nil }
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
	}
	assert snapshot['wght'] == 200
}

fn test_live_font_variation_normal_resolution_clears_the_existing_map() {
	mut style := computed_properties_with_initial_values()
	variation := parse_css_value(ParsingParams{}, '"wght" 610', .font_variation_settings) or { panic('invalid variation') }
	normal := parse_css_value(ParsingParams{}, 'normal', .font_variation_settings) or { panic('invalid normal') }
	style.set_property(.font_variation_settings, variation, .no, .no)
	_ = resolve_computed_values(style)
	assert style.font_variation_storage_.values['wght'] == 610
	values := unsafe { &ComputedValues(style) }
	snapshot := values.font_variation_settings()
	style.set_property(.font_variation_settings, normal, .no, .no)
	_ = resolve_computed_values(style)
	assert style.font_variation_storage_ == unsafe { nil }
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
	}
	assert snapshot['wght'] == 610
	fresh := computed_properties_with_initial_values()
	_ = resolve_computed_values(fresh)
	assert fresh.font_variation_storage_ == unsafe { nil }
}
