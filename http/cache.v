// Copyright (c) 2025-2026, Tim Flynn <trflynn89@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the in-memory HTTP-cache utility algorithms from
// Libraries/LibHTTP/Cache/Utilities.cpp. Durations are represented in
// milliseconds, matching the Unix millisecond timestamps used by the V port.
module http

import cachepolicy
import time

pub enum CacheLifetimeStatus {
	fresh
	expired
	must_revalidate
	stale_while_revalidate
}

fn cache_ascii_lowercase(value string) string {
	mut bytes := value.bytes()
	for index, byte in bytes {
		if byte >= `A` && byte <= `Z` {
			bytes[index] = byte + 0x20
		}
	}
	return bytes.bytestr()
}

// This follows LibHTTP's quoted-string-aware cache-control scanner by using
// the translated get/decode/split algorithm, which does not split on commas
// inside quoted strings.
pub fn extract_cache_control_directive(cache_control string, directive string) ?string {
	return extract_cache_control_directive_impl(cache_control, directive, true)
}

fn extract_cache_control_directive_impl(cache_control string, directive string, allow_argument bool) ?string {
	assert directive.len > 0
	for raw_part in get_decode_and_split_header_value(cache_control) {
		part := raw_part.trim('\t ')
		if equals := part.index('=') {
			if !allow_argument { continue }
			name := part[..equals].trim('\t ')
			if cache_ascii_lowercase(name) == cache_ascii_lowercase(directive) {
				return part[equals + 1..].trim('\t ')
			}
		} else if cache_ascii_lowercase(part) == cache_ascii_lowercase(directive) {
			return ''
		}
	}
	return none
}

pub fn contains_cache_control_directive(cache_control string, directive string) bool {
	return extract_cache_control_directive(cache_control, directive) != none
}

// RFC 9111 delta-seconds is one or more ASCII digits. Saturate overflows at
// 2^31 seconds, as permitted by the specification, before converting to ms.
fn parse_cache_delta_seconds(value string) ?i64 {
	if value.len == 0 { return none }
	maximum_seconds := u64(2_147_483_648)
	mut seconds := u64(0)
	for byte in value.bytes() {
		if byte < `0` || byte > `9` { return none }
		if seconds < maximum_seconds {
			next := seconds * 10 + u64(byte - `0`)
			seconds = if next > maximum_seconds { maximum_seconds } else { next }
		}
	}
	return i64(seconds) * 1000
}

pub fn extract_cache_control_duration_directive(cache_control string, directive string, valueless_fallback ?i64) ?i64 {
	value := extract_cache_control_directive(cache_control, directive) or { return none }
	if value.len == 0 {
		return valueless_fallback
	}
	return parse_cache_delta_seconds(value)
}

pub fn is_cacheable_request(method string, request_headers &HeaderList) bool {
	if method !in ['GET', 'HEAD'] {
		return false
	}
	if cache_control := request_headers.get('Cache-Control') {
		if cache_ascii_lowercase(cache_control).contains('no-store') {
			return false
		}
	}
	return !request_headers.contains('Range')
}

fn is_heuristically_cacheable_status(status_code u32) bool {
	return status_code in [u32(200), 203, 204, 206, 300, 301, 308, 404, 405, 410, 414, 501]
}

pub fn vary_header_names(headers &HeaderList) []string {
	value := headers.get('Vary') or { return []string{} }
	mut names := []string{}
	for field in value.split(',') {
		name := cache_ascii_lowercase(field.trim('\t '))
		if name != '' && name !in names {
			names << name
			// Every caller rejects this over-limit result. Stop before further
			// untrusted names turn deduplication into unbounded quadratic work.
			if names.len > 32 { return names }
		}
	}
	names.sort()
	return names
}

