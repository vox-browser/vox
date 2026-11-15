// SPDX-License-Identifier: BSD-2-Clause
module libjs

import platform

fn test_intl_language_tags_preserve_canonical_aliases_and_sorted_extensions() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	cases := {
		'EN-us': 'en-US'
		'iw-IL': 'he-IL'
		'sh': 'sr-Latn'
		'sh-Cyrl': 'sr-Cyrl'
		'ja-Latn-heploc-hepburn': 'ja-Latn-alalc97'
		'hy-Latn-arevmda': 'hyw-Latn'
		'en-UK': 'en-GB'
		'en-u-nu-latn-ca-islamicc': 'en-u-ca-islamic-civil-nu-latn'
		'de-u-kn-true-co-phonebk': 'de-u-co-phonebk-kn'
		'en-u-ca-gregory-ca-buddhist': 'en-u-ca-gregory'
		'en-u-foo-foo-bar': 'en-u-bar-foo'
		'en-z-abc-a-def-x-PRIVATE': 'en-a-def-z-abc-x-private'
		'en-t-IW-il-m0-ungegn': 'en-t-he-il-m0-ungegn'
	}
	for input, expected in cases { assert intl_canonicalize_language_tag(mut vm, utf16_string(input))!.tag() == expected }
}

fn test_intl_language_tags_reject_bad_unicode_grammar_variants_and_singletons() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	for text in ['', 'en_US', 'abcd', 'x-private', 'en--US', 'en-US-US', 'en-a', 'en-u', 'en-x', 'en-1901-1901', 'en-a-abc-a-def', 'en-t-de-1901-1901', 'en-t-m0', 'en-u-12-abc'] {
		if _ := intl_canonicalize_language_tag(mut vm, utf16_string(text)) { assert false, text }
		else { assert thrown_value(err).as_object().is_error_object() }
	}
	for units in [[u16(`e`), u16(`n`), u16(0xd800)], [u16(0xe9), u16(`n`)]] {
		if _ := intl_canonicalize_language_tag(mut vm, Utf16String.from_slice(units)) { assert false }
	}
}

fn test_intl_cldr_locale_deltas_keep_parent_data_immutable_and_default_content_available() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	core := intl_core_data(mut vm)!
	assert core.release == '48.2.0' && core.locale_spans.len == 1121
	assert 'en-US' in core.locale_spans && 'ru-RU' in core.locale_spans
	en := intl_date_locale_data(mut vm, 'en')!
	gb := intl_date_locale_data(mut vm, 'en-GB')!
	assert en.date_formats['short'] == 'M/d/yy'
	assert gb.date_formats['short'] == 'dd/MM/y'
	assert en.months['format_wide'][0] == 'January' && gb.months['format_wide'][0] == 'January'
	assert en.date_formats['short'] == 'M/d/yy'
	assert intl_date_locale_data(mut vm, 'ru')!.months['format_wide'][0] == 'января'
	assert voidptr(intl_date_locale_data(mut vm, 'en-GB')!) == voidptr(gb)
}

fn test_intl_cldr_cache_survives_temporary_allocation_storage() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut arena := platform.new_arena('load native Intl data')
	entry := arena.enter()
	core := intl_core_data(mut vm)!
	locale := intl_date_locale_data(mut vm, 'en-GB')!
	arena.leave(entry)
	assert !arena.contains(core) && !arena.contains(locale)
	assert !arena.contains(locale.months['format_wide'].data)
	arena.reset(); arena.release()
	assert locale.months['format_wide'][0] == 'January' && core.zone_alias['america/new_york'] == 'America/New_York'
}

fn test_intl_canonical_language_records_retain_text_beyond_temporary_allocation_scope() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut arena := platform.new_arena('canonical Intl locale text')
	entry := arena.enter()
	id := intl_canonicalize_language_tag(mut vm, utf16_string('EN-latn-us-u-ca-gregory'))!
	arena.leave(entry)
	assert !arena.contains(id.language.str) && !arena.contains(id.script.str) && !arena.contains(id.region.str)
	arena.reset(); arena.release()
	assert id.tag() == 'en-Latn-US-u-ca-gregory'
}
