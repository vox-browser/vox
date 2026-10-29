module css

import platform

$if gcboehm ? {
	fn C.GC_gcollect()
	fn C.GC_get_total_bytes() uint
}

fn test_native_font_is_shared_by_metrics_and_rendering_without_repeated_allocation() {
	font := &PlatformFont{
		typeface: &PlatformTypeface{ family_name: 'SerenitySans' }
		point_size: 12.375
	}
	handle := font.font_for_rendering()
	metrics := handle.pixel_metrics()
	assert voidptr(font.font_for_metrics()) == voidptr(handle)
	assert handle.point_size == 16.5
	$if gcboehm ? {
		C.GC_gcollect()
		before := C.GC_get_total_bytes()
		for _ in 0 .. 1024 {
			assert voidptr(font.font_for_rendering()) == voidptr(handle)
			assert font.font_for_metrics().pixel_metrics() == metrics
		}
		assert C.GC_get_total_bytes() == before
	} $else {
		assert font.font_for_rendering().pixel_metrics() == metrics
	}
}

fn test_native_author_font_retains_axes_and_replaces_handles_after_axis_changes() {
	mut font := PlatformFont{
		typeface: &PlatformTypeface{family_name:'Variable fixture',source_path:'/font/variable.ttf'}
		point_size:12
		variations:FontVariationSettings{weight:500,width:90,opsz:16}
	}
	font.variations.set_axis('wght',550)
	font.variations.set_axis('TEST',7)
	first := font.font_for_rendering()
	assert first.requested_variations == [
		platform.FontVariationAxis{tag:0x54455354,value:7},
		platform.FontVariationAxis{tag:0x6f70737a,value:16},
		platform.FontVariationAxis{tag:0x77647468,value:90},
		platform.FontVariationAxis{tag:0x77676874,value:550},
	]
	assert voidptr(font.font_for_rendering()) == voidptr(first)
	mut copy := owned_platform_font(&font)
	assert voidptr(copy.font_for_rendering()) == voidptr(first)
	font.variations.set_axis('wght',650)
	second := font.font_for_rendering()
	assert voidptr(second) != voidptr(first)
	assert second.requested_variations[3].value == 650
	assert first.requested_variations[3].value == 550
	font.variations.opsz = 24
	third := font.font_for_rendering()
	assert voidptr(third) != voidptr(second)
	assert third.requested_variations[1].value == 24
	assert copy.font_for_rendering().requested_variations[1].value == 16
}

fn test_native_font_visibility_changes_replace_the_handle_and_preserve_snapshots() {
	mut font := PlatformFont{
		typeface: &PlatformTypeface{ family_name: 'SerenitySans' }
		point_size: 12
	}
	visible := font.font_for_rendering()
	font.is_invisible = true
	invisible := font.font_for_rendering()
	assert voidptr(visible) != voidptr(invisible)
	assert !visible.is_invisible
	assert invisible.is_invisible
	assert visible.pixel_metrics() == invisible.pixel_metrics()
	font.point_size = 15
	resized := font.font_for_rendering()
	assert voidptr(resized) != voidptr(invisible)
	assert resized.point_size == 20
	assert invisible.point_size == 16
	font.is_invisible = false
	final := font.font_for_rendering()
	assert !final.is_invisible
	assert resized.is_invisible
	$if gcboehm ? { C.GC_gcollect() }
	assert invisible.is_invisible
	assert invisible.point_size == 16
	assert !visible.is_invisible
}

fn test_native_font_cascade_copies_share_immutable_handle_and_detach_after_input_changes() {
	mut source := FontCascadeList.create()
	source.add(PlatformFont{
		typeface: &PlatformTypeface{ family_name: 'SerenitySans' }
		point_size: 12.375
	}, [UnicodeRange{ start: 65, end: 90 }])
	first := source.fonts[0].font.font_for_rendering()
	mut copy := FontCascadeList.create()
	copy.extend(source)
	assert voidptr(copy.fonts[0].font.font_for_rendering()) == voidptr(first)
	assert copy.fonts[0].unicode_ranges == source.fonts[0].unicode_ranges
	mut copied_font := owned_platform_font(&copy.fonts[0].font)
	copied_font.point_size = 18
	replacement := copied_font.font_for_rendering()
	assert voidptr(replacement) != voidptr(first)
	assert replacement.point_size == 24
	assert source.fonts[0].font.font_for_rendering().point_size == 16.5
	assert first.point_size == 16.5
	// Reallocation of the cascade array cannot invalidate a retained native font.
	for _ in 0 .. 128 {
		source.add(PlatformFont{
			typeface: &PlatformTypeface{ family_name: 'Serif' }
			point_size: 10
		}, [])
	}
	$if gcboehm ? { C.GC_gcollect() }
	assert first.pixel_metrics() == (platform.Font{
		family: 'SerenitySans'
		point_size: 16.5
	}).pixel_metrics()
}
