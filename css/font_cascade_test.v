module css

import dom
import math
import os
import platform

fn test_system_ui_generic_font_family_list_parses() {
	parsed := parse_css_value_logic(.font_family, 'system-ui, sans-serif') or {
		panic('failed to parse a valid generic font-family list')
	}
	assert parsed is StyleValueList
	list := parsed as StyleValueList
	assert list.values().len == 2
	assert list.values()[0].serialize(.normal) == 'system-ui'
	assert list.values()[1].serialize(.normal) == 'sans-serif'
}

fn test_font_cascade_selects_unicode_range_then_fallback() {
	mut list := FontCascadeList.create()
	list.add(PlatformFont{
		typeface: &PlatformTypeface{
			family_name: 'Latin A'
		}
	}, [UnicodeRange{ start: u32(`A`), end: u32(`A`) }])
	list.add(PlatformFont{
		typeface: &PlatformTypeface{
			family_name: 'Unrestricted'
		}
	}, [])
	assert list.font_for_code_point(u32(`A`)).typeface.family_name == 'Latin A'
	assert list.font_for_code_point(u32(`B`)).typeface.family_name == 'Unrestricted'

	mut ranged_only := FontCascadeList.create()
	ranged_only.add(PlatformFont{
		typeface: &PlatformTypeface{
			family_name: 'Latin A'
		}
	}, [UnicodeRange{ start: u32(`A`), end: u32(`A`) }])
	ranged_only.set_last_resort_font(PlatformFont{
		typeface: &PlatformTypeface{
			family_name: 'Last resort'
		}
	})
	assert ranged_only.font_for_code_point(u32(`B`)).typeface.family_name == 'Last resort'
}

fn test_computed_font_list_uses_computed_font_properties_and_caches_result() {
	mut computed := ComputedProperties.new()
	computed.set_property_without_modifying_flags(.font_family, &dom.StyleValue{
		css_text: 'serif, monospace'
	})
	computed.set_property_without_modifying_flags(.font_size, &dom.StyleValue{
		css_text: '20px'
	})
	computed.set_property_without_modifying_flags(.font_weight, &dom.StyleValue{
		css_text: '700'
	})
	computer := FontComputer.create()
	first_list := computed.computed_font_list(computer)
	second_list := computed.computed_font_list(computer)
	assert voidptr(first_list) == voidptr(second_list)
	assert !first_list.is_empty()
	font := computed.first_available_computed_font(computer)
	assert font.point_size == 15
	assert font.variations.weight == 700
	$if macos {
		assert font.typeface.family_name == 'Serif'
	}
}

fn test_first_available_computed_font_retains_owned_value_across_allocation_pressure() {
	mut computed := ComputedProperties.new()
	computed.set_property_without_modifying_flags(.font_family, &dom.StyleValue{
		css_text: 'sans-serif'
	})
	computer := FontComputer.create()
	selected := computed.first_available_computed_font(computer)
	expected_family := selected.typeface.family_name
	mut allocation_pressure := []string{cap: 4096}
	for index in 0 .. 4096 {
		allocation_pressure << '${index}-${expected_family}'
	}
	retained := computed.first_available_computed_font(computer)
	assert retained.typeface.family_name == expected_family
	metrics := platform.Font{
		family: retained.typeface.family_name
		point_size: retained.point_size / 0.75
		weight: int(retained.variations.weight)
		source_path: retained.typeface.source_path
	}.pixel_metrics()
	assert metrics.size == retained.point_size / 0.75
	assert allocation_pressure.len == 4096
}

fn test_quoted_system_font_family_selects_named_face() {
	$if macos {
		mut computed := ComputedProperties.new()
		computed.set_property_without_modifying_flags(.font_family, &dom.StyleValue{
			css_text: '"Helvetica Neue", Helvetica, Arial, sans-serif'
		})
		computed.set_property_without_modifying_flags(.font_weight, &dom.StyleValue{
			css_text: '700'
		})
		computer := FontComputer.create()
		font := computed.first_available_computed_font(computer)
		assert font.typeface.family_name == 'Helvetica Neue'
		assert font.variations.weight == 700
	}
}

fn test_local_true_type_font_loader_retains_its_source_file() {
	$if macos {
		computer := FontComputer.create()
		mut loader := FontLoader.create(computer, 'Fixture Face', [], [
			URL.from_url('file:///System/Library/Fonts/Supplemental/Arial.ttf'),
		], none)
		font := loader.font_with_point_size(12, FontVariationSettings{}, ShapeFeatures{}) or {
			panic('local TrueType face did not load')
		}
		assert font.typeface.family_name == 'Fixture Face'
		assert font.typeface.source_path == '/System/Library/Fonts/Supplemental/Arial.ttf'
	}
}

