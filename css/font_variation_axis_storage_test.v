module css

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn test_default_variation_axes_reads_and_owned_copies_allocate_nothing() {
	mut settings := FontVariationSettings{}
	other := FontVariationSettings{}
	mut copies := []FontVariationSettings{len: 1024}
	mut checks := 0
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	for index in 0 .. copies.len {
		if settings.axis_value('missing') == none { checks++ }
		if settings.axis_count() == 0 { checks++ }
		if !settings.has_axes() { checks++ }
		if settings.axis_values_equal(&other) { checks++ }
		settings.remove_axis('missing')
		copies[index] = settings.owned_clone()
	}
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert allocated == 0
	assert checks == 4096
	assert settings.axis_storage_ == unsafe { nil }
	assert copies[1023].axis_storage_ == unsafe { nil }
	assert copies[1023].weight == 400
	assert copies[1023].width == 100
	assert copies[1023].opsz == none
	mut snapshot := settings.axis_values()
	snapshot['wght'] = 900
	gc_collect()
	assert !settings.has_axes()
	assert !copies[0].has_axes()
}

fn test_variation_axes_preserve_zero_optional_misses_and_remove_the_last_value() {
	mut settings := FontVariationSettings{ weight: 444.25, width: 87.5, opsz: 13.25 }
	settings.set_axis('ZERO', 0)
	storage := settings.axis_storage_
	assert settings.has_axes()
	assert settings.axis_count() == 1
	assert (settings.axis_value('ZERO') or { panic('stored zero was lost') }) == 0
	assert settings.axis_value('missing-in-populated-map') == none
	settings.set_axis('XTRA', -17.5)
	settings.set_axis('ZERO', 2.5)
	assert voidptr(settings.axis_storage_) == voidptr(storage)
	assert settings.axis_count() == 2
	assert (settings.axis_value('XTRA') or { panic('custom axis lost') }) == -17.5
	settings.remove_axis('ZERO')
	assert settings.axis_value('ZERO') == none
	assert settings.axis_count() == 1
	settings.remove_axis('XTRA')
	assert settings.axis_storage_ == unsafe { nil }
	assert settings.weight == 444.25
	assert settings.width == 87.5
	assert settings.opsz or { panic('optical size lost') } == 13.25
}

fn test_variation_axis_bulk_set_snapshots_and_owned_clone_are_independent_after_collection() {
	mut input := {'wght': 450.0, 'wdth': 88.0}
	mut settings := FontVariationSettings{ weight: 620, width: 91, opsz: 18.5 }
	settings.set_axes(input)
	mut clone := settings.owned_clone()
	mut snapshot := settings.axis_values()
	assert voidptr(clone.axis_storage_) != voidptr(settings.axis_storage_)
	input['wght'] = 700
	input['XTRA'] = 3
	snapshot['wght'] = 800
	snapshot.delete('wdth')
	clone.set_axis('wght', 900)
	assert (settings.axis_value('wght') or { panic('original lost') }) == 450
	assert settings.axis_count() == 2
	assert (clone.axis_value('wght') or { panic('clone lost') }) == 900
	retained := settings.axis_values()
	settings.set_axes(map[string]f64{})
	gc_collect()
	assert settings.axis_storage_ == unsafe { nil }
	assert retained['wght'] == 450
	assert retained['wdth'] == 88
	assert clone.axis_count() == 2
	assert clone.weight == 620
	assert clone.width == 91
	assert clone.opsz or { panic('clone optical size lost') } == 18.5
	assert snapshot['wght'] == 800
}

fn test_variation_axis_equality_compares_values_and_presence_in_any_insertion_order() {
	mut left := FontVariationSettings{}
	mut right := FontVariationSettings{}
	assert left.axis_values_equal(&right)
	left.set_axis('ZERO', 0)
	assert !left.axis_values_equal(&right)
	right.set_axis('TAIL', 3.5)
	right.set_axis('ZERO', 0)
	left.set_axis('TAIL', 3.5)
	assert left.axis_values_equal(&right)
	right.set_axis('TAIL', 4.5)
	assert !left.axis_values_equal(&right)
	right.remove_axis('TAIL')
	left.remove_axis('TAIL')
	assert left.axis_values_equal(&right)
	left.remove_axis('ZERO')
	right.remove_axis('ZERO')
	assert left.axis_values_equal(&right)
	assert left.axis_storage_ == unsafe { nil }
	assert right.axis_storage_ == unsafe { nil }
}

fn test_real_cascade_clones_axes_without_changing_native_handle_or_retained_selection() {
	mut variations := FontVariationSettings{ weight: 620, width: 88, opsz: 14 }
	variations.set_axis('wght', 610)
	variations.set_axis('TEST', 7)
	font := PlatformFont{
		typeface: &PlatformTypeface{ family_name: 'SerenitySans' }
		point_size: 12
		variations: variations
	}
	mut source := FontCascadeList.create()
	source.add(font, [UnicodeRange{ start: 65, end: 90 }])
	first := source.fonts[0].font.font_for_rendering()
	mut copy := FontCascadeList.create()
	copy.extend(source)
	assert source.equals(copy)
	assert voidptr(copy.fonts[0].font.font_for_rendering()) == voidptr(first)
	assert voidptr(source.fonts[0].font.variations.axis_storage_) != voidptr(copy.fonts[0].font.variations.axis_storage_)
	variations.set_axis('wght', 900)
	mut detached := owned_platform_font(&copy.fonts[0].font)
	detached.variations.set_axis('TEST', 99)
	gc_collect()
	selected := source.font_for_code_point(u32(`A`))
	assert (selected.variations.axis_value('wght') or { panic('selection axis lost') }) == 610
	assert (copy.fonts[0].font.variations.axis_value('TEST') or { panic('copy axis lost') }) == 7
	assert !platform_font_equals(detached, copy.fonts[0].font)
	assert selected.variations.weight == 620
	assert selected.variations.width == 88
	assert selected.variations.opsz or { panic('selection optical size lost') } == 14
	assert first.point_size == 16
	assert first.weight == 620
}

fn test_font_computer_preserves_custom_axes_tag_filtering_and_numeric_variations() {
	mut computer := FontComputer.create()
	cascade := computer.compute_font_for_style_values(['serif'], CSSPixels.new(20), 0, 555,
		Percentage{ value_: 82.5 }, .auto_, {'wdth': 90.25, 'wght': 530.0, 'bad': 99.0}, FontFeatureData{})
	assert cascade.last_resort_font != unsafe { nil }
	selected := cascade.font_for_code_point(u32(`A`))
	assert selected.variations.axis_count() == 2
	assert (selected.variations.axis_value('wdth') or { panic('width axis lost') }) == 90.25
	assert (selected.variations.axis_value('wght') or { panic('weight axis lost') }) == 530
	assert selected.variations.axis_value('bad') == none
	assert selected.variations.weight == 555
	assert selected.variations.width == 82.5
	assert selected.variations.opsz or { panic('automatic optical size lost') } == 20
	gc_collect()
	assert (selected.variations.axis_value('wdth') or { panic('retained axis lost') }) == 90.25
}
