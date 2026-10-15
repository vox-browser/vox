module css

import dom

fn sharing_font_style(family string, size string) &ComputedProperties {
	mut style := ComputedProperties.new()
	style.set_property_without_modifying_flags(.font_family, &dom.StyleValue{ css_text: family })
	style.set_property_without_modifying_flags(.font_size, &dom.StyleValue{ css_text: size })
	return style
}

fn sharing_font_feature_value(font &PlatformFont, tag string) ?u32 {
	for feature in font.features {
		if feature.tag == tag { return feature.value }
	}
	return none
}

fn test_computed_font_cascades_share_the_font_computer_cache_across_styles() {
	mut computer := FontComputer.create()
	mut first := sharing_font_style('serif', '20px')
	mut second := sharing_font_style('serif', '20px')
	list := first.computed_font_list(computer)
	assert voidptr(second.computed_font_list(computer)) == voidptr(list)
	cached := computer.compute_font_for_style_values(['serif'], first.font_size(), first.font_slope(),
		first.font_weight(), first.font_width(), first.font_optical_sizing(),
		first.font_variation_settings(), first.font_feature_data())
	assert voidptr(list) == voidptr(cached)
	first.set_property_without_modifying_flags(.font_size, &dom.StyleValue{ css_text: '24px' })
	larger := first.computed_font_list(computer)
	assert voidptr(larger) != voidptr(list)
	assert larger.font_for_code_point(u32(`A`)).point_size == 18
	assert second.first_available_computed_font(computer).point_size == 15
	first.clear_computed_font_list_cache()
	gc_collect()
	assert voidptr(second.computed_font_list(computer)) == voidptr(list)
	assert list.font_for_code_point(u32(`A`)).point_size == 15
}

fn test_shared_computed_cascades_keep_old_snapshots_across_environment_and_owner_changes() {
	mut computer := FontComputer.create()
	mut first := sharing_font_style('serif', '20px')
	mut second := sharing_font_style('serif', '20px')
	old := first.computed_font_list(computer)
	old_font := first.first_available_computed_font(computer)
	old_family := old_font.typeface.family_name
	assert voidptr(second.computed_font_list(computer)) == voidptr(old)
	computer.clear_computed_font_cache('serif')
	fresh := first.computed_font_list(computer)
	assert voidptr(fresh) != voidptr(old)
	assert voidptr(second.computed_font_list(computer)) == voidptr(fresh)
	other_computer := FontComputer.create()
	other := first.computed_font_list(other_computer)
	assert voidptr(other) != voidptr(fresh)
	assert voidptr(first.computed_font_list(computer)) == voidptr(fresh)
	gc_collect()
	assert old_font.typeface.family_name == old_family
	assert old_font.point_size == 15
	assert old.font_for_code_point(u32(`A`)).typeface.family_name == old_family
	assert fresh.font_for_code_point(u32(`A`)).point_size == 15
}

fn test_shared_computed_cascade_owns_feature_tags_and_axes_after_style_replacement() {
	computer := FontComputer.create()
	mut first := sharing_font_style('serif', '20px')
	mut second := sharing_font_style('serif', '20px')
	mut styles := [first, second]
	for mut style in styles {
		style.set_property_without_modifying_flags(.font_feature_settings,
			&dom.StyleValue{ css_text: '"liga" 0, "ss01" 3' })
		style.set_property_without_modifying_flags(.font_variation_settings,
			&dom.StyleValue{ css_text: '"wdth" 110, "wght" 450' })
	}
	original := first.computed_font_list(computer)
	assert voidptr(second.computed_font_list(computer)) == voidptr(original)
	retained := original.font_for_code_point(u32(`A`))
	assert (sharing_font_feature_value(retained, 'liga') or { panic('missing liga') }) == 0
	assert (sharing_font_feature_value(retained, 'ss01') or { panic('missing ss01') }) == 3
	assert (retained.variations.axis_value('wdth') or { panic('missing wdth') }) == 110
	first.set_property_without_modifying_flags(.font_feature_settings,
		&dom.StyleValue{ css_text: '"liga" 1, "ss01" 7' })
	first.set_property_without_modifying_flags(.font_variation_settings,
		&dom.StyleValue{ css_text: '"wdth" 130, "wght" 700' })
	replacement := first.computed_font_list(computer)
	assert voidptr(replacement) != voidptr(original)
	gc_collect()
	assert voidptr(second.computed_font_list(computer)) == voidptr(original)
	assert (sharing_font_feature_value(retained, 'liga') or { panic('lost retained liga') }) == 0
	assert (sharing_font_feature_value(retained, 'ss01') or { panic('lost retained ss01') }) == 3
	assert (retained.variations.axis_value('wdth') or { panic('lost retained wdth') }) == 110
	changed := replacement.font_for_code_point(u32(`A`))
	assert (sharing_font_feature_value(changed, 'liga') or { panic('missing changed liga') }) == 1
	assert (sharing_font_feature_value(changed, 'ss01') or { panic('missing changed ss01') }) == 7
	assert (changed.variations.axis_value('wdth') or { panic('missing changed wdth') }) == 130
}

