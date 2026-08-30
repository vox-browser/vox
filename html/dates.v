// Copyright (c) 2018-2023, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2022, Adam Hodgen <ant1441@gmail.com>
// Copyright (c) 2022, Andrew Kaster <akaster@serenityos.org>
// Copyright (c) 2023-2025, Shannon Booth <shannon@serenityos.org>
// Copyright (c) 2023, stelar7 <dudedbz@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/Dates.cpp.
module html

import strconv

pub struct YearAndMonth {
pub:
	year  u32
	month u32
}

pub struct WeekYearAndWeek {
pub:
	week_year u32
	week      u32
}

pub struct YearMonthDay {
pub:
	year  u32
	month u32
	day   u32
}

pub struct HourMinuteSecond {
pub:
	hour   i32
	minute i32
	second f32
}

pub struct DateAndTime {
pub:
	date YearMonthDay
	time HourMinuteSecond
}

struct DateLexer {
	input string
mut:
	position int
}

fn (lexer DateLexer) is_eof() bool {
	return lexer.position >= lexer.input.len
}

fn (lexer DateLexer) remaining() int {
	return lexer.input.len - lexer.position
}

fn (mut lexer DateLexer) consume_specific(character u8) bool {
	if lexer.is_eof() || lexer.input[lexer.position] != character {
		return false
	}
	lexer.position++
	return true
}

fn (mut lexer DateLexer) consume_digits() string {
	start := lexer.position
	for !lexer.is_eof() && is_number_ascii_digit(lexer.input[lexer.position]) {
		lexer.position++
	}
	return lexer.input[start..lexer.position]
}