fn test_font_face_source_resolves_against_its_stylesheet() {
	descriptors := CSSFontFaceDescriptors.create([]FontFaceDescriptor{})
	font_face_rule := CSSFontFaceRule.create(descriptors)
	wrapper := CSSRule.create_font_face_rule(font_face_rule)
	sheet := CSSStyleSheet.create(CSSRuleList.create([wrapper]), MediaList.create_empty(), 'file:///tmp/site/css/main.css')
	assert font_face_rule.parent_style_sheet? == sheet
	resolved := resolve_font_face_source_url(URL.from_url('../fonts/example.ttf'), font_face_rule)
	assert resolved == 'file:///tmp/site/fonts/example.ttf'
}

fn test_font_face_tracks_declared_width_in_registration_key() {
	mut computer := FontComputer.create()
	mut set := FontFaceSet.create_for_font_computer(computer)
	mut face := FontFaceObject.construct_impl('Width Fixture', FontFaceSource.from_string("url('missing-font.ttf')"), FontFaceDescriptors{
		stretch: 'condensed'
	})
	set.add(face)!
	face.status_ = .loaded
	face.parsed_font = &PlatformTypeface{
		family_name: 'Width Fixture'
	}
	computer.register_font_face(face)

	assert face.declared_width() == 75
	assert face.parsed_font_face().width()? == 75
	assert computer.font_faces.keys() == ['width fixture|0-0|0|75']

	face.set_stretch('expanded')!
	assert face.declared_width() == 125
	assert computer.font_faces.keys() == ['width fixture|0-0|0|125']
}

fn test_font_matching_filters_width_before_weight() {
	mut computer := FontComputer.create()
	mut set := FontFaceSet.create_for_font_computer(computer)
	mut condensed := FontFaceObject.construct_impl('Width Match', FontFaceSource.from_string("url('condensed.ttf')"), FontFaceDescriptors{
		stretch: 'condensed'
	})
	condensed.status_ = .loaded
	condensed.parsed_font = &PlatformTypeface{
		family_name: 'Width Match'
		source_path: 'condensed.ttf'
	}
	set.add(condensed)!
	computer.register_font_face(condensed)

	mut normal := FontFaceObject.construct_impl('Width Match', FontFaceSource.from_string("url('normal.ttf')"), FontFaceDescriptors{})
	normal.status_ = .loaded
	normal.parsed_font = &PlatformTypeface{
		family_name: 'Width Match'
		source_path: 'normal.ttf'
	}
	set.add(normal)!
	computer.register_font_face(normal)

	matched := computer.compute_font_for_style_values(['Width Match'], CSSPixels.new(16), 0, 400, Percentage{ value_: 80 }, .none_, map[string]f64{}, FontFeatureData{})
	assert matched.fonts.len == 1
	assert matched.fonts[0].font.typeface.source_path == 'condensed.ttf'
}

fn test_stylesheet_font_face_rules_register_local_true_type_loaders() {
	$if macos {
		sheet := parse_css_stylesheet_with_parser("@font-face { font-family: Fixture; src: url('Arial.ttf') format('truetype'); }", 'file:///System/Library/Fonts/Supplemental/main.css')
		mut computer := FontComputer.create()
		set := FontFaceSet.create_for_font_computer(computer)
		computer.load_fonts_from_css_rules(sheet.css_rules().rules, set)
		assert computer.font_faces.len == 1
		face := set.set_entries()[0]
		assert face.status() == .unloaded
		mut cascade := computer.compute_font_for_style_values(['Fixture'], CSSPixels.new(16), 0,
			400, Percentage{ value_: 100 }, .auto_, map[string]f64{}, FontFeatureData{})
		assert cascade.pending_faces.len == 1
		cascade.font_for_code_point(u32(`A`))
		assert face.status() == .unloaded
		cascade.font_for_code_point_for_shaping(u32(`A`))
		assert face.status() == .loaded
		assert face.parsed_font != unsafe { nil }
		typeface := face.parsed_font
		assert typeface.family_name == 'Fixture'
		assert typeface.source_path == '/System/Library/Fonts/Supplemental/Arial.ttf'
	}
}

