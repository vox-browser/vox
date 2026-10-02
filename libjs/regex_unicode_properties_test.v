module libjs

fn test_regex_unicode_aliases_are_exact_and_keep_category_aggregates() {
	for pair in [['Lu', 'Uppercase_Letter'], ['LC', 'Cased_Letter'],
		['L', 'Letter'], ['M', 'Mark'], ['N', 'Number'], ['P', 'Punctuation'],
		['S', 'Symbol'], ['Z', 'Separator'], ['C', 'Other']] {
		assert regex_unicode_category_from_string(pair[0]) or { panic(pair[0]) } == regex_unicode_category_from_string(pair[1]) or {
			panic(pair[1])
		}
	}
	for invalid in ['', 'lu', 'uppercase_letter', 'UppercaseLetter', 'Uppercase-Letter', ' Lu',
		'Lu ', 'Lu\x00'] {
		assert regex_unicode_category_from_string(invalid) == none
	}
	assert regex_unicode_property_from_string('Alpha') == regex_unicode_property_from_string('Alphabetic')
	assert regex_unicode_script_from_string('Grek') == regex_unicode_script_from_string('Greek')
	assert regex_unicode_script_from_string('Beria_Erfe') or { panic('missing Unicode 17 script') } == 208
	assert regex_unicode_script_from_string('greek') == none
	assert regex_unicode_property_from_string('ascii') == none
}

fn test_regex_unicode_category_and_binary_case_closures_are_cached() {
	lower := regex_unicode_category_from_string('Ll') or { panic('Ll') }
	assert !regex_unicode_has_general_category(0x41, lower, false)
	assert regex_unicode_has_general_category(0x41, lower, true)
	assert regex_unicode_has_general_category(0xdf, lower, true)
	assert !regex_unicode_has_general_category(0x30, lower, true)
	assert regex_unicode_has_general_category(0x41, lower, true)
	property := regex_unicode_property_from_string('Lowercase') or { panic('Lowercase') }
	assert !regex_unicode_has_property(0x41, property, false)
	assert regex_unicode_has_property(0x41, property, true)
	assert !regex_unicode_has_property(0x30, property, true)
	assert regex_unicode_has_property(0x41, property, true)
	assert regex_property_matches(0xd800, 'Any', none)
	assert !regex_property_matches(0x110000, 'Any', none)
	assert !regex_property_matches(0x378, 'Assigned', none)
	assert regex_property_matches(0x7f, 'ASCII', none)
	assert !regex_property_matches(0x80, 'ASCII', none)
	// Standard ICU retains Private_Use, including Apple's legacy PUA characters.
	assert regex_property_matches(0xf882, 'Co', none)
	assert !regex_property_matches(0xf882, 'Letter', none)
	assert !regex_property_matches(0xf882, 'Alphabetic', none)
}

fn test_regex_resolution_preserves_value_presence_and_script_extensions() {
	for name in ['sc', 'Script'] {
		property := regex_resolve_property(name, 'Greek') or { panic(name) }
		assert property.kind == .script
		assert regex_resolved_property_matches(0x3b1, property)
		assert !regex_resolved_property_matches(0x41, property)
	}
	for name in ['scx', 'Script_Extensions'] {
		property := regex_resolve_property(name, 'Hira') or { panic(name) }
		assert property.kind == .script_extension
		assert regex_resolved_property_matches(0x30fc, property)
	}
	assert !regex_property_matches(0x30fc, 'sc', 'Hiragana')
	assert regex_property_matches(0x30fc, 'scx', 'Hiragana')
	assert regex_resolve_property('Greek', none) or { panic('Greek') } == RegexResolvedProperty{
		kind: .script
		id:   14
	}
	assert regex_property_matches(0x3b1, 'Greek', none)
	assert !regex_is_valid_ecma262_property('Greek', none)
	assert regex_is_valid_ecma262_property('Script', 'Greek')
	assert regex_is_valid_ecma262_property('gc', 'L')
	assert regex_is_valid_ecma262_property('Letter', none)
	assert regex_is_valid_ecma262_property('ASCII', none)
	assert regex_resolve_property('gc', none) == none
	assert regex_resolve_property('gc', '') == none
	assert regex_resolve_property('ASCII', '') == none
	assert regex_resolve_property('script', 'Greek') == none
	assert !regex_is_valid_ecma262_property('Full_Composition_Exclusion', none)
	assert regex_is_string_property('RGI_Emoji')
	assert regex_is_valid_ecma262_property('RGI_Emoji', none)
	assert !regex_is_string_property('Emoji')
}

fn test_regex_property_case_closure_retains_any_and_all_semantics() {
	assert !regex_property_matches(0x61, 'Lu', none)
	assert regex_property_matches_case_insensitive(0x61, 'Lu', none)
	assert !regex_property_all_case_equivalents_match(0x61, 'Lu', none)
	assert regex_property_all_case_equivalents_match(0x61, 'Letter', none)
	assert regex_property_matches_case_insensitive(0x212a, 'ASCII', none)
	assert !regex_property_all_case_equivalents_match(0x212a, 'ASCII', none)
	assert !regex_property_matches_case_insensitive(0x61, 'unknown', none)
	assert !regex_property_all_case_equivalents_match(0x61, 'unknown', none)
	assert regex_property_matches_case_insensitive(0xd800, 'Cs', none)
}

fn test_regex_unicode_rust_scalar_predicates_preserve_ascii_shortcuts() {
	assert regex_has_space_separator_category(0x20)
	assert regex_has_space_separator_category(0xa0)
	assert !regex_has_space_separator_category(0x9)
	assert regex_has_identifier_start_property(0x41)
	assert regex_has_identifier_start_property(0x3b1)
	assert !regex_has_identifier_start_property(0x5f)
	assert regex_has_identifier_continue_property(0x5f)
	assert regex_has_identifier_continue_property(0x30)
	assert !regex_has_identifier_continue_property(0x24)
	assert !regex_has_identifier_start_property(0x110000)
}
