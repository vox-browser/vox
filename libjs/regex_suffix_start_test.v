module libjs

fn test_suffix_prefix_width_overflow_stays_a_safe_upper_bound() {
	assert regex_width_add(u64(0xffffffff), 2) == u64(0x100000001)
	assert regex_width_multiply(u64(0xffffffff), 2) == u64(0x1fffffffe)
	assert regex_width_add(regex_width_limit - 1, 2) == regex_width_limit
	assert regex_width_multiply(regex_width_limit, 2) == regex_width_limit
}

fn test_suffix_start_hints_preserve_matches_captures_and_search_offsets() {
	defer { set_regex_suffix_starts_for_testing(true) }
	for pattern in [
		r'^[\x20\t\r\n\f]+|((?:^|[^\\])(?:\\.)*)[\x20\t\r\n\f]+$',
		r'(a|bc)x+$',
		r'(a?b{0,3})x{1,2}$',
		r'(a|b?c?)x+$',
		r'(?:a|bc){0,2}x+$',
		r'(?:a\\.)*x+$',
		r'(a*)x+$',
		r'(?=(a?))a?x+$',
		r'(?<=(a))x+$',
		r'^a|x+$',
		r'^(?:)|x+$',
		r'^(?:😀)|x+$',
		r'(a)\1x+$',
		r'a?x+$',
	] {
		set_regex_suffix_starts_for_testing(false)
		mut control := RegexEngine.compile(pattern.runes(), RegexAstFlags{})!
		set_regex_suffix_starts_for_testing(true)
		mut candidate := RegexEngine.compile(pattern.runes(), RegexAstFlags{})!
		for text in ['', 'x', 'xxxx', 'axxx', 'abxx', 'bcxxx', 'aaaaax', 'a\\x', 'a\\.x', '.arrow ',
			' ', '\t ', 'a\n', '😀xx', '😀', 'zzzzx'] {
			input := RegexUtf16Input{ units: utf16_string(text).data }
			for start in 0 .. input.units.len + 2 {
				mut expected := []i32{len: int(control.program.capture_count + 1) * 2, init: -1}
				mut actual := expected.clone()
				status := control.exec(input, uint(start), mut expected)
				assert candidate.exec(input, uint(start), mut actual) == status, '${pattern}: ${text}: ${start}'
				assert actual == expected, '${pattern}: ${text}: ${start}'
			}
		}
	}
}

fn test_suffix_start_hints_skip_only_impossible_positions_and_retain_fallbacks() {
	defer { diagnose_regex_suffix_starts_for_testing(false) }
	mut engine := RegexEngine.compile(r'^[\x20\t\r\n\f]+|((?:^|[^\\])(?:\\.)*)[\x20\t\r\n\f]+$'.runes(), RegexAstFlags{})!
	assert engine.suffix_starts != none
	diagnose_regex_suffix_starts_for_testing(true)
	mut captures := []i32{len: 4, init: -1}
	assert engine.exec(RegexUtf16Input{ units: utf16_string('.ajax-yn-button .togglebutton ').data }, 0, mut captures) == .match
	assert captures == [28, 30, 28, 29]
	activity := diagnose_regex_suffix_starts_for_testing(false)
	assert activity.searches > 0 && activity.skipped_positions > 0
	for flags in [RegexAstFlags{ ignore_case: true }, RegexAstFlags{ multiline: true },
		RegexAstFlags{ unicode: true }, RegexAstFlags{ unicode_sets: true },
		RegexAstFlags{ sticky: true }] {
		fallback := RegexEngine.compile(r'a?x+$'.runes(), flags)!
		assert fallback.suffix_starts == none
	}
}
