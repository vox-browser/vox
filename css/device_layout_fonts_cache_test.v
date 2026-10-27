module css

import platform

$if gcboehm ? {
	fn C.GC_gcollect()
	fn C.GC_get_total_bytes() uint
}

fn projected_font_cache_source() &FontCascadeList {
	mut source := FontCascadeList.create()
	mut variations := FontVariationSettings{ opsz: 13.5 }
	variations.set_axis('TEST', 7)
	source.add(PlatformFont{
		typeface:              &PlatformTypeface{ family_name: 'Arial' }
		point_size:            9.375
		variations:            variations
		features:              [ShapeFeature{ tag: 'liga', value: 0 }]
		font_rendering_policy: .chromium
	}, [UnicodeRange{ start: 32, end: 127 }])
	return source
}

fn test_device_font_cascade_shares_physical_fonts_and_native_handles_without_allocation() {
	source := projected_font_cache_source()
	projected := device_layout_fonts(source, 2, 25)
	font := projected.fonts[0].font.font_for_rendering()
	assert projected.fonts[0].font.point_size == 18.75
	assert font.point_size == 25
	assert projected.fonts[0].font.variations.opsz? == 13.5
	assert source.fonts[0].font.point_size == 9.375
	$if gcboehm ? {
		C.GC_gcollect()
		before := C.GC_get_total_bytes()
		for _ in 0 .. 1024 {
			next := device_layout_fonts(source, 2, 25)
			assert voidptr(next) == voidptr(projected)
			assert voidptr(next.fonts[0].font.font_for_rendering()) == voidptr(font)
		}
		assert C.GC_get_total_bytes() == before
	} $else {
		assert voidptr(device_layout_fonts(source, 2, 25)) == voidptr(projected)
	}
	rescaled := device_layout_fonts(source, 3, 37.5)
	assert voidptr(rescaled) != voidptr(projected)
	assert rescaled.fonts[0].font.point_size == 28.125
	assert rescaled.fonts[0].font.font_for_rendering().point_size == 37.5
	assert projected.fonts[0].font.font_for_rendering().point_size == 25
	assert projected.fonts[0].font.variations.opsz? == 13.5
}

fn test_device_font_cascade_rechecks_every_mutable_font_input_and_keeps_snapshots() {
	mut source := projected_font_cache_source()
	original := device_layout_fonts(source, 2, 25)
	mut previous := original
	for change in 0 .. 10 {
		mut font := owned_platform_font(&source.fonts[0].font)
		match change {
			0 { font.point_size = 10 }
			1 { font.variations.weight = 700 }
			2 { font.variations.width = 110 }
			3 { font.variations.opsz = 22 }
			4 { font.variations.set_axis('TEST', 9) }
			5 { font.features[0].value = 1 }
			6 { font.is_invisible = true }
			7 { font.italic = true }
			8 { font.font_rendering_policy = .libweb }
			9 { font.typeface = &PlatformTypeface{ family_name: 'Serif' } }
			else {}
		}
		source.fonts[0] = FontCascadeEntry{ font: font, unicode_ranges: source.fonts[0].unicode_ranges }
		next := device_layout_fonts(source, 2, 25)
		assert voidptr(next) != voidptr(previous)
		assert voidptr(device_layout_fonts(source, 2, 25)) == voidptr(next)
		assert next.fonts[0].font.point_size == 20
		assert next.fonts[0].font.variations.weight == font.variations.weight
		assert next.fonts[0].font.variations.width == font.variations.width
		assert next.fonts[0].font.variations.opsz == font.variations.opsz
		assert next.fonts[0].font.variations.axis_values() == font.variations.axis_values()
		assert next.fonts[0].font.features == font.features
		assert next.fonts[0].font.is_invisible == font.is_invisible
		assert next.fonts[0].font.italic == font.italic
		assert next.fonts[0].font.font_rendering_policy == font.font_rendering_policy
		assert voidptr(next.fonts[0].font.typeface) == voidptr(font.typeface)
		previous = next
	}
	assert original.fonts[0].font.point_size == 18.75
	assert original.fonts[0].font.variations.weight == 400
	assert original.fonts[0].font.variations.width == 100
	assert original.fonts[0].font.variations.opsz? == 13.5
	assert original.fonts[0].font.variations.axis_value('TEST')? == 7
	assert original.fonts[0].font.features[0].value == 0
	assert !original.fonts[0].font.is_invisible
	assert !original.fonts[0].font.italic
	assert original.fonts[0].font.typeface.family_name == 'Arial'
}