fn test_loaded_file_backed_font_cascade_keeps_heap_owned_entries() {
	$if macos {
		sheet := parse_css_stylesheet_with_parser("@font-face { font-family: Fixture; src: url('Arial.ttf') format('truetype'); }", 'file:///System/Library/Fonts/Supplemental/main.css')
		mut computer := FontComputer.create()
		set := FontFaceSet.create_for_font_computer(computer)
		computer.load_fonts_from_css_rules(sheet.css_rules().rules, set)
		mut pending := computer.compute_font_for_style_values(['Fixture'], CSSPixels.new(16),
			0, 400, Percentage{ value_: 100 }, .auto_, map[string]f64{}, FontFeatureData{})
		pending.font_for_code_point_for_shaping(u32(`A`))
		loaded := computer.compute_font_for_style_values(['Fixture'], CSSPixels.new(16), 0,
			400, Percentage{ value_: 100 }, .auto_, map[string]f64{}, FontFeatureData{})
		cached := computer.compute_font_for_style_values(['Fixture'], CSSPixels.new(16), 0,
			400, Percentage{ value_: 100 }, .auto_, map[string]f64{}, FontFeatureData{})
		assert voidptr(loaded) == voidptr(cached)
		mut allocation_pressure := []string{cap: 4096}
		for index in 0 .. 4096 {
			allocation_pressure << 'file-backed-font-${index}'
		}
		selected := cached.font_for_code_point(u32(`A`))
		assert selected.typeface.family_name == 'Fixture'
		assert selected.typeface.source_path == '/System/Library/Fonts/Supplemental/Arial.ttf'
		metrics := platform.Font{
			family:      selected.typeface.family_name.clone()
			point_size:  selected.point_size / 0.75
			weight:      int(selected.variations.weight)
			source_path: selected.typeface.source_path.clone()
		}.pixel_metrics()
		assert metrics.size == selected.point_size / 0.75
		assert allocation_pressure.len == 4096
	}
}

fn test_unicode_range_font_face_loads_only_when_a_covered_code_point_is_selected() {
	$if macos {
		sheet := parse_css_stylesheet_with_parser("@font-face { font-family: Subset; src: url('Arial.ttf') format('truetype'); unicode-range: U+41; }", 'file:///System/Library/Fonts/Supplemental/main.css')
		mut computer := FontComputer.create()
		set := FontFaceSet.create_for_font_computer(computer)
		computer.load_fonts_from_css_rules(sheet.css_rules().rules, set)
		face := set.set_entries()[0]

		assert face.status() == .unloaded
		mut cascade := computer.compute_font_for_style_values(['Subset'], CSSPixels.new(16), 0, 400, Percentage{ value_: 100 }, .auto_, map[string]f64{}, FontFeatureData{})
		assert cascade.pending_faces.len == 1
		cascade.font_for_code_point(u32(`B`))
		assert face.status() == .unloaded
		cascade.font_for_code_point_for_shaping(u32(`A`))
		assert face.status() == .loaded
	}
}

fn test_font_cascade_probe_does_not_trigger_pending_face_load() {
	$if macos {
		sheet := parse_css_stylesheet_with_parser("@font-face { font-family: Probe; src: url('Arial.ttf') format('truetype'); unicode-range: U+20; }", 'file:///System/Library/Fonts/Supplemental/main.css')
		mut computer := FontComputer.create()
		set := FontFaceSet.create_for_font_computer(computer)
		computer.load_fonts_from_css_rules(sheet.css_rules().rules, set)
		face := set.set_entries()[0]
		cascade := computer.compute_font_for_style_values(['Probe'], CSSPixels.new(16), 0, 400, Percentage{ value_: 100 }, .auto_, map[string]f64{}, FontFeatureData{})

		cascade.font_for_code_point(u32(` `))
		assert face.status() == .unloaded
	}
}

fn pending_font_display_face(display string, elapsed_ms u32) &FontFaceObject {
	mut face := FontFaceObject.construct_impl('Pending ${display}', FontFaceSource.from_string("url('pending.woff')"), FontFaceDescriptors{
		display: display
	})
	// Keep the request pending so the display period, rather than the synchronous
	// test loader, decides whether the fallback has ink.
	face.status_ = .loading
	face.set_font_display_time_for_testing(elapsed_ms)
	return face
}

fn pending_font_display_state(display string, elapsed_ms u32) PendingFontState {
	mut face := pending_font_display_face(display, elapsed_ms)
	return face.resolve_for_rendering()
}

