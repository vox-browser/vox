// SPDX-License-Identifier: BSD-2-Clause
module libjs

import math

// DateParser's standardized Date Time String Format, without locale heuristics.
struct DateTextParser {
	text []u16
mut:
	position int
}

fn (mut parser DateTextParser) number(count int) ?int {
	if parser.position + count > parser.text.len { return none }
	mut result := 0
	for _ in 0 .. count {
		c := parser.text[parser.position]
		if c < `0` || c > `9` { return none }
		result = result * 10 + int(c - `0`)
		parser.position++
	}
	return result
}

fn (mut parser DateTextParser) take(c u16) bool {
	if parser.position < parser.text.len && parser.text[parser.position] == c {
		parser.position++
		return true
	}
	return false
}

fn parse_date_string(text Utf16String) f64 {
	iso := parse_iso_date_string(text)
	if !math.is_nan(iso) { return iso }
	return parse_native_date_string(text)
}

fn parse_iso_date_string(text Utf16String) f64 {
	mut parser := DateTextParser{ text: text.as_slice() }
	mut year := 0
	if parser.take(`+`) {
		year = parser.number(6) or { return math.nan() }
	} else if parser.take(`-`) {
		year = -(parser.number(6) or { return math.nan() })
		if year == 0 { return math.nan() }
	} else {
		year = parser.number(4) or { return math.nan() }
	}
	mut month := 1
	mut day := 1
	if parser.take(`-`) {
		month = parser.number(2) or { return math.nan() }
		if parser.take(`-`) { day = parser.number(2) or { return math.nan() } }
	}
	if month < 1 || month > 12 || day < 1 || day > 31 { return math.nan() }
	mut hour := 0
	mut minute := 0
	mut second := 0
	mut millisecond := 0
	mut local := false
	mut offset := 0
	if parser.take(`T`) {
		hour = parser.number(2) or { return math.nan() }
		if !parser.take(`:`) { return math.nan() }
		minute = parser.number(2) or { return math.nan() }
		if parser.take(`:`) {
			second = parser.number(2) or { return math.nan() }
			if parser.take(`.`) { millisecond = parser.number(3) or { return math.nan() } }
		}
		if hour > 24 || minute > 59 || second > 59 || (hour == 24 && (minute != 0 || second != 0 || millisecond != 0)) {
			return math.nan()
		}
		if !parser.take(`Z`) {
			mut sign := 0
			if parser.take(`+`) {
				sign = 1
			} else if parser.take(`-`) {
				sign = -1
			}
			if sign == 0 {
				local = true
			} else {
				oh := parser.number(2) or { return math.nan() }
				if !parser.take(`:`) { return math.nan() }
				om := parser.number(2) or { return math.nan() }
				if oh > 23 || om > 59 { return math.nan() }
				offset = sign * (oh * 60 + om) * 60000
			}
		}
	}
	if parser.position != parser.text.len { return math.nan() }
	value := date_make_date(year, month - 1, day, hour, minute, second, millisecond) - offset
	return date_time_clip(if local { date_utc_time(value) } else { value })
}

// The engine's toString/toUTCString formats. Numeric GMT offsets have minute
// precision, so historical sub-minute offsets cannot round-trip their omitted
// seconds. Other implementation-defined legacy formats are absent.
fn parse_native_date_string(text Utf16String) f64 {
	if text.len() > 64 { return math.nan() }
	words := text.str().split(' ')
	if words.len != 6 { return math.nan() }
	utc := words[0].ends_with(',')
	weekday := if utc { words[0].trim_right(',') } else { words[0] }
	if weekday !in ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] { return math.nan() }
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
	month := months.index(words[if utc { 2 } else { 1 }])
	if month < 0 { return math.nan() }
	day := parse_date_decimal(words[if utc { 1 } else { 2 }]) or { return math.nan() }
	year := parse_date_decimal(words[3]) or { return math.nan() }
	if day < 1 || day > 31 { return math.nan() }
	mut clock := DateTextParser{ text: utf16_string(words[4]).as_slice() }
	hour := clock.number(2) or { return math.nan() }
	if !clock.take(`:`) { return math.nan() }
	minute := clock.number(2) or { return math.nan() }
	if !clock.take(`:`) { return math.nan() }
	second := clock.number(2) or { return math.nan() }
	if clock.position != clock.text.len || hour > 23 || minute > 59 || second > 59 {
		return math.nan()
	}
	mut offset := 0
	zone := words[5]
	if utc {
		if zone != 'GMT' { return math.nan() }
	} else {
		if zone.len != 8 || !zone.starts_with('GMT') || zone[3] !in [`+`, `-`] { return math.nan() }
		oh := parse_date_decimal(zone[4..6]) or { return math.nan() }
		om := parse_date_decimal(zone[6..8]) or { return math.nan() }
		if oh > 23 || om > 59 { return math.nan() }
		offset = (if zone[3] == `-` { -1 } else { 1 }) * (oh * 60 + om) * 60000
	}
	return date_time_clip(date_make_date(year, month, day, hour, minute, second, 0) - offset)
}

fn parse_date_decimal(text string) ?int {
	negative := text.starts_with('-')
	digits := if negative { text[1..] } else { text }
	if digits.len == 0 || digits.len > 7 { return none }
	mut result := 0
	for c in digits {
		if c < `0` || c > `9` { return none }
		result = result * 10 + int(c - `0`)
	}
	return if negative { -result } else { result }
}
