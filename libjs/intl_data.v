// SPDX-License-Identifier: BSD-2-Clause
module libjs

import json2
import platform

struct IntlDataSpan { offset int; length int }
struct IntlMetaZonePeriod { name string; start string; end string }
struct IntlLanguageAliasRule { language string; script string; region string; variants []string; replacement string }
struct IntlDayPeriodRule { name string; at string; start string; end string }

@[heap]
pub struct IntlCoreData {
	schema int
	release string
	revision string
	locale_spans map[string]IntlDataSpan
	language_rules []IntlLanguageAliasRule
	language_alias map[string]string
	script_alias map[string]string
	region_alias map[string][]string
	variant_alias map[string]string
	likely_subtags map[string]string
	hour_cycles map[string]string
	numbering_systems map[string]string
	type_alias map[string]string
	zone_alias map[string]string
	meta_zones map[string][]IntlMetaZonePeriod
	day_periods map[string][]IntlDayPeriodRule
	cardinal_rules map[string]map[string]string
	ordinal_rules map[string]map[string]string
	currency_digits map[string]int
}

@[heap]
pub struct IntlDateLocaleData {
	parent string
	removed map[string][]string
	months map[string][]string
	weekdays map[string][]string
	eras map[string][]string
	periods map[string]string
	date_formats map[string]string
	time_formats map[string]string
	combinations map[string]string
	at_time map[string]string
	available map[string]string
	zone_names map[string]map[string]string
	meta_zone_names map[string]map[string]string
	list_patterns map[string]map[string]string
	gmt_format string
	gmt_zero string
	hour_format string
	region_format string
	numbering_system string
	decimal map[string]string
	number_symbols map[string]map[string]string
	number_patterns map[string]string
	number_compact map[string]map[string]string
	number_currencies map[string]map[string]string
	number_units map[string]map[string]string
	number_per map[string]string
	relative_time map[string]map[string]string
	minimum_grouping string
}

fn intl_core_data(mut vm VM) !&IntlCoreData {
	mut realm := unsafe { &Realm(vm.realm()) }
	if data := realm.intl_core_data { return data }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	data := json2.decode[IntlCoreData]($embed_file('@VMODROOT/libjs/intl_data/core.dat').to_string()) or { return vm.throw_error(.internal_error, 'Invalid embedded Intl core data: ' + err.msg()) }
	if data.schema != 1 || data.revision != 'bb334e8d6250c9363e957e131bf7e6d08ec72f91' { return vm.throw_error(.internal_error, 'Unsupported embedded Intl data revision') }
	result := &IntlCoreData{...data}
	realm.intl_core_data = result
	return result
}

fn intl_overlay[T](base map[string]T, own map[string]T, removed []string) map[string]T {
	mut result := base.clone()
	for key in removed { result.delete(key) }
	for key, value in own { result[key] = value }
	return result
}

fn intl_date_locale_data(mut vm VM, locale string) !&IntlDateLocaleData {
	mut realm := unsafe { &Realm(vm.realm()) }
	if data := realm.intl_date_locales[locale] { return data }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	core := intl_core_data(mut vm)!
	span := core.locale_spans[locale] or { return vm.throw_error(.internal_error, 'Missing Intl locale data: ' + locale) }
	blob := $embed_file('@VMODROOT/libjs/intl_data/locales.dat').to_string()
	if span.offset < 0 || span.length < 0 || span.offset > blob.len || span.length > blob.len - span.offset { return vm.throw_error(.internal_error, 'Invalid Intl data span') }
	own := json2.decode[IntlDateLocaleData](blob[span.offset..span.offset + span.length]) or { return vm.throw_error(.internal_error, 'Invalid embedded Intl locale data: ' + err.msg()) }
	if own.parent == '' {
		data := &IntlDateLocaleData{...own}
		realm.intl_date_locales[locale] = data
		return data
	}
	base := intl_date_locale_data(mut vm, own.parent)!
	data := &IntlDateLocaleData{
		months: intl_overlay(base.months, own.months, own.removed['months'])
		weekdays: intl_overlay(base.weekdays, own.weekdays, own.removed['weekdays'])
		eras: intl_overlay(base.eras, own.eras, own.removed['eras'])
		periods: intl_overlay(base.periods, own.periods, own.removed['periods'])
		date_formats: intl_overlay(base.date_formats, own.date_formats, own.removed['date_formats'])
		time_formats: intl_overlay(base.time_formats, own.time_formats, own.removed['time_formats'])
		combinations: intl_overlay(base.combinations, own.combinations, own.removed['combinations'])
		at_time: intl_overlay(base.at_time, own.at_time, own.removed['at_time'])
		available: intl_overlay(base.available, own.available, own.removed['available'])
		zone_names: intl_overlay(base.zone_names, own.zone_names, own.removed['zone_names'])
		meta_zone_names: intl_overlay(base.meta_zone_names, own.meta_zone_names, own.removed['meta_zone_names'])
		list_patterns: intl_overlay(base.list_patterns, own.list_patterns, own.removed['list_patterns'])
		decimal: intl_overlay(base.decimal, own.decimal, own.removed['decimal'])
		number_symbols: intl_overlay(base.number_symbols, own.number_symbols, own.removed['number_symbols'])
		number_patterns: intl_overlay(base.number_patterns, own.number_patterns, own.removed['number_patterns'])
		number_compact: intl_overlay(base.number_compact, own.number_compact, own.removed['number_compact'])
		number_currencies: intl_overlay(base.number_currencies, own.number_currencies, own.removed['number_currencies'])
		number_units: intl_overlay(base.number_units, own.number_units, own.removed['number_units'])
		number_per: intl_overlay(base.number_per, own.number_per, own.removed['number_per'])
		relative_time: intl_overlay(base.relative_time, own.relative_time, own.removed['relative_time'])
		minimum_grouping: if own.minimum_grouping != '' { own.minimum_grouping } else { base.minimum_grouping }
		gmt_format: if own.gmt_format != '' { own.gmt_format } else { base.gmt_format }
		gmt_zero: if own.gmt_zero != '' { own.gmt_zero } else { base.gmt_zero }
		hour_format: if own.hour_format != '' { own.hour_format } else { base.hour_format }
		region_format: if own.region_format != '' { own.region_format } else { base.region_format }
		numbering_system: if own.numbering_system != '' { own.numbering_system } else { base.numbering_system }
	}
	realm.intl_date_locales[locale] = data
	return data
}