fn test_device_font_cascade_rechecks_character_ranges_fallbacks_and_pending_faces() {
	mut source := projected_font_cache_source()
	first := device_layout_fonts(source, 2, 25)
	source.fonts[0] = FontCascadeEntry{
		font:           source.fonts[0].font
		unicode_ranges: [UnicodeRange{ start: 65, end: 90 }]
	}
	ranged := device_layout_fonts(source, 2, 25)
	assert voidptr(ranged) != voidptr(first)
	assert first.fonts[0].unicode_ranges[0].start == 32
	assert ranged.fonts[0].unicode_ranges[0].start == 65
	source.set_last_resort_font(source.fonts[0].font)
	last_resort := device_layout_fonts(source, 2, 25)
	assert voidptr(last_resort) != voidptr(ranged)
	assert ranged.last_resort_font == unsafe { nil }
	assert last_resort.last_resort_font.point_size == 18.75
	source.last_resort_font.point_size = 15
	replaced := device_layout_fonts(source, 2, 25)
	assert voidptr(replaced) != voidptr(last_resort)
	assert replaced.last_resort_font.point_size == 30
	assert last_resort.last_resort_font.point_size == 18.75
	source.last_resort_font.variations.set_axis('TEST', 11)
	source.last_resort_font.features[0].value = 1
	fallback_changed := device_layout_fonts(source, 2, 25)
	assert voidptr(fallback_changed) != voidptr(replaced)
	assert fallback_changed.last_resort_font.variations.axis_value('TEST')? == 11
	assert fallback_changed.last_resort_font.features[0].value == 1
	assert replaced.last_resort_font.variations.axis_value('TEST')? == 7
	assert replaced.last_resort_font.features[0].value == 0
	source.last_resort_font = unsafe { nil }
	removed := device_layout_fonts(source, 2, 25)
	assert voidptr(removed) != voidptr(fallback_changed)
	assert removed.last_resort_font == unsafe { nil }
	source.pending_faces << PendingFontFace{ font_index: 0, unicode_ranges: [UnicodeRange{ start: 97, end: 122 }] }
	pending := device_layout_fonts(source, 2, 25)
	assert pending.pending_faces.len == 1
	assert voidptr(device_layout_fonts(source, 2, 25)) != voidptr(pending)
	assert removed.pending_faces.len == 0
}

fn test_device_font_cascade_rejects_modified_projection_and_keeps_pixel_rounding_policy() {
	source := projected_font_cache_source()
	mut first := device_layout_fonts(source, 2, 25.125)
	assert first.fonts[0].font.pixel_size_override_? == f32(browser_font_size_for_rendering(25.125))
	mut font := owned_platform_font(&first.fonts[0].font)
	font.point_size = 99
	first.fonts[0] = FontCascadeEntry{ font: font, unicode_ranges: first.fonts[0].unicode_ranges }
	replacement := device_layout_fonts(source, 2, 25.125)
	assert voidptr(replacement) != voidptr(first)
	assert replacement.fonts[0].font.point_size == 18.75
	assert first.fonts[0].font.point_size == 99
	changed_pixels := device_layout_fonts(source, 2, 25.875)
	assert voidptr(changed_pixels) != voidptr(replacement)
	assert changed_pixels.fonts[0].font.pixel_size_override_? == f32(browser_font_size_for_rendering(25.875))
	assert replacement.fonts[0].font.pixel_size_override_? == f32(browser_font_size_for_rendering(25.125))
}

fn test_device_font_cascade_cache_stays_inside_its_retained_document_owner() {
	mut owner := platform.new_retained_arena('projected font cascade owner')
	mut scope := owner.enter()
	source := projected_font_cache_source()
	mut scratch := platform.begin_thread_scratch('projected cascade scratch')
	projected := device_layout_fonts(source, 2, 25)
	scratch.finish()
	$if prealloc {
		assert owner.arena.contains(voidptr(source))
		assert owner.arena.contains(voidptr(projected))
		assert owner.arena.contains(projected.fonts.data)
	}
	assert voidptr(device_layout_fonts(source, 2, 25)) == voidptr(projected)
	assert projected.fonts[0].font.point_size == 18.75
	scope.finish()
	owner.release()
}

fn test_device_font_cascade_does_not_store_document_owned_fonts_on_a_persistent_source() {
	source := projected_font_cache_source()
	mut owner := platform.new_retained_arena('standalone font computer borrower')
	mut scope := owner.enter()
	first := device_layout_fonts(source, 2, 25)
	$if prealloc {
		assert !owner.arena.contains(voidptr(source))
		assert owner.arena.contains(voidptr(first))
		assert source.device_layout_font_projection_ == unsafe { nil }
	}
	scope.finish()
	owner.release()
	second := device_layout_fonts(source, 2, 25)
	assert second.fonts[0].font.point_size == 18.75
	assert voidptr(device_layout_fonts(source, 2, 25)) == voidptr(second)
}

fn test_device_font_cascade_shared_typeface_changes_replace_only_the_native_handle() {
	source := projected_font_cache_source()
	projected := device_layout_fonts(source, 2, 25)
	old_handle := projected.fonts[0].font.font_for_rendering()
	mut typeface := source.fonts[0].font.typeface
	typeface.family_name = 'Serif'
	typeface.source_path = '/fixture/changed-typeface.ttf'
	next := device_layout_fonts(source, 2, 25)
	assert voidptr(next) == voidptr(projected)
	new_handle := next.fonts[0].font.font_for_rendering()
	assert voidptr(new_handle) != voidptr(old_handle)
	assert new_handle.family == 'Serif'
	assert new_handle.source_path == '/fixture/changed-typeface.ttf'
	assert old_handle.family == 'Arial'
	assert old_handle.source_path == ''
}

fn test_device_font_cascade_does_not_retain_an_embedded_document_projection() {
	mut host := platform.new_retained_arena('projected font host')
	mut host_scope := host.enter()
	source := projected_font_cache_source()
	first := device_layout_fonts(source, 2, 25)
	mut child := platform.new_retained_arena('projected font child')
	mut child_scope := child.enter_nested()
	other := device_layout_fonts(source, 3, 37.5)
	assert other.fonts[0].font.point_size == 28.125
	$if prealloc {
		assert child.arena.contains(voidptr(other))
		assert voidptr(source.device_layout_font_projection_) == voidptr(first)
	}
	child_scope.finish()
	child.release()
	// Inspect only the source owner's cache after retiring the nested owner.
	assert device_layout_fonts(source, 2, 25).fonts[0].font.point_size == 18.75
	assert voidptr(device_layout_fonts(source, 2, 25)) == voidptr(source.device_layout_font_projection_)
	host_scope.finish()
	host.release()
}