fn test_shared_pending_cascade_preserves_font_display_and_nonloading_probe_semantics() {
	mut computer := FontComputer.create()
	mut face := FontFaceObject.construct_impl('Shared Pending',
		FontFaceSource.from_string('url("pending.woff")'),
		FontFaceDescriptors{ display: 'block', unicode_range: 'U+41' })
	mut set := FontFaceSet.create_for_font_computer(computer)
	set.add(face)!
	face.status_ = .loading
	mut first := sharing_font_style('"Shared Pending", serif', '20px')
	mut second := sharing_font_style('"Shared Pending", serif', '20px')
	list := first.computed_font_list(computer)
	assert list.pending_faces.len == 1
	assert voidptr(second.computed_font_list(computer)) == voidptr(list)
	assert !list.equals(list)
	assert face.font_download_timer_start_ns_ == none
	assert !list.font_for_code_point(u32(`A`)).is_invisible
	assert !list.font_for_code_point_for_shaping(u32(`B`)).is_invisible
	assert face.font_download_timer_start_ns_ == none
	face.set_font_display_time_for_testing(0)
	blocked := list.font_for_code_point_for_shaping(u32(`A`))
	assert blocked.is_invisible
	assert face.font_download_timer_start_ns_ != none
	assert voidptr(second.computed_font_list(computer).font_for_code_point_for_shaping(u32(`A`))) == voidptr(blocked)
	assert !list.font_for_code_point(u32(`A`)).is_invisible
	face.set_font_display_time_for_testing(3000)
	assert !list.font_for_code_point_for_shaping(u32(`A`)).is_invisible
	fresh := first.computed_font_list(computer)
	assert voidptr(fresh) != voidptr(list)
	assert voidptr(second.computed_font_list(computer)) == voidptr(fresh)
	assert !fresh.equals(fresh)
	gc_collect()
	assert blocked.is_invisible
	assert blocked.point_size == 15
	assert list.pending_faces.len == 1
	assert fresh.pending_faces.len == 1
}

fn test_shared_pending_local_face_refreshes_all_styles_after_shaping_loads_it() {
	$if macos {
		sheet := parse_css_stylesheet_with_parser('@font-face { font-family: "Shared Local"; src: url("Arial.ttf") format("truetype"); unicode-range: U+41; }',
			'file:///System/Library/Fonts/Supplemental/main.css')
		mut computer := FontComputer.create()
		set := FontFaceSet.create_for_font_computer(computer)
		computer.load_fonts_from_css_rules(sheet.css_rules().rules, set)
		face := set.set_entries()[0]
		mut first := sharing_font_style('"Shared Local", serif', '20px')
		mut second := sharing_font_style('"Shared Local", serif', '20px')
		pending := first.computed_font_list(computer)
		assert voidptr(second.computed_font_list(computer)) == voidptr(pending)
		assert pending.pending_faces.len == 1
		_ = first.first_available_computed_font(computer)
		assert face.status() == .unloaded
		_ = pending.font_for_code_point_for_shaping(u32(`A`))
		assert face.status() == .loaded
		loaded := first.computed_font_list(computer)
		assert voidptr(loaded) != voidptr(pending)
		assert voidptr(second.computed_font_list(computer)) == voidptr(loaded)
		assert loaded.pending_faces.len == 0
		assert loaded.font_for_code_point(u32(`A`)).typeface.family_name == 'Shared Local'
		assert loaded.font_for_code_point(u32(`A`)).typeface.source_path == '/System/Library/Fonts/Supplemental/Arial.ttf'
		gc_collect()
		assert pending.pending_faces.len == 1
		assert loaded.font_for_code_point(u32(`A`)).point_size == 15
		assert first.computed_values_line_height_ == first.line_height()
	}
}
