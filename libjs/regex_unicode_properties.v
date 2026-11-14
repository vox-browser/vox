module libjs

// LibUnicode/CharacterTypes.cpp's has_property/resolve_property and exported
// Unicode property helpers, with character_types.rs's Option boundary.
pub fn regex_property_matches(point u32, name string, value ?string) bool {
	if supplied := value {
		if name in ['sc', 'Script', 'scx', 'Script_Extensions'] {
			if script := regex_unicode_script_from_string(supplied) {
				if name in ['sc', 'Script'] { return regex_unicode_has_script(point, script) }
				return regex_unicode_has_script_extension(point, script)
			}
		} else if name in ['gc', 'General_Category'] {
			if category := regex_unicode_category_from_string(supplied) {
				return regex_unicode_has_general_category(point, category, false)
			}
		}
		return false
	}
	if property := regex_unicode_property_from_string(name) {
		return regex_unicode_has_property(point, property, false)
	}
	if category := regex_unicode_category_from_string(name) {
		return regex_unicode_has_general_category(point, category, false)
	}
	if script := regex_unicode_script_from_string(name) {
		return regex_unicode_has_script(point, script)
	}
	return false
}

pub fn regex_resolve_property(name string, value ?string) ?RegexResolvedProperty {
	if supplied := value {
		if name in ['sc', 'Script', 'scx', 'Script_Extensions'] {
			if script := regex_unicode_script_from_string(supplied) {
				return RegexResolvedProperty{
					kind: if name in ['scx', 'Script_Extensions'] {
						.script_extension
					} else {
						.script
					}
					id:   script
				}
			}
		} else if name in ['gc', 'General_Category'] {
			if category := regex_unicode_category_from_string(supplied) { return RegexResolvedProperty{
					kind: .general_category
					id:   category
				} }
		}
		return none
	}
	if property := regex_unicode_property_from_string(name) { return RegexResolvedProperty{
			kind: .binary_property
			id:   property
		} }
	if category := regex_unicode_category_from_string(name) { return RegexResolvedProperty{
			kind: .general_category
			id:   category
		} }
	if script := regex_unicode_script_from_string(name) { return RegexResolvedProperty{
			kind: .script
			id:   script
		} }
	return none
}

pub fn regex_resolved_property_matches(point u32, property RegexResolvedProperty) bool {
	return match property.kind {
		.script { regex_unicode_has_script(point, property.id) }
		.script_extension { regex_unicode_has_script_extension(point, property.id) }
		.general_category { regex_unicode_has_general_category(point, property.id, false) }
		.binary_property { regex_unicode_has_property(point, property.id, false) }
	}
}

pub fn regex_property_matches_case_insensitive(point u32, name string, value ?string) bool {
	canonical := regex_canonicalize(point, true)
	ranges := regex_expand_range_case_insensitive(canonical, canonical)
	for range in ranges {
		for candidate := range.start; candidate <= range.end; candidate++ {
			if regex_property_matches(candidate, name, value) { return true }
		}
	}
	return false
}

pub fn regex_property_all_case_equivalents_match(point u32, name string, value ?string) bool {
	canonical := regex_canonicalize(point, true)
	ranges := regex_expand_range_case_insensitive(canonical, canonical)
	for range in ranges {
		for candidate := range.start; candidate <= range.end; candidate++ {
			if !regex_property_matches(candidate, name, value) { return false }
		}
	}
	return true
}

pub fn regex_is_string_property(name string) bool {
	if property := regex_unicode_property_from_string(name) {
		return regex_unicode_is_ecma262_string_property(property)
	}
	return false
}

pub fn regex_is_valid_ecma262_property(name string, value ?string) bool {
	if supplied := value {
		if name in ['sc', 'Script', 'scx', 'Script_Extensions'] {
			return regex_unicode_script_from_string(supplied) != none
		}
		if name in ['gc', 'General_Category'] {
			return regex_unicode_category_from_string(supplied) != none
		}
		return false
	}
	if property := regex_unicode_property_from_string(name) {
		return regex_unicode_is_ecma262_property(property)
			|| regex_unicode_is_ecma262_string_property(property)
	}
	return regex_unicode_category_from_string(name) != none
}

pub fn regex_has_space_separator_category(point u32) bool {
	if point < 128 { return point == 0x20 || point == 0xa0 }
	return regex_unicode_has_general_category(point, u32(12), false)
}

pub fn regex_has_identifier_start_property(point u32) bool {
	if point < 128 { return (point >= 0x41 && point <= 0x5a) || (point >= 0x61 && point <= 0x7a) }
	return regex_unicode_property_id_start(point)
}

pub fn regex_has_identifier_continue_property(point u32) bool {
	if point < 128 {
		return (point >= 0x41 && point <= 0x5a) || (point >= 0x61 && point <= 0x7a)
			|| (point >= 0x30 && point <= 0x39) || point == 0x5f
	}
	return regex_unicode_property_id_continue(point)
}
