module css

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn contingency_cascade_font(size f32) PlatformFont {
	mut variations := FontVariationSettings{}
	variations.set_axis('wght', 450)
	return PlatformFont{
		typeface: &PlatformTypeface{ family_name: 'Invisible storage fixture', source_path: '/fixture/font.ttf' }
		point_size: size
		variations: variations
		features: [ShapeFeature{ tag: 'liga', value: 0 }]
	}
}

fn test_cascade_visible_selection_and_absent_cache_lookup_allocate_nothing() {
	mut list := FontCascadeList.create()
	font := contingency_cascade_font(12)
	key := 'missing'
	mut misses := 0
	mut visible_matches := 0
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	for _ in 0 .. 1024 {
		if list.cached_invisible_font(key) == none { misses++ }
		if voidptr(list.font_with_visibility(&font, false)) == voidptr(&font) { visible_matches++ }
	}
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert allocated == 0
	assert misses == 1024
	assert visible_matches == 1024
	assert list.invisible_font_storage_ == unsafe { nil }
	gc_collect()
	assert list.invisible_font_storage_ == unsafe { nil }
}

fn test_cascade_invisible_cache_first_write_identity_key_misses_and_retention() {
	mut list := FontCascadeList.create()
	font := contingency_cascade_font(12)
	first := list.font_with_visibility(&font, true)
	assert first.is_invisible
	assert !font.is_invisible
	assert list.invisible_font_storage_ != unsafe { nil }
	assert list.invisible_font_storage_.values.len == 1
	assert list.cached_invisible_font('missing-in-populated-cache') == none
	matching := contingency_cascade_font(12)
	assert voidptr(list.font_with_visibility(&matching, true)) == voidptr(first)
	larger := contingency_cascade_font(18)
	second := list.font_with_visibility(&larger, true)
	assert voidptr(second) != voidptr(first)
	assert list.invisible_font_storage_.values.len == 2
	gc_collect()
	assert voidptr(list.font_with_visibility(&font, true)) == voidptr(first)
	assert first.point_size == 12
	assert second.point_size == 18
	assert first.typeface.family_name == 'Invisible storage fixture'
}

fn test_cascade_invisible_font_owns_axes_features_and_independent_cache_storage() {
	mut list := FontCascadeList.create()
	mut source := contingency_cascade_font(12)
	first := list.font_with_visibility(&source, true)
	source.variations.set_axis('wght', 700)
	source.features[0].value = 1
	assert (first.variations.axis_value('wght') or { panic('missing owned weight axis') }) == 450
	assert first.features[0].value == 0
	mut other := FontCascadeList.create()
	assert other.invisible_font_storage_ == unsafe { nil }
	second := other.font_with_visibility(&source, true)
	assert voidptr(other.invisible_font_storage_) != voidptr(list.invisible_font_storage_)
	assert voidptr(first) != voidptr(second)
	assert (second.variations.axis_value('wght') or { panic('missing owned weight axis') }) == 700
	assert second.features[0].value == 1
	gc_collect()
	assert (first.variations.axis_value('wght') or { panic('missing owned weight axis') }) == 450
	assert first.features[0].tag == 'liga'
	assert (second.variations.axis_value('wght') or { panic('missing owned weight axis') }) == 700
}

fn test_cascade_add_extend_and_last_resort_keep_existing_invisible_cache_identity() {
	mut list := FontCascadeList.create()
	font := contingency_cascade_font(12)
	first := list.font_with_visibility(&font, true)
	storage := list.invisible_font_storage_
	list.add(font, [])
	mut extension := FontCascadeList.create()
	extension.add(contingency_cascade_font(18), [])
	list.extend(extension)
	list.set_last_resort_font(contingency_cascade_font(20))
	assert voidptr(list.invisible_font_storage_) == voidptr(storage)
	assert list.invisible_font_storage_.values.len == 1
	assert extension.invisible_font_storage_ == unsafe { nil }
	assert voidptr(list.font_with_visibility(&font, true)) == voidptr(first)
	gc_collect()
	assert first.is_invisible
	assert list.fonts.len == 2
	assert list.last_resort_font.point_size == 20
	assert voidptr(list.invisible_font_storage_) == voidptr(storage)
}
