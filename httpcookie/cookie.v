// Copyright (c) 2021-2026, Tim Flynn <trflynn89@ladybird.org>
// Copyright (c) 2022, Tobias Christiansen <tobyase@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translation of LibHTTP/Cookie/Cookie.{h,cpp} and ParsedCookie.{h,cpp}.
module httpcookie

import strconv
import time
import url

pub enum SameSite as u8 {
	default_
	none
	strict
	lax
}

pub enum Source as u8 {
	non_http
	http
}

pub struct ParsedCookie {
pub mut:
	name                               string
	value                              string
	same_site_attribute                SameSite = .default_
	expiry_time_from_expires_attribute ?i64
	expiry_time_from_max_age_attribute ?i64
	domain                             ?string
	path                               ?string
	secure_attribute_present           bool
	http_only_attribute_present        bool
}

pub struct VersionedCookie {
pub:
	cookie_version ?u64
	cookie         string
}

const maximum_cookie_age_seconds = i64(400 * 24 * 60 * 60)
const short_month_names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
	'Nov', 'Dec']

pub fn same_site_from_string(value string) SameSite {
	return match value.to_lower() {
		'none' { .none }
		'strict' { .strict }
		'lax' { .lax }
		else { .default_ }
	}
}

// https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis-22#section-5.1.2
pub fn canonicalize_domain(record &url.URL) ?string {
	host := record.host or { return none }
	// Upstream has the same FIXME for the label conversions; LibURL has already
	// converted domain hosts to their ASCII form by this point.
	return host.serialize().trim('[]').to_lower()
}

// https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis-22#section-5.1.4-1
pub fn default_path(record &url.URL) string {
	uri_path := url.percent_decode(record.serialize_path()).bytestr()
	if uri_path == '' || uri_path[0] != `/` {
		return '/'
	}
	last_separator := uri_path.last_index('/') or { return '/' }
	if last_separator == 0 {
		return '/'
	}
	return uri_path[..last_separator]
}

pub fn cookie_contains_invalid_control_character(cookie_string string) bool {
	for code_point in cookie_string.runes() {
		if code_point <= 0x08 || (code_point >= 0x0a && code_point <= 0x1f) || code_point == 0x7f {
			return true
		}
	}
	return false
}

fn parse_uint(token string) ?u32 {
	if token == '' || token.bytes().any(it < `0` || it > `9`) {
		return none
	}
	value := strconv.parse_uint(token, 10, 32) or { return none }
	return u32(value)
}

fn cookie_date_tokens(input string) []string {
	mut tokens := []string{}
	mut start := -1
	bytes := input.bytes()
	for index, byte in bytes {
		is_delimiter := byte == 0x09 || (byte >= 0x20 && byte <= 0x2f) || (byte >= 0x3b && byte <= 0x40) || (byte >= 0x5b && byte <= 0x60) || (byte >= 0x7b && byte <= 0x7e)
		if is_delimiter {
			if start >= 0 {
				tokens << input[start..index]
				start = -1
			}
		} else if start < 0 {
			start = index
		}
	}
	if start >= 0 {
		tokens << input[start..]
	}
	return tokens
}

// https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis-22#section-5.1.1
fn parse_date_time(date_string string) ?i64 {
	mut hour := u32(0)
	mut minute := u32(0)
	mut second := u32(0)
	mut day_of_month := u32(0)
	mut month := u32(0)
	mut year := u32(0)
	mut found_time := false
	mut found_day_of_month := false
	mut found_month := false
	mut found_year := false

	for token in cookie_date_tokens(date_string) {
		if !found_time {
			parts := token.split(':')
			if parts.len == 3 && parts.all(it.len > 0 && it.len <= 2) {
				parsed_hour := parse_uint(parts[0])
				parsed_minute := parse_uint(parts[1])
				parsed_second := parse_uint(parts[2])
				if h := parsed_hour {
					if m := parsed_minute {
						if s := parsed_second {
							hour, minute, second = h, m, s
							found_time = true
							continue
						}
					}
				}
			}
		}
		if !found_day_of_month && token.len <= 2 {
			if parsed := parse_uint(token) {
				day_of_month = parsed
				found_day_of_month = true
				continue
			}
		}
		if !found_month {
			for index, month_name in short_month_names {
				if token.to_lower() == month_name.to_lower() {
					month = u32(index + 1)
					found_month = true
					break
				}
			}
			if found_month {
				continue
			}
		}
		if !found_year && token.len in [2, 4] {
			if parsed := parse_uint(token) {
				year = parsed
				found_year = true
			}
		}
	}

	if year >= 70 && year <= 99 {
		year += 1900
	}
	if year <= 69 {
		year += 2000
	}
	if !found_day_of_month || !found_month || !found_year || !found_time || day_of_month < 1 || day_of_month > 31 || year < 1601 || hour > 23 || minute > 59 || second > 59 {
		return none
	}
	days := time.days_in_month(int(month), int(year)) or { return none }
	if day_of_month > u32(days) {
		return none
	}
	return time.new(time.Time{
		year: int(year)
		month: int(month)
		day: int(day_of_month)
		hour: int(hour)
		minute: int(minute)
		second: int(second)
	}).unix()
}

