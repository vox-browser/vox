module css

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn test_layout_cache_is_materialized_only_for_layout_and_mutable_values() {
	assert sizeof(ComputedProperties) < 1024
	mut first := computed_properties_with_initial_values()
	second := computed_properties_with_initial_values()
	assert first.computed_layout_cache_ == unsafe { nil }
	assert second.computed_layout_cache_ == unsafe { nil }
	_ = first.font_size()
	assert first.computed_layout_cache_ == unsafe { nil }
	_ = resolve_computed_values(first)
	assert first.computed_values_resolved_
	assert first.computed_layout_cache_ != unsafe { nil }
	assert second.computed_layout_cache_ == unsafe { nil }
	mut values := unsafe { &MutableComputedValues(second) }
	values.set_color(Color{5, 6, 7, 255})
	assert second.computed_layout_cache().computed_values_color_ == Color{5, 6, 7, 255}
	assert first.computed_layout_cache().computed_values_color_ == Color{0, 0, 0, 255}
}

fn test_layout_cache_mutations_detach_copied_styles_and_keep_previous_values_alive() {
	mut first := computed_properties_with_initial_values()
	_ = resolve_computed_values(first)
	first.share_computed_layout_cache()
	mut copied := &ComputedProperties{
		...first
	}
	original_cache := first.computed_layout_cache()
	assert voidptr(copied.computed_layout_cache()) == voidptr(original_cache)
	mut original_values := unsafe { &MutableComputedValues(first) }
	original_values.set_color(Color{1, 2, 3, 255})
	assert copied.computed_layout_cache().computed_values_color_ == Color{0, 0, 0, 255}
	assert first.computed_layout_cache().computed_values_color_ == Color{1, 2, 3, 255}
	mut values := unsafe { &MutableComputedValues(copied) }
	values.set_color(Color{9, 8, 7, 255})
	assert voidptr(copied.computed_layout_cache()) != voidptr(original_cache)
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		assert original_cache.computed_values_color_ == Color{0, 0, 0, 255}
		assert copied.computed_layout_cache().computed_values_color_ == Color{9, 8, 7, 255}
		assert first.property(.font_size, .no)!.css_text == copied.property(.font_size, .no)!.css_text
		assert first.computed_layout_cache().computed_values_color_ == Color{1, 2, 3, 255}
	}
	first.share_computed_layout_cache()
	before_resolve := &ComputedProperties{
		...first
	}
	width := parse_css_value(ParsingParams{}, '41px', .width) or { panic('width') }
	first.set_property(.width, width, .no, .no)
	_ = resolve_computed_values(first)
	assert before_resolve.computed_layout_cache().computed_values_color_ == Color{1, 2, 3, 255}
	assert first.computed_layout_cache().writable_owner_identity == 0
	assert first.computed_layout_cache().computed_values_width_ != before_resolve.computed_layout_cache().computed_values_width_
}

fn test_unmaterialized_layout_cache_defaults_remain_readable_after_collection() {
	first := computed_properties_with_initial_values()
	initial := first.computed_layout_cache()
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		next := computed_properties_with_initial_values()
		assert next.computed_layout_cache_ == unsafe { nil }
		assert voidptr(next.computed_layout_cache()) == voidptr(initial)
		assert next.computed_layout_cache().computed_values_margin_ == initial.computed_values_margin_
		assert next.computed_layout_cache().rare_data().computed_values_rotate_ == none
	}
}

fn test_hot_content_and_marker_updates_preserve_style_copies_without_detaching_layout_cache() {
	mut first := computed_properties_with_initial_values()
	mut values := unsafe { &MutableComputedValues(first) }
	values.set_content(ContentData{ type_: .list, text: 'original content' })
	values.set_list_style_type(ListStyleType{ kind: .string, name: 'original marker' })
	assert first.computed_layout_cache_ == unsafe { nil }
	copied := &ComputedProperties{
		...first
	}
	values.set_content(ContentData{ type_: .list, text: 'new content' })
	values.set_list_style_type(ListStyleType{ kind: .string, name: 'new marker' })
	assert (unsafe { &ComputedValues(copied) }.computed_content() or {
		panic('original content lost')
	}).text == 'original content'
	assert unsafe { &ComputedValues(copied) }.computed_list_style_type().name == 'original marker'
	_ = resolve_computed_values(first)
	cache := first.computed_layout_cache()
	published := &ComputedProperties{
		...first
	}
	values.set_content(none)
	values.set_list_style_type(ListStyleType{})
	assert voidptr(first.computed_layout_cache()) == voidptr(cache)
	assert unsafe { &ComputedValues(first) }.computed_content() == none
	assert unsafe { &ComputedValues(first) }.computed_list_style_type().kind == .none_
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		assert (unsafe { &ComputedValues(published) }.computed_content() or {
			panic('retained content lost')
		}).text == 'new content'
		assert unsafe { &ComputedValues(published) }.computed_list_style_type().name == 'new marker'
		assert (unsafe { &ComputedValues(copied) }.computed_content() or {
			panic('copied content lost')
		}).text == 'original content'
		assert unsafe { &ComputedValues(copied) }.computed_list_style_type().name == 'original marker'
	}
}

fn test_restyling_an_unshared_style_rewrites_its_snapshot_in_place() {
	mut style := computed_properties_with_initial_values()
	reuse_previous := begin_layout_cache_reuse(style)
	defer { end_layout_cache_reuse(reuse_previous) }
	_ = resolve_computed_values(style)
	cache := style.computed_layout_cache()
	assert style.owns_computed_layout_cache(u64(voidptr(style)))
	width := parse_css_value(ParsingParams{}, '41px', .width) or { panic('width') }
	for _ in 0 .. 3 {
		style.set_property(.width, width, .no, .no)
		_ = resolve_computed_values(style)
		mut values := unsafe { &MutableComputedValues(style) }
		values.set_color(Color{1, 2, 3, 255})
		assert voidptr(style.computed_layout_cache()) == voidptr(cache)
		assert style.computed_layout_cache().writable_owner_identity == 0
	}
	assert style.computed_layout_cache().computed_values_color_ == Color{1, 2, 3, 255}
	// Outside an animation restyle, a write takes a copy.
	end_layout_cache_reuse(voidptr(0))
	mut outside := unsafe { &MutableComputedValues(style) }
	outside.set_color(Color{4, 5, 6, 255})
	assert voidptr(style.computed_layout_cache()) != voidptr(cache)
	cache_after_copy := style.computed_layout_cache()
	_ = begin_layout_cache_reuse(style)
	_ = resolve_computed_values(style)
	assert voidptr(style.computed_layout_cache()) == voidptr(cache_after_copy)
	// Once shared, the next write detaches again and owns the new snapshot.
	style.share_computed_layout_cache()
	copied := &ComputedProperties{
		...style
	}
	_ = resolve_computed_values(style)
	assert voidptr(style.computed_layout_cache()) != voidptr(cache_after_copy)
	assert voidptr(copied.computed_layout_cache()) == voidptr(cache_after_copy)
	assert style.owns_computed_layout_cache(u64(voidptr(style)))
	assert !copied.owns_computed_layout_cache(u64(voidptr(copied)))
}