fn days_in_month(year u64, month u32) u32 {
	return match month {
		2 {
			if year % 400 == 0 || (year % 4 == 0 && year % 100 != 0) {
				u32(29)
			} else {
				u32(28)
			}
		}
		4, 6, 9, 11 {
			u32(30)
		}
		else {
			u32(31)
		}
	}
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#week-number-of-the-last-day
pub fn week_number_of_the_last_day(year u64) u32 {
	day_of_week := (1 + 5 * ((year - 1) % 4) + 4 * ((year - 1) % 100) + 6 * ((year - 1) % 400)) % 7
	if day_of_week == 4 || (day_of_week == 3 && (year % 400 == 0 || (year % 4 == 0 && year % 100 != 0))) {
		return 53
	}
	return 52
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#valid-week-string
pub fn is_valid_week_string(value string) bool {
	parts := value.split('-')
	if parts.len != 2 || parts[0].len < 4 || parts[1].len != 3 {
		return false
	}
	year := strconv.parse_uint(parts[0], 10, 64) or { return false }
	if year == 0 || parts[1][0] != `W` || !is_number_ascii_digit(parts[1][1]) || !is_number_ascii_digit(parts[1][2]) {
		return false
	}
	week := u32(parts[1][1] - `0`) * 10 + u32(parts[1][2] - `0`)
	return week >= 1 && week <= week_number_of_the_last_day(year)
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#valid-month-string
pub fn is_valid_month_string(value string) bool {
	parts := value.split('-')
	if parts.len != 2 || parts[0].len < 4 || parts[1].len != 2 {
		return false
	}
	year := strconv.parse_uint(parts[0], 10, 64) or { return false }
	if year == 0 || !is_number_ascii_digit(parts[1][0]) || !is_number_ascii_digit(parts[1][1]) {
		return false
	}
	month := u32(parts[1][0] - `0`) * 10 + u32(parts[1][1] - `0`)
	return month >= 1 && month <= 12
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#valid-date-string
pub fn is_valid_date_string(value string) bool {
	parts := value.split('-')
	if parts.len != 3 {
		return false
	}
	if !is_valid_month_string('${parts[0]}-${parts[1]}') || parts[2].len != 2 || !is_number_ascii_digit(parts[2][0]) || !is_number_ascii_digit(parts[2][1]) {
		return false
	}
	year := strconv.parse_uint(parts[0], 10, 64) or { return false }
	month := u32(parts[1][0] - `0`) * 10 + u32(parts[1][1] - `0`)
	day := u32(parts[2][0] - `0`) * 10 + u32(parts[2][1] - `0`)
	return day >= 1 && day <= days_in_month(year, month)
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#valid-local-date-and-time-string
pub fn is_valid_local_date_and_time_string(value string) bool {
	parts_by_t := value.split('T')
	if parts_by_t.len == 2 {
		return is_valid_date_string(parts_by_t[0]) && is_valid_time_string(parts_by_t[1])
	}
	parts_by_space := value.split(' ')
	if parts_by_space.len == 2 {
		return is_valid_date_string(parts_by_space[0]) && is_valid_time_string(parts_by_space[1])
	}
	return false
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#valid-normalised-local-date-and-time-string
pub fn normalize_local_date_and_time_string(value string) string {
	mut normalized_t := value
	if value.count(' ') > 0 {
		assert value.count(' ') == 1
		normalized_t = value.replace_once(' ', 'T')
	}
	parts := normalized_t.split('T')
	assert parts.len == 2
	mut normalized_length := parts[1].len
	for normalized_length > 9 {
		if parts[1][normalized_length - 1] != `0` {
			return '${parts[0]}T${parts[1][..normalized_length]}'
		}
		normalized_length--
	}
	if normalized_length > 5 {
		time_without_milliseconds := parts[1][..8]
		length := if time_without_milliseconds.ends_with(':00') { 5 } else { 8 }
		return '${parts[0]}T${parts[1][..length]}'
	}
	return normalized_t
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#valid-time-string
pub fn is_valid_time_string(value string) bool {
	parts := value.split(':')
	if (parts.len != 2 && parts.len != 3) || parts[0].len != 2 || parts[1].len != 2 {
		return false
	}
	if !is_number_ascii_digit(parts[0][0]) || !is_number_ascii_digit(parts[0][1]) {
		return false
	}
	hour := int(parts[0][0] - `0`) * 10 + int(parts[0][1] - `0`)
	if hour > 23 {
		return false
	}
	if !is_number_ascii_digit(parts[1][0]) || !is_number_ascii_digit(parts[1][1]) {
		return false
	}
	minute := int(parts[1][0] - `0`) * 10 + int(parts[1][1] - `0`)
	if minute > 59 {
		return false
	}
	if parts.len == 3 {
		if parts[2].len < 2 || !is_number_ascii_digit(parts[2][0]) || !is_number_ascii_digit(parts[2][1]) {
			return false
		}
		second := int(parts[2][0] - `0`) * 10 + int(parts[2][1] - `0`)
		if second > 59 {
			return false
		}
		if parts[2].len > 2 {
			fractional := parts[2].split('.')
			if fractional.len != 2 || fractional[1].len < 1 || fractional[1].len > 3 {
				return false
			}
			for digit in fractional[1].bytes() {
				if !is_number_ascii_digit(digit) {
					return false
				}
			}
		}
	}
	return true
}

fn parse_a_month_component(mut input DateLexer) ?YearAndMonth {
	year_string := input.consume_digits()
	if year_string.len < 4 {
		return none
	}
	year_value := strconv.parse_uint(year_string, 10, 32) or { return none }
	year := u32(year_value)
	if year < 1 || !input.consume_specific(`-`) {
		return none
	}
	month_string := input.consume_digits()
	if month_string.len != 2 {
		return none
	}
	month := u32(strconv.parse_uint(month_string, 10, 32) or { return none })
	if month < 1 || month > 12 {
		return none
	}
	return YearAndMonth{year, month}
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#parse-a-month-string
pub fn parse_a_month_string(input_view string) ?YearAndMonth {
	mut input := DateLexer{
		input: input_view
	}
	year_and_month := parse_a_month_component(mut input) or { return none }
	if !input.is_eof() {
		return none
	}
	return year_and_month
}

pub fn number_of_months_since_unix_epoch(year_and_month YearAndMonth) i32 {
	return i32((year_and_month.year - 1970) * 12 + year_and_month.month - 1)
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#parse-a-week-string
pub fn parse_a_week_string(input_view string) ?WeekYearAndWeek {
	mut input := DateLexer{
		input: input_view
	}
	year_string := input.consume_digits()
	if year_string.len < 4 {
		return none
	}
	year := u32(strconv.parse_uint(year_string, 10, 32) or { return none })
	if year < 1 || !input.consume_specific(`-`) || !input.consume_specific(`W`) {
		return none
	}
	week_string := input.consume_digits()
	if week_string.len != 2 {
		return none
	}
	week := u32(strconv.parse_uint(week_string, 10, 32) or { return none })
	max_week := week_number_of_the_last_day(year)
	if week < 1 || week > max_week || !input.is_eof() {
		return none
	}
	return WeekYearAndWeek{year, week}
}

fn parse_a_date_component(mut input DateLexer) ?YearMonthDay {
	month_component := parse_a_month_component(mut input) or { return none }
	max_day := days_in_month(month_component.year, month_component.month)
	if !input.consume_specific(`-`) {
		return none
	}
	day_string := input.consume_digits()
	if day_string.len != 2 {
		return none
	}
	day := u32(strconv.parse_uint(day_string, 10, 32) or { return none })
	if day < 1 || day > max_day {
		return none
	}
	return YearMonthDay{month_component.year, month_component.month, day}
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#parse-a-date-string
pub fn parse_a_date_string(input_view string) ?YearMonthDay {
	mut input := DateLexer{
		input: input_view
	}
	year_month_day := parse_a_date_component(mut input) or { return none }
	if !input.is_eof() {
		return none
	}
	return year_month_day
}

fn parse_a_time_component(mut input DateLexer) ?HourMinuteSecond {
	hour_string := input.consume_digits()
	if hour_string.len != 2 {
		return none
	}
	hour := i32(strconv.parse_int(hour_string, 10, 32) or { return none })
	if hour < 0 || hour > 23 || !input.consume_specific(`:`) {
		return none
	}
	minute_string := input.consume_digits()
	if minute_string.len != 2 {
		return none
	}
	minute := i32(strconv.parse_int(minute_string, 10, 32) or { return none })
	if minute < 0 || minute > 59 {
		return none
	}
	mut second := f32(0)
	if input.consume_specific(`:`) {
		if input.is_eof() || input.remaining() == 1 || (!is_number_ascii_digit(input.input[input.position]) && !is_number_ascii_digit(input.input[input.position + 1])) {
			return none
		}
		start := input.position
		for !input.is_eof() && (is_number_ascii_digit(input.input[input.position]) || input.input[input.position] == `.`) {
			input.position++
		}
		second_string := input.input[start..input.position]
		if second_string.len == 3 || (second_string.len > 3 && second_string[2] != `.`) || second_string.count('.') > 1 {
			return none
		}
		second = f32(strconv.atof64(second_string) or { return none })
		if second < 0 || second >= 60 {
			return none
		}
	}
	return HourMinuteSecond{hour, minute, second}
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#parse-a-time-string
pub fn parse_time_string(value string) !HourMinuteSecond {
	mut input := DateLexer{
		input: value
	}
	time := parse_a_time_component(mut input) or { return error("Can't parse time string") }
	if !input.is_eof() {
		return error("Can't parse time string")
	}
	return time
}

// https://html.spec.whatwg.org/multipage/common-microsyntaxes.html#parse-a-local-date-and-time-string
pub fn parse_a_local_date_and_time_string(input_view string) ?DateAndTime {
	mut input := DateLexer{
		input: input_view
	}
	date := parse_a_date_component(mut input) or { return none }
	if !input.consume_specific(`T`) && !input.consume_specific(` `) {
		return none
	}
	time := parse_a_time_component(mut input) or { return none }
	if !input.is_eof() {
		return none
	}
	return DateAndTime{date, time}
}