pub fn is_cacheable_response(status_code u32, received_headers &HeaderList) bool {
	headers := remove_connection_specific_fields(received_headers)
	if status_code < 200 || status_code in [u32(206), 304] {
		return false
	}
	names := vary_header_names(headers)
	if names.len > 32 || names.any(it in ['*', 'cookie']) {
		return false
	}
	cache_control := headers.get('Cache-Control')
	if value := cache_control {
		if cachepolicy.has_unterminated_quoted_string(value) { return false }
		if extract_cache_control_directive_impl(value, 'must-understand', false) != none {
			if !is_heuristically_cacheable_status(status_code) && status_code != 304 {
				return false
			}
		} else if contains_cache_control_directive(value, 'no-store') {
			return false
		}
	}
	has_expires := headers.contains('Expires')
	mut has_public := false
	mut has_private := false
	mut has_max_age := false
	if value := cache_control {
		has_public = contains_cache_control_directive(value, 'public')
		has_private = contains_cache_control_directive(value, 'private')
		has_max_age = extract_cache_control_duration_directive(value, 'max-age', none) != none
	}
	return has_public || has_private || has_expires || has_max_age || is_heuristically_cacheable_status(status_code)
}

pub fn is_header_exempted_from_cache_storage(name string) bool {
	return cache_ascii_lowercase(name) in ['connection', 'keep-alive', 'proxy-connection', 'te',
		'transfer-encoding', 'upgrade', 'set-cookie', 'strict-transport-security',
		'x-ladybird-enable-disk-cache', 'x-ladybird-disk-cache-status',
		'x-ladybird-request-time-offset']
}

pub fn remove_connection_specific_fields(headers &HeaderList) &HeaderList {
	fields := cachepolicy.storage_headers(headers.headers().map(cachepolicy.Header{
		name: it.name, value: it.value
	}))
	mut result := HeaderList.create()
	for field in fields { result.append(Header{ name: field.name, value: field.value }) }
	return result
}

pub fn store_header_and_trailer_fields(headers &HeaderList) &HeaderList {
	mut stored := HeaderList.create()
	for header in remove_connection_specific_fields(headers).headers() {
		if !is_header_exempted_from_cache_storage(header.name) {
			stored.append(header)
		}
	}
	return stored
}

fn lowercase_outside_quoted_strings(value string) string {
	mut bytes := value.bytes()
	mut quoted := false
	mut escaped := false
	for index, byte in bytes {
		if escaped {
			escaped = false
		} else if quoted && byte == `\\` {
			escaped = true
		} else if byte == `"` {
			quoted = !quoted
		} else if !quoted && byte >= `A` && byte <= `Z` {
			bytes[index] = byte + 0x20
		}
	}
	return bytes.bytestr()
}

fn normalized_request_vary_values(name string, request_headers &HeaderList) ?[]string {
	combined := request_headers.get(name) or { return none }
	if cache_ascii_lowercase(name) !in ['accept', 'accept-encoding', 'accept-language'] {
		return [combined]
	}
	mut values := []string{}
	for header in request_headers.headers() {
		if !equals_ignoring_ascii_case(header.name, name) { continue }
		for field in get_decode_and_split_header_value(header.value) {
			if field != '' { values << lowercase_outside_quoted_strings(field) }
		}
	}
	values.sort()
	return values
}

pub fn normalize_request_vary_header_values(name string, request_headers &HeaderList) string {
	values := normalized_request_vary_values(name, request_headers) or { return '' }
	return values.join('\n')
}

// Length framing distinguishes fields, repeated values, and absent fields
// from present-but-empty fields. Only the in-memory cache uses these keys.
pub fn create_vary_key(request_headers &HeaderList, response_headers &HeaderList) ?string {
	names := vary_header_names(response_headers)
	if names.len > 32 || names.any(it in ['*', 'cookie']) { return none }
	mut key := ''
	for name in names {
		key += '${name.len}:${name}'
		if values := normalized_request_vary_values(name, request_headers) {
			key += '${values.len + 1}:'
			for value in values { key += '${value.len}:${value}' }
		} else {
			key += '0:'
		}
	}
	return key
}

pub fn has_preconditions(headers &HeaderList) bool {
	return ['If-Match', 'If-None-Match', 'If-Modified-Since', 'If-Unmodified-Since',
		'If-Range'].any(headers.contains(it))
}

fn parse_http_date(value ?string) ?i64 {
	date := value or { return none }
	parsed := time.parse_rfc2616(date) or { return none }
	return parsed.unix_milli()
}

