// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn test_native_collation_root_weights_accent_levels_case_and_canonical_equivalence() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	for row in [['a', 'A', '-1'], ['A', 'b', '-1'], ['é', 'f', '-1'], ['e', 'é', '-1'], ['é', 'e\u0301', '0'], ['', '\x00', '0'], ['ß', 'ss', '1']] {
		assert intl_collation_compare(mut vm, utf16_string(row[0]), utf16_string(row[1]), IntlCollationSettings{})! == row[2].int()
	}
	assert intl_collation_compare(mut vm, utf16_string('é'), utf16_string('E'), IntlCollationSettings{sensitivity: 'base'})! == 0
	assert intl_collation_compare(mut vm, utf16_string('ß'), utf16_string('ss'), IntlCollationSettings{sensitivity: 'base'})! == 0
	assert intl_collation_compare(mut vm, utf16_string('a'), utf16_string('A'), IntlCollationSettings{sensitivity: 'accent'})! == 0
}

fn test_native_collation_case_first_and_case_only_ignore_noncase_variants() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_collation_compare(mut vm, utf16_string('A'), utf16_string('a'), IntlCollationSettings{case_first: 'upper'})! == -1
	assert intl_collation_compare(mut vm, utf16_string('a'), utf16_string('A'), IntlCollationSettings{case_first: 'lower'})! == -1
	assert intl_collation_compare(mut vm, utf16_string('ä'), utf16_string('a'), IntlCollationSettings{sensitivity: 'case'})! == 0
	assert intl_collation_compare(mut vm, utf16_string('ａ'), utf16_string('a'), IntlCollationSettings{sensitivity: 'case'})! == 0
	assert intl_collation_compare(mut vm, utf16_string('a'), utf16_string('A'), IntlCollationSettings{sensitivity: 'case'})! == -1
}

fn test_native_collation_longest_contractions_and_discontiguous_nonstarter_matching() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	data := intl_collation_data(mut vm)!
	mut points := [u32(0x438), 0x327, 0x306]
	node, end := intl_collation_match(mut vm, data, mut points, 0)!
	i := data.child(0, 0x438)?
	assert node == data.child(i, 0x306)? && end == 1
	assert points == [u32(0x438), 0x327]
	mut blocked := [u32(0x438), 0x301, 0x306]
	blocked_node, blocked_end := intl_collation_match(mut vm, data, mut blocked, 0)!
	assert blocked_node == i && blocked_end == 1 && blocked.len == 3
	assert intl_collation_compare(mut vm, utf16_string('й\u0327'), utf16_string('и\u0327\u0306'), IntlCollationSettings{})! == 0
	// Hangul canonical decomposition uses root jamo mappings.
	assert intl_collation_compare(mut vm, utf16_string('각'), utf16_string('\u1100\u1161\u11a8'), IntlCollationSettings{})! == 0
}

fn test_native_collation_numeric_runs_are_unbounded_exact_and_script_independent() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	settings := IntlCollationSettings{numeric: true}
	assert intl_collation_compare(mut vm, utf16_string('file2'), utf16_string('file10'), settings)! == -1
	assert intl_collation_compare(mut vm, utf16_string('file2'), utf16_string('file10'), IntlCollationSettings{})! == 1
	assert intl_collation_compare(mut vm, utf16_string('file002'), utf16_string('file٢'), settings)! == 0
	assert intl_collation_compare(mut vm, utf16_string('9'.repeat(300)), utf16_string('1' + '0'.repeat(300)), settings)! == -1
	assert intl_collation_compare(mut vm, utf16_string('9007199254740992'), utf16_string('9007199254740993'), settings)! == -1
	assert intl_collation_compare(mut vm, utf16_string('file0a'), utf16_string('file000a'), settings)! == 0
}

fn test_native_collation_shifted_punctuation_ignores_following_primary_ignorables_only() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	settings := IntlCollationSettings{ignore_punctuation: true}
	assert intl_collation_compare(mut vm, utf16_string('a-b'), utf16_string('ab'), settings)! == 0
	assert intl_collation_compare(mut vm, utf16_string('-\u0301ab'), utf16_string('ab'), settings)! == 0
	assert intl_collation_compare(mut vm, utf16_string('a$b'), utf16_string('ab'), settings)! != 0
	assert intl_collation_compare(mut vm, utf16_string('a-b'), utf16_string('ab'), IntlCollationSettings{})! != 0
}

fn test_native_collation_implicit_weights_preserve_han_and_lone_surrogate_identity() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert intl_collation_implicit(0x4e00)[0].primary == 0xfb40
	assert intl_collation_implicit(0x20000)[0].primary == 0xfb84
	assert intl_collation_implicit(0xe000)[0].primary == 0xfbc1
	assert intl_collation_implicit(0x17000)[0].primary == 0xfb00
	assert intl_collation_compare(mut vm, Utf16String.from_slice([u16(0xd800)]), Utf16String.from_slice([u16(0xd801)]), IntlCollationSettings{})! == -1
	assert intl_collation_compare(mut vm, utf16_string('一'), utf16_string('丁'), IntlCollationSettings{})! == -1
}
