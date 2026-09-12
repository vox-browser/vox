module css

import dom

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
		typeface: PlatformTypeface{
			family_name: 'Latin A'
		}
	}, [UnicodeRange{ start: u32(`A`), end: u32(`A`) }])
	list.add(PlatformFont{
		typeface: PlatformTypeface{
			family_name: 'Unrestricted'
		}
	}, [])
	assert list.font_for_code_point(u32(`A`)).typeface.family_name == 'Latin A'
	assert list.font_for_code_point(u32(`B`)).typeface.family_name == 'Unrestricted'

	mut ranged_only := FontCascadeList.create()
	ranged_only.add(PlatformFont{
		typeface: PlatformTypeface{
			family_name: 'Latin A'
		}
	}, [UnicodeRange{ start: u32(`A`), end: u32(`A`) }])
	ranged_only.set_last_resort_font(PlatformFont{
		typeface: PlatformTypeface{
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

fn test_stylesheet_font_face_rules_register_local_true_type_loaders() {
	$if macos {
		sheet := parse_css_stylesheet_with_parser("@font-face { font-family: Fixture; src: url('Arial.ttf') format('truetype'); }", 'file:///System/Library/Fonts/Supplemental/main.css')
		mut computer := FontComputer.create()
		set := FontFaceSet.create_for_font_computer(computer)
		computer.load_fonts_from_css_rules(sheet.css_rules().rules, set)
		assert computer.font_faces.len == 1
		for _, faces in computer.font_faces {
			assert faces.len == 1
			typeface := faces[0].parsed_font or { panic('font face was not loaded') }
			assert typeface.family_name == 'Fixture'
			assert typeface.source_path == '/System/Library/Fonts/Supplemental/Arial.ttf'
		}
	}
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