fn parse_signed_i64_saturated(input string) i64 {
	return strconv.parse_int(input, 10, 64) or {
		if input.starts_with('-') { min_i64 } else { max_i64 }
	}
}

fn process_attribute(record &url.URL, mut parsed ParsedCookie, attribute_name string, attribute_value string) ! {
	match attribute_name.to_lower() {
		'expires' {
			if expiry := parse_date_time(attribute_value) {
				limit := time.now().unix() + maximum_cookie_age_seconds
				parsed.expiry_time_from_expires_attribute = if expiry > limit {
					limit
				} else {
					expiry
				}
			}
		}
		'max-age' {
			if attribute_value != '' {
				digits := if attribute_value.starts_with('-') {
					attribute_value[1..]
				} else {
					attribute_value
				}
				if digits != '' && digits.bytes().all(it >= `0` && it <= `9`) {
					mut delta_seconds := parse_signed_i64_saturated(attribute_value)
					if delta_seconds > maximum_cookie_age_seconds {
						delta_seconds = maximum_cookie_age_seconds
					}
					parsed.expiry_time_from_max_age_attribute = if delta_seconds <= 0 {
						min_i64
					} else {
						time.now().unix() + delta_seconds
					}
				}
			}
		}
		'domain' {
			if attribute_value.bytes().any(it > 0x7f) {
				return error('Domain must be a string of ASCII characters')
			}
			domain := if attribute_value.starts_with('.') {
				attribute_value[1..]
			} else {
				attribute_value
			}
			parsed.domain = domain.to_lower()
		}
		'path' {
			parsed.path = if attribute_value == '' || !attribute_value.starts_with('/') {
				default_path(record)
			} else {
				attribute_value
			}
		}
		'secure' {
			parsed.secure_attribute_present = true
		}
		'httponly' {
			parsed.http_only_attribute_present = true
		}
		'samesite' {
			parsed.same_site_attribute = same_site_from_string(attribute_value)
		}
		else {}
	}
}

// https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis-22#section-5.6-6
pub fn parse_cookie(record &url.URL, cookie_string string) ?ParsedCookie {
	if cookie_contains_invalid_control_character(cookie_string) {
		return none
	}
	semicolon := cookie_string.index(';') or { cookie_string.len }
	name_value_pair := cookie_string[..semicolon]
	mut name := ''
	mut value := ''
	if equals := name_value_pair.index('=') {
		name = name_value_pair[..equals]
		if equals < name_value_pair.len - 1 {
			value = name_value_pair[equals + 1..]
		}
	} else {
		value = name_value_pair
	}
	name = name.trim('\t ')
	value = value.trim('\t ')
	if name.len + value.len > 4096 {
		return none
	}
	mut parsed := ParsedCookie{
		name: name
		value: value
	}
	mut unparsed_attributes := if semicolon < cookie_string.len {
		cookie_string[semicolon..]
	} else {
		''
	}
	for unparsed_attributes != '' {
		unparsed_attributes = unparsed_attributes[1..]
		next_semicolon := unparsed_attributes.index(';') or { unparsed_attributes.len }
		cookie_attribute := unparsed_attributes[..next_semicolon]
		unparsed_attributes = if next_semicolon < unparsed_attributes.len {
			unparsed_attributes[next_semicolon..]
		} else {
			''
		}
		equals := cookie_attribute.index('=') or { cookie_attribute.len }
		attribute_name := cookie_attribute[..equals].trim('\t ')
		attribute_value := if equals < cookie_attribute.len {
			cookie_attribute[equals + 1..].trim('\t ')
		} else {
			''
		}
		if attribute_value.len > 1024 {
			continue
		}
		process_attribute(record, mut parsed, attribute_name, attribute_value) or { return none }
	}
	return parsed
}
