// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os

fn test_intl_date_patterns_preserve_quoted_literals_and_localized_field_widths() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	tokens := intl_parse_date_pattern(mut vm, "d 'de' MMMM 'de' y 'o''clock'")!
	fields, supported := intl_date_pattern_fields(tokens)
	assert supported && fields['day'] == 'numeric' && fields['month'] == 'long' && fields['year'] == 'numeric'
	assert tokens.last().literal == " o'clock"
	data := intl_date_locale_data(mut vm, 'en-GB')!
	pattern := intl_best_date_pattern(mut vm, data, {'day': 'numeric', 'month': 'numeric', 'year': 'numeric'}, 'h23')!
	actual, valid := intl_date_pattern_fields(pattern)
	assert valid && actual['day'] == '2-digit' && actual['month'] == '2-digit'
}

fn test_intl_time_zone_offsets_aliases_and_tzif_rules_have_separate_native_records() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	for input, expected in {'+03': '+03:00', '+0330': '+03:30', '-0330': '-03:30', '-00:00': '+00:00', 'us/eastern': 'America/New_York', 'gmt': 'UTC'} {
		zone := intl_parse_time_zone(mut vm, Value.from_string(vm.create_string_from_str(input)))!
		assert zone.identifier == expected
	}
	zone := intl_parse_time_zone(mut vm, Value.from_string(vm.create_string_from_str('America/New_York')))!
	assert intl_time_zone_rule(mut vm, zone, 0)!.offset == -18000
	assert intl_time_zone_rule(mut vm, zone, date_make_date(2024, 6, 1, 0, 0, 0, 0))!.is_dst
}

fn test_intl_gmt_offset_patterns_keep_local_separators_and_single_hour_fields() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	fi := intl_date_locale_data(mut vm, 'fi')!
	am := intl_date_locale_data(mut vm, 'am')!
	assert intl_zone_offset_name(fi, 10800, false) == fi.gmt_format.replace('{0}', '+3')
	assert intl_zone_offset_name(fi, 12600, true) == fi.gmt_format.replace('{0}', '+3.30')
	assert intl_zone_offset_name(am, 10800, false) == am.gmt_format.replace('{0}', '+3')
	assert intl_zone_offset_name(am, 12600, true) == am.gmt_format.replace('{0}', '+0330')
	assert intl_zone_offset_name(fi, 12615, true) == fi.gmt_format.replace('{0}', '+3.30.15')
}

fn test_intl_system_zone_without_an_iana_name_has_consistent_fixed_offset_semantics() {
	previous := os.getenv_opt('TZ')
	defer { if value := previous { os.setenv('TZ', value, true) } else { os.unsetenv('TZ') } }
	os.setenv('TZ', 'STD3DST,M3.2.0,M11.1.0', true)
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	zone := intl_parse_time_zone(mut vm, js_undefined())!
	assert zone.location == none && zone.identifier == intl_offset_identifier(zone.offset_seconds)
	assert intl_time_zone_rule(mut vm, zone, 0)!.offset == zone.offset_seconds
	assert intl_time_zone_rule(mut vm, zone, date_make_date(2024, 6, 1, 0, 0, 0, 0))!.offset == zone.offset_seconds
}
