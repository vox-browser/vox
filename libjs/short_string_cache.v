module libjs

$if test {
	__global short_string_cache_disabled bool
	__global short_string_cache_diagnostic bool
	__global short_string_cache_hits u64
	pub fn set_short_string_cache_for_testing(enabled bool) { short_string_cache_disabled = !enabled }
	pub fn diagnose_short_string_cache_for_testing(enabled bool) u64 {
		previous := short_string_cache_hits
		short_string_cache_hits = 0
		short_string_cache_diagnostic = enabled
		return previous
	}
}

fn (mut vm VM) create_cached_utf8_string(text string) &PrimitiveString {
	$if test { if short_string_cache_disabled { return vm.create_string(utf16_string(text)) } }
	if text.len == 0 { return vm.empty_string() }
	if text.len == 1 && text[0] < 128 { return vm.single_ascii_character_string(text[0]) }
	if text.len > 64 { return vm.create_string(utf16_string(text)) }
	if cached := vm.short_utf8_strings[text] {
		$if test { if short_string_cache_diagnostic { short_string_cache_hits++ } }
		return cached
	}
	created := vm.create_string(utf16_string(text))
	// A bounded content cache avoids UTF-16 conversion on hits. UTF-8 keys
	// and PrimitiveString values own their storage independently of callers.
	if vm.short_utf8_strings.len >= 128 { vm.short_utf8_strings.clear() }
	vm.short_utf8_strings[text.clone()] = created
	return created
}
