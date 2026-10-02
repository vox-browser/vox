module libjs

// LibRegex/Rust/src/vm.rs's four Unicode property forwarding helpers.
pub fn regex_match_unicode_property_case_insensitive(point u32, name string, value ?string) bool {
	return regex_property_matches_case_insensitive(point, name, value)
}

pub fn regex_match_unicode_property_all_case_equivalents(point u32, name string, value ?string) bool {
	return regex_property_all_case_equivalents_match(point, name, value)
}

fn regex_match_unicode_property(point u32, name string, value ?string) bool {
	return regex_property_matches(point, name, value)
}

pub fn regex_match_unicode_property_resolved(point u32, name string, value ?string, resolved ?RegexResolvedProperty) bool {
	if property := resolved { return regex_resolved_property_matches(point, property) }
	return regex_match_unicode_property(point, name, value)
}