fn test_font_display_timeline_period_boundaries() {
	assert pending_font_display_state('auto', 0) == .invisible
	assert pending_font_display_state('auto', 2999) == .invisible
	assert pending_font_display_state('auto', 3000) == .visible
	assert pending_font_display_state('block', 2999) == .invisible
	assert pending_font_display_state('block', 3000) == .visible
	assert pending_font_display_state('swap', 0) == .visible
	assert pending_font_display_state('fallback', 99) == .invisible
	assert pending_font_display_state('fallback', 100) == .visible
	assert pending_font_display_state('fallback', 3099) == .visible
	assert pending_font_display_state('fallback', 3100) == .failed
	assert pending_font_display_state('optional', 99) == .invisible
	assert pending_font_display_state('optional', 100) == .failed
}

fn test_font_display_timeline_arms_and_cancels_the_host_deadline_timer() {
	mut face := FontFaceObject.construct_impl('Timed block', FontFaceSource.from_string("url('pending.woff')"), FontFaceDescriptors{
		display: 'block'
	})
	face.status_ = .loading
	assert face.resolve_for_rendering() == .invisible
	mut timer := face.font_download_timer_ or { panic('display timer was not created') }
	assert timer.is_active()
	assert timer.interval() > 0
	assert timer.interval() <= 3000
	face.set_font_display_time_for_testing(3000)
	assert !timer.is_active()
	assert face.resolve_for_rendering() == .visible
}

fn test_initial_paint_waits_only_for_pending_cache_resident_font_work() {
	mut computer := FontComputer.create()
	mut face := pending_font_display_face('block', 0)
	assert face.resolve_for_rendering() == .invisible
	mut loader := FontLoader.create(computer, face.family(), face.unicode_ranges(), []URL{}, none)
	loader.has_started_request_ = true
	loader.requires_network_ = false
	face.font_loader_ = loader
	computer.register_font_face(face)

	assert computer.should_defer_initial_paint()
	assert !computer.has_completed_initial_paint()
	loader.requires_network_ = true
	assert !computer.should_defer_initial_paint()
	assert computer.has_completed_initial_paint()
	assert computer.initial_paint_had_pending_fonts()
	assert !computer.should_defer_initial_paint()
}

fn test_loaded_document_font_invalidates_style_before_the_first_paint() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	mut root := document.create_element_ns(dom.namespace_html_uri, 'html') or { panic(err) }
	root.set_attribute_value('style', 'font-family:serif;font-size:16px')
	mut target := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	target.set_attribute_value('style', 'font-family:"Loaded Fixture",sans-serif;font-size:16px')
	mut unrelated := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	unrelated.set_attribute_value('style', 'font-family:serif;font-size:16px')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(target.as_node()) or { panic(err) }
	root_node.append_child(unrelated.as_node()) or { panic(err) }
	style_computer := css_style_computer_for(document)
	mut computer := unsafe { &FontComputer(style_computer.font_computer()) }
	document.update_style()
	bridge := target.el_computed_properties() or { panic('missing target style') }
	mut style := unsafe { &ComputedProperties(computed_properties_from_dom(bridge) or { panic('missing style owner') }) }
	previous_cascade := style.computed_font_list(computer)
	assert !computer.has_completed_initial_paint()

	computer.did_load_font('Loaded Fixture')

	assert !document.needs_full_style_update()
	assert target.has_pending_font_input_update()
	assert document.element_needs_style_update(target)
	assert document_node.child_needs_style_update()
	assert !unrelated.has_pending_font_input_update()
	assert !computer.has_completed_initial_paint()
	document.update_style()
	assert !target.has_pending_font_input_update()
	assert voidptr(target.el_computed_properties() or { panic('missing target style') }) == voidptr(bridge)
	assert style.cached_computed_font_list_generation_ == computer.environment_generation()
	assert voidptr(style.computed_font_list(computer)) != voidptr(previous_cascade)
	assert !computer.has_completed_initial_paint()
}

fn test_local_woff2_font_is_prepared_for_metrics_and_shaping() {
	$if macos {
		fixture := os.real_path(os.join_path(os.dir(os.dir(@FILE)), '..', '3rd', 'ladybird',
			'Tests', 'LibWeb', 'Assets', 'NotoSansEthiopic.woff2'))
		if !os.is_file(fixture) {
			return
		}
		prepared := platform.prepare_font_file(fixture) or { panic('WOFF2 preparation failed') }
		assert prepared != fixture
		assert os.is_file(prepared)
		font := platform.Font{
			family: 'Noto Sans Ethiopic'
			point_size: 16
			source_path: prepared
		}
		metrics := font.pixel_metrics()
		assert math.round(f64(metrics.ascent)) + math.round(f64(metrics.descent)) == 22
		assert font.contains_glyph(u32(0x1200))
	}
}

