// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math
import time

struct IntlDatePart { type_ string; value string }

fn intl_localize_digits(core &IntlCoreData, system string, text string) string {
	if system == 'latn' { return text }
	digits := (core.numbering_systems[system] or { '0123456789' }).runes()
	mut result := ''
	for unit in text.runes() { result += if unit >= `0` && unit <= `9` { digits[int(unit - `0`)].str() } else { unit.str() } }
	return result
}

fn intl_numeric_date_part(core &IntlCoreData, formatter &IntlDateTimeFormat, value int, width int) string {
	text := if width == 2 { '${value % 100:02}' } else { value.str() }
	return intl_localize_digits(core, formatter.numbering_system, text)
}

fn intl_flexible_day_period(core &IntlCoreData, locale string, clock time.Time) string {
	minutes := clock.hour * 60 + clock.minute
	mut tag := locale
	for {
		if rules := core.day_periods[tag] {
			for rule in rules {
				if rule.at != '' {
					parts := rule.at.split(':')
					if minutes == parts[0].int() * 60 + parts[1].int() && clock.second == 0 && clock.nanosecond == 0 { return rule.name }
				}
			}
			for rule in rules {
				if rule.start == '' || rule.end == '' { continue }
				start := rule.start.split(':'); end := rule.end.split(':')
				a := start[0].int() * 60 + start[1].int(); b := end[0].int() * 60 + end[1].int()
				if (a <= b && minutes >= a && minutes < b) || (a > b && (minutes >= a || minutes < b)) { return rule.name }
			}
			break
		}
		at := tag.last_index('-') or { break }; tag = tag[..at]
	}
	return if clock.hour < 12 { 'am' } else { 'pm' }
}

fn intl_format_date_parts(mut vm VM, formatter &IntlDateTimeFormat, input Value) ![]IntlDatePart {
	value := if input.is_undefined() { f64(time.now().unix_milli()) } else { input.to_number(mut vm)!.number }
	stamp := date_time_clip(value)
	if math.is_nan(stamp) { return vm.throw_error(.range_error, 'Invalid time value for Intl.DateTimeFormat') }
	core := intl_core_data(mut vm)!
	data := intl_date_locale_data(mut vm, formatter.data_locale)!
	rule := intl_time_zone_rule(mut vm, formatter.time_zone, stamp)!
	clock := time.unix_milli(i64(stamp + f64(rule.offset) * 1000))
	mut result := []IntlDatePart{}
	for token in formatter.pattern {
		vm.consume_execution_budget()!
		mut type_ := intl_date_token_name(token)
		mut text := ''
		if token.field == 0 { type_ = 'literal'; text = token.literal }
		else {
			width := if token.count >= 5 { 'narrow' } else if token.count == 4 { 'wide' } else { 'abbreviated' }
			match token.field {
				`G` {
					key := if token.count >= 5 { 'eraNarrow' } else if token.count == 4 { 'eraNames' } else { 'eraAbbr' }
					text = data.eras[key][if clock.year <= 0 { 0 } else { 1 }]
				}
				`y` { text = intl_numeric_date_part(core, formatter, if clock.year <= 0 { 1 - clock.year } else { clock.year }, token.count) }
				`M`, `L` {
					if token.count <= 2 { text = intl_numeric_date_part(core, formatter, clock.month, token.count) }
					else { context := if token.field == `L` { 'stand-alone' } else { 'format' }; text = data.months[context + '_' + width][clock.month - 1] }
				}
				`d` { text = intl_numeric_date_part(core, formatter, clock.day, token.count) }
				`E`, `e`, `c` {
					context := if token.field == `c` { 'stand-alone' } else { 'format' }
					text = data.weekdays[context + '_' + width][clock.day_of_week() % 7]
				}
				`h`, `H`, `K`, `k` {
					hour := if token.field == `h` { if clock.hour % 12 == 0 { 12 } else { clock.hour % 12 } } else if token.field == `K` { clock.hour % 12 } else if token.field == `k` && clock.hour == 0 { 24 } else { clock.hour }
					text = intl_numeric_date_part(core, formatter, hour, token.count)
				}
				`m` { text = intl_numeric_date_part(core, formatter, clock.minute, token.count) }
				`s` { text = intl_numeric_date_part(core, formatter, clock.second, token.count) }
				`S` {
					milliseconds := '${clock.nanosecond / 1000000:03}'
					text = intl_localize_digits(core, formatter.numbering_system, milliseconds[..token.count])
				}
				`a`, `b`, `B` {
					mut kind := if clock.hour < 12 { 'am' } else { 'pm' }
					if token.field == `B` { kind = intl_flexible_day_period(core, formatter.data_locale, clock) }
					else if token.field == `b` && clock.minute == 0 && clock.second == 0 && clock.nanosecond == 0 && clock.hour in [0, 12] { kind = if clock.hour == 0 { 'midnight' } else { 'noon' } }
					text = data.periods['format_' + width + '_' + kind] or { data.periods['format_abbreviated_' + if clock.hour < 12 { 'am' } else { 'pm' }] }
				}
				`z`, `v`, `O`, `V`, `Z`, `X`, `x` { text = intl_localize_digits(core, formatter.numbering_system, intl_zone_name(mut vm, data, formatter.time_zone, rule, stamp, intl_date_token_style(token))!) }
				else { return vm.throw_error(.internal_error, 'Unsupported native Intl date field') }
			}
		}
		// Upstream LibUnicode normalizes these CLDR time separators for browser
		// compatibility in both string and partitioned formatting.
		text = text.replace('\u202f', ' ').replace('\u2009', ' ')
		if type_ == 'literal' && result.len > 0 && result.last().type_ == 'literal' {
			last := result.pop(); result << IntlDatePart{type_: type_, value: last.value + text}
		} else { result << IntlDatePart{type_: type_, value: text} }
	}
	return result
}