pub fn calculate_freshness_lifetime(status_code u32, headers &HeaderList) i64 {
	if cache_control := headers.get('Cache-Control') {
		if max_age := extract_cache_control_duration_directive(cache_control, 'max-age', none) {
			return max_age
		}
	}
	if expires_header := headers.get('Expires') {
		// An invalid Expires value means already expired, not permission to
		// fall through to a Last-Modified freshness heuristic.
		expires := parse_http_date(expires_header) or { return 0 }
		date := parse_http_date(headers.get('Date')) or { time.now().unix_milli() }
		return expires - date
	}
	cache_control := headers.get('Cache-Control')
	heuristics_allowed := is_heuristically_cacheable_status(status_code) || if value := cache_control {
		contains_cache_control_directive(value, 'public')
	} else {
		false
	}
	if !heuristics_allowed {
		return 0
	}
	last_modified := parse_http_date(headers.get('Last-Modified')) or { return 0 }
	seconds_since_last_modified := (time.now().unix_milli() - last_modified) / 1000
	if seconds_since_last_modified <= 0 {
		return 0
	}
	return (seconds_since_last_modified / 10) * 1000
}

pub fn calculate_age(headers &HeaderList, request_time i64, response_time i64) i64 {
	mut age_value := i64(0)
	if age := headers.get('Age') {
		if milliseconds := cachepolicy.age_milliseconds(age) {
			age_value = milliseconds
		}
	}
	now := time.now().unix_milli()
	date_value := parse_http_date(headers.get('Date')) or { now }
	apparent_age := if response_time > date_value { response_time - date_value } else { i64(0) }
	response_delay := response_time - request_time
	corrected_age_value := age_value + response_delay
	corrected_initial_age := if apparent_age > corrected_age_value {
		apparent_age
	} else {
		corrected_age_value
	}
	return corrected_initial_age + (now - response_time)
}

pub fn calculate_stale_while_revalidate_lifetime(headers &HeaderList, freshness_lifetime i64) i64 {
	cache_control := headers.get('Cache-Control') or { return 0 }
	swr := extract_cache_control_duration_directive(cache_control, 'stale-while-revalidate', none) or {
		return 0
	}
	return freshness_lifetime + swr
}

fn revalidation_status(response_headers &HeaderList, status CacheLifetimeStatus) CacheLifetimeStatus {
	if response_headers.contains('Last-Modified') || response_headers.contains('ETag') {
		return status
	}
	return .expired
}

pub fn cache_lifetime_status(request_headers &HeaderList, response_headers &HeaderList, freshness_lifetime i64, current_age i64) CacheLifetimeStatus {
	request_cache_control := request_headers.get('Cache-Control')
	response_cache_control := response_headers.get('Cache-Control')
	if value := response_cache_control {
		if contains_cache_control_directive(value, 'no-cache') {
			return revalidation_status(response_headers, .must_revalidate)
		}
	}
	if value := request_cache_control {
		if cache_ascii_lowercase(value).contains('no-cache') {
			return revalidation_status(response_headers, .must_revalidate)
		}
		if max_age := extract_cache_control_duration_directive(value, 'max-age', none) {
			if max_age <= current_age {
				return .expired
			}
		}
		if min_fresh := extract_cache_control_duration_directive(value, 'min-fresh', none) {
			if freshness_lifetime < current_age + min_fresh {
				return .expired
			}
		}
	}
	if freshness_lifetime > current_age {
		return .fresh
	}
	if value := request_cache_control {
		if max_stale := extract_cache_control_duration_directive(value, 'max-stale', max_i64 / 4) {
			if freshness_lifetime + max_stale > current_age {
				return .fresh
			}
		}
	}
	response_control := response_cache_control or {
		return revalidation_status(response_headers, .must_revalidate)
	}
	if calculate_stale_while_revalidate_lifetime(response_headers, freshness_lifetime) > current_age {
		return revalidation_status(response_headers, .stale_while_revalidate)
	}
	if contains_cache_control_directive(response_control, 'must-revalidate') {
		return revalidation_status(response_headers, .must_revalidate)
	}
	return .expired
}