fn test_pending_font_face_preserves_fallback_metrics_and_suppresses_ink_during_block() {
	mut face := pending_font_display_face('block', 0)
	mut cascade := FontCascadeList.create()
	cascade.add_pending_face(face)
	cascade.add(PlatformFont{
		typeface:   &PlatformTypeface{
			family_name: 'Fallback'
		}
		point_size: 12
	}, [])

	probe := cascade.font_for_code_point(u32(`A`))
	assert !probe.is_invisible
	assert face.font_download_timer_start_ns_ == none
	selected := cascade.font_for_code_point_for_shaping(u32(`A`))
	assert selected.typeface.family_name == probe.typeface.family_name
	assert selected.point_size == probe.point_size
	assert selected.is_invisible
	assert face.font_download_timer_start_ns_ != none
}

fn test_pending_preferred_face_does_not_resolve_later_fallback_faces() {
	mut preferred := pending_font_display_face('swap', 0)
	mut unused := pending_font_display_face('swap', 0)
	mut cascade := FontCascadeList.create()
	cascade.add_pending_face(preferred)
	cascade.add_pending_face(unused)
	cascade.add(PlatformFont{
		typeface: &PlatformTypeface{
			family_name: 'Fallback'
		}
	}, [])

	selected := cascade.font_for_code_point_for_shaping(u32(`A`))
	assert selected.typeface.family_name == 'Fallback'
	assert preferred.font_download_timer_start_ns_ != none
	assert unused.font_download_timer_start_ns_ == none
}

fn test_loaded_script_font_face_is_registered_for_matching_and_removed_with_its_set_entry() {
	$if macos {
		mut computer := FontComputer.create()
		mut set := FontFaceSet.create_for_font_computer(computer)
		mut face := FontFaceObject.construct_impl('Script Fixture', FontFaceSource.from_string("url('file:///System/Library/Fonts/Supplemental/Arial.ttf')"), FontFaceDescriptors{})
		set.add(face)!
		face.load()

		assert face.status() == .loaded
		assert computer.font_faces.len == 1
		matched := computer.compute_font_for_style_values(['Script Fixture'], CSSPixels.new(20), 0, 400, Percentage{ value_: 100 }, .auto_, map[string]f64{}, FontFeatureData{})
		assert !matched.is_empty()
		assert matched.fonts[0].font.typeface.family_name == 'Script Fixture'

		face.set_family('Renamed Fixture')!
		old_family := computer.compute_font_for_style_values(['Script Fixture'], CSSPixels.new(20), 0, 400, Percentage{ value_: 100 }, .auto_, map[string]f64{}, FontFeatureData{})
		assert old_family.fonts[0].font.typeface.family_name == 'Default'
		renamed := computer.compute_font_for_style_values(['Renamed Fixture'], CSSPixels.new(20), 0, 400, Percentage{ value_: 100 }, .auto_, map[string]f64{}, FontFeatureData{})
		assert renamed.fonts[0].font.typeface.family_name == 'Script Fixture'

		assert set.delete_(face)
		assert computer.font_faces.len == 0
		fallback := computer.compute_font_for_style_values(['Renamed Fixture'], CSSPixels.new(20), 0, 400, Percentage{ value_: 100 }, .auto_, map[string]f64{}, FontFeatureData{})
		assert fallback.fonts[0].font.typeface.family_name == 'Default'
	}
}

fn test_font_faces_with_the_same_url_share_one_loader() {
	$if macos {
		mut computer := FontComputer.create()
		mut set := FontFaceSet.create_for_font_computer(computer)
		source := FontFaceSource.from_string("url('file:///System/Library/Fonts/Supplemental/Arial.ttf')")
		mut face_a := FontFaceObject.construct_impl('Dedup Fixture', source, FontFaceDescriptors{
			weight: '400'
		})
		mut face_b := FontFaceObject.construct_impl('Dedup Fixture', source, FontFaceDescriptors{
			weight: '700'
		})
		set.add(face_a)!
		set.add(face_b)!

		face_a.load()
		face_b.load()
		assert face_a.status() == .loaded
		assert face_b.status() == .loaded
		assert computer.loaders_by_url.len == 1
		assert face_a.parsed_font != unsafe { nil }
		assert face_b.parsed_font != unsafe { nil }
		assert face_a.parsed_font.source_path == face_b.parsed_font.source_path
	}
}
