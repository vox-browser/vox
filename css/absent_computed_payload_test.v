module css

$if gcboehm ? {
	fn C.GC_get_total_bytes() usize
	fn C.GC_gcollect()
}

fn test_empty_and_string_list_markers_do_not_allocate_counter_algorithms() {
	mut before := usize(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut matches := 0
	for _ in 0 .. 512 {
		empty := ListStyleType{}
		text := ListStyleType{kind: .string, name: 'literal marker'}
		if empty.kind == .none_ && empty.counter_style == none
			&& text.kind == .string && text.name == 'literal marker'
			&& text.counter_style == none { matches++ }
	}
	mut allocated := usize(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert matches == 512
	assert allocated == 0
}

fn absent_paint_constructor_bytes(explicit_none bool) (usize, int) {
	mut before := usize(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut matches := 0
	for _ in 0 .. 32 {
		cache := if explicit_none {
			ComputedLayoutCache{computed_values_fill_: none, computed_values_stroke_: none}
		} else { ComputedLayoutCache{} }
		rare := if explicit_none {
			ComputedLayoutRareData{computed_values_mask_image_: none, computed_values_clip_path_: none}
		} else { ComputedLayoutRareData{} }
		if cache.computed_values_fill_ == none && cache.computed_values_stroke_ == none
			&& rare.computed_values_mask_image_ == none
			&& rare.computed_values_clip_path_ == none { matches++ }
	}
	mut allocated := usize(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	return allocated, matches
}

fn test_absent_paint_defaults_match_explicit_absence_allocation() {
	_, _ = absent_paint_constructor_bytes(true)
	_, _ = absent_paint_constructor_bytes(false)
	$if gcboehm ? { C.GC_gcollect() }
	reference, reference_matches := absent_paint_constructor_bytes(true)
	$if gcboehm ? { C.GC_gcollect() }
	actual, actual_matches := absent_paint_constructor_bytes(false)
	assert reference_matches == 32
	assert actual_matches == 32
	// Both paths construct the same other cache values and required heap records.
	// One allocator quantum per iteration permits rounding, not nested owners.
	assert actual <= reference + 32 * 16
}

fn absent_payload_populated_style() &ComputedProperties {
	mut style := computed_properties_with_initial_values()
	mut values := unsafe { &MutableComputedValues(style) }
	values.set_list_style_type(ListStyleType{kind: .counter_style, name: 'decimal',
		counter_style: CounterStyle.decimal()})
	values.set_fill(SVGPaint.from_color(Color{17, 34, 51, 255}))
	values.set_stroke(SVGPaint.from_url(URL.from_url('retained-paint.svg'), Color{68, 85, 102, 255}))
	values.set_mask_image(ImageStyleValue.create_from_url_string('retained-mask.svg'))
	shape := parse_css_value_logic(.clip_path, 'inset(1px 2px 3px 4px)') or { panic('expected clip-path value') }
	if shape is BasicShapeStyleValue {
		values.set_clip_path(ClipPathReference.from_basic_shape(shape))
	} else { panic('expected basic shape') }
	return style
}

fn test_present_computed_payloads_survive_copy_reset_and_collection() {
	mut style := absent_payload_populated_style()
	retained := &ComputedProperties{...style}
	mut values := unsafe { &MutableComputedValues(style) }
	values.set_list_style_type(ListStyleType{})
	mut cleared_cache := values.ensure_computed_layout_cache()
	cleared_cache.computed_values_fill_ = none
	cleared_cache.computed_values_stroke_ = none
	values.set_cached_mask_image(none)
	values.set_cached_clip_path(none)
	for _ in 0 .. 4 {
		$if gcboehm ? { C.GC_gcollect() }
		old := unsafe { &ComputedValues(retained) }
		marker := old.computed_list_style_type()
		counter := marker.counter_style or { panic('lost counter style') }
		assert counter.name() == 'decimal'
		assert counter.generate_an_initial_representation_for_the_counter_value(42)? == '42'
		assert (old.fill() or { panic('lost fill') }).as_color() == Color{17, 34, 51, 255}
		stroke := old.stroke() or { panic('lost stroke') }
		assert stroke.as_url().url() == 'retained-paint.svg'
		assert stroke.fallback_color()? == Color{68, 85, 102, 255}
		image := old.mask_image() or { panic('lost mask image') }
		assert image.url_.url() == 'retained-mask.svg'
		clip := old.clip_path() or { panic('lost clip path') }
		assert clip.is_basic_shape()
		assert clip.basic_shape().serialize(.normal) == 'inset(1px 2px 3px 4px)'
		assert values.computed_list_style_type().counter_style == none
		assert values.fill() == none
		assert values.stroke() == none
		assert values.mask_image() == none
		assert values.clip_path() == none
	}
}
