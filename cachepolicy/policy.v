// SPDX-License-Identifier: BSD-2-Clause

// Cache reuse policy shared by the browser's disk adapters and Fetch's memory
// cache. Callers own keys, response filtering and bytes; this module owns the
// decision whether those bytes may answer a request without a network check.
module cachepolicy

import time

pub struct Header {
pub:
	name  string
	value string
}

pub enum Mode {
	default
	no_store
	reload
	no_cache
	force_cache
	only_if_cached
}

pub struct Request {
pub:
	method  string = 'GET'
	mode    Mode
	headers []Header
}

// Unix milliseconds captured at the request and response boundaries. Missing
// timing is different from an entry that has just arrived: legacy disk entries
// must not acquire a new lifetime when they are first read.
pub struct Timing {
pub:
	request_time  i64
	response_time i64
}

pub struct Response {
pub:
	status  u32 = 200
	headers []Header
	timing  ?Timing
}

pub enum Storage {
	memory
	disk
}

pub struct ReuseOptions {
pub:
	storage           Storage
	require_immutable bool
}

pub enum ReuseKind {
	miss
	fresh
	stale
	revalidate
}

pub struct Decision {
pub:
	kind               ReuseKind
	current_age        i64
	freshness_lifetime i64
}

pub fn (decision Decision) can_reuse() bool {
	return decision.kind in [.fresh, .stale]
}

// Preserve accumulated age when a response enters another cache. Rounding up
// prevents subsecond age from being lost at the HTTP delta-seconds boundary.
pub fn (decision Decision) age_header_value() string {
	seconds := decision.current_age / 1000 + if decision.current_age % 1000 == 0 {
		i64(0)
	} else {
		i64(1)
	}
	return seconds.str()
}

fn header_value(headers []Header, name string) ?string {
	mut values := []string{}
	for header in headers {
		if header.name.to_lower() == name.to_lower() {
			values << header.value
		}
	}
	if values.len == 0 { return none }
	return values.join(', ')
}

fn has_header(headers []Header, name string) bool {
	return header_value(headers, name) != none
}

struct Directive {
	name  string
	value string
}

// A quoted extension value may contain commas or escaped quotation marks.
// Treating those commas as directive separators can hide or invent policy.
fn directives(value string) []Directive {
	mut parts := []string{}
	mut quoted := false
	mut escaped := false
	mut start := 0
	for index, byte in value.bytes() {
		if escaped {
			escaped = false
		} else if quoted && byte == `\\` {
			escaped = true
		} else if byte == `"` {
			quoted = !quoted
		} else if byte == `,` && !quoted {
			parts << value[start..index]
			start = index + 1
		}
	}
	parts << value[start..]
	mut result := []Directive{}
	for raw in parts {
		part := raw.trim('\t ')
		if equals := part.index('=') {
			result << Directive{
				name:  part[..equals].trim('\t ').to_lower()
				value: part[equals + 1..].trim('\t ')
			}
		} else {
			result << Directive{ name: part.to_lower() }
		}
	}
	return result
}

fn control_directives(headers []Header) []Directive {
	return directives(header_value(headers, 'Cache-Control') or { '' })
}

pub fn has_unterminated_quoted_string(value string) bool {
	mut quoted := false
	mut escaped := false
	for byte in value.bytes() {
		if escaped {
			escaped = false
		} else if quoted && byte == `\\` {
			escaped = true
		} else if byte == `"` {
			quoted = !quoted
		}
	}
	return quoted
}

// Connection options name hop-by-hop fields, even when they would otherwise
// be cache metadata. Remove them before both policy evaluation and storage.
pub fn storage_headers(headers []Header) []Header {
	mut excluded := ['connection', 'keep-alive', 'proxy-connection', 'te',
		'transfer-encoding', 'upgrade', 'x-ladybird-enable-disk-cache',
		'x-ladybird-disk-cache-status', 'x-ladybird-request-time-offset']
	for header in headers {
		if header.name.to_lower() == 'connection' {
			for option in header.value.split(',') {
				name := option.trim('\t ').to_lower()
				if name != '' && name !in excluded { excluded << name }
			}
		}
	}
	return headers.filter(it.name.to_lower() !in excluded)
}

fn contains_directive(values []Directive, name string) bool {
	return values.any(it.name == name)
}

// Parse before multiplying, rejecting negative, duplicate and overflowing
// durations. An invalid lifetime must not wrap around into a fresh response.
fn delta_milliseconds(input string, allow_quotes bool) ?i64 {
	mut value := input.trim('\t ')
	if allow_quotes && value.len >= 2 && value[0] == `"` && value[value.len - 1] == `"` {
		value = value[1..value.len - 1]
	}
	if value.len == 0 { return none }
	mut seconds := i64(0)
	for byte in value.bytes() {
		if byte < `0` || byte > `9` { return none }
		digit := i64(byte - `0`)
		if seconds > (max_i64 / 1000 - digit) / 10 { return none }
		seconds = seconds * 10 + digit
	}
	return seconds * 1000
}

fn duration(values []Directive, name string, valueless ?i64) ?i64 {
	mut matches := []string{}
	for value in values {
		if value.name == name { matches << value.value }
	}
	if matches.len != 1 { return none }
	if matches[0] == '' { return valueless }
	return delta_milliseconds(matches[0], true)
}

fn http_date(value string) ?i64 {
	parsed := time.parse_rfc2616(value) or { return none }
	return parsed.unix_milli()
}

fn saturating_add(first i64, second i64) i64 {
	if second > max_i64 - first { return max_i64 }
	return first + second
}

pub fn forbids_storage(headers []Header) bool {
	fields := storage_headers(headers)
	return has_unterminated_quoted_string(header_value(fields, 'Cache-Control') or { '' })
		|| contains_directive(control_directives(fields), 'no-store')
}

fn heuristic_status(status u32) bool {
	return status in [u32(200), 203, 204, 206, 300, 301, 308, 404, 405, 410, 414, 501]
}

fn vary_names(headers []Header) []string {
	return (header_value(headers, 'Vary') or { '' }).split(',').map(it.trim('\t ').to_lower()).filter(it != '')
}

fn response_date(response Response, timing Timing) ?i64 {
	if date := header_value(response.headers, 'Date') {
		return http_date(date)
	}
	return timing.response_time
}

fn current_age(response Response, timing Timing, now i64) ?i64 {
	if timing.request_time < 0 || timing.response_time < timing.request_time
		|| now < timing.response_time {
		return none
	}
	date := response_date(response, timing) or { return none }
	mut age := i64(0)
	if value := header_value(response.headers, 'Age') {
		age = delta_milliseconds(value, false) or { return none }
	}
	// RFC 9111 section 4.2.3. Date and Age are alternative estimates, not
	// additive ages. Response delay and time resident in this cache still count.
	apparent_age := if timing.response_time > date { timing.response_time - date } else { i64(0) }
	corrected_age := saturating_add(age, timing.response_time - timing.request_time)
	initial_age := if apparent_age > corrected_age { apparent_age } else { corrected_age }
	return saturating_add(initial_age, now - timing.response_time)
}

fn freshness_lifetime(response Response, timing Timing, values []Directive, storage Storage) ?i64 {
	if contains_directive(values, 'max-age') {
		return duration(values, 'max-age', none)
	}
	date := response_date(response, timing) or { return none }
	if expires := header_value(response.headers, 'Expires') {
		stamp := http_date(expires) or { return none }
		return if stamp > date { stamp - date } else { i64(0) }
	}
	// The unpartitioned disk cache only replays explicitly fresh responses.
	// A partitioned memory cache may retain the existing Last-Modified heuristic.
	if storage == .disk { return none }
	if !heuristic_status(response.status) && !contains_directive(values, 'public') { return i64(0) }
	if modified := header_value(response.headers, 'Last-Modified') {
		stamp := http_date(modified) or { return none }
		return if date > stamp { (date - stamp) / 10 } else { i64(0) }
	}
	return i64(0)
}

// Identity and Vary-key matching happen before evaluate. The disk profile is
// intentionally conservative because its persistent keys do not contain a
// network partition or arbitrary request-header variants. Both disk adapters
// use this same profile; the memory cache supplies its full partition/Vary key.
pub fn evaluate(request Request, received_response Response, options ReuseOptions, now i64) Decision {
	response := Response{ ...received_response, headers: storage_headers(received_response.headers) }
	request_control := control_directives(request.headers)
	response_control := control_directives(response.headers)
	if request.method !in ['GET', 'HEAD'] || request.mode in [.no_store, .reload]
		|| contains_directive(request_control, 'no-store') || has_header(request.headers, 'Range')
		|| contains_directive(response_control, 'no-store') || response.status < 200
		|| response.status == 206 || '*' in vary_names(response.headers)
		|| 'cookie' in vary_names(response.headers)
		|| has_unterminated_quoted_string(header_value(response.headers, 'Cache-Control') or { '' }) {
		return Decision{}
	}
	if request.mode == .no_cache || contains_directive(request_control, 'no-cache')
		|| contains_directive(response_control, 'no-cache')
		|| (!has_header(request.headers, 'Cache-Control')
			&& contains_directive(directives(header_value(request.headers, 'Pragma') or { '' }), 'no-cache')) {
		return Decision{ kind: .revalidate }
	}
	if options.storage == .disk {
		if request.method != 'GET' || request.mode != .default || response.status != 200
			|| has_header(request.headers, 'Authorization') || has_header(request.headers, 'Cookie')
			|| !contains_directive(response_control, 'public') || contains_directive(response_control, 'private')
			|| has_header(response.headers, 'Set-Cookie')
			|| vary_names(response.headers).any(it !in ['accept', 'accept-encoding'])
			|| (options.require_immutable && !contains_directive(response_control, 'immutable')) {
			return Decision{}
		}
	}
	timing := response.timing or { return Decision{} }
	age := current_age(response, timing, now) or { return Decision{} }
	lifetime := freshness_lifetime(response, timing, response_control, options.storage) or { return Decision{} }
	result := Decision{ current_age: age, freshness_lifetime: lifetime }
	if contains_directive(request_control, 'max-age') {
		max_age := duration(request_control, 'max-age', none) or { return result }
		if age >= max_age { return Decision{ ...result, kind: .revalidate } }
	}
	if contains_directive(request_control, 'min-fresh') {
		min_fresh := duration(request_control, 'min-fresh', none) or { return result }
		if saturating_add(age, min_fresh) >= lifetime {
			return Decision{ ...result, kind: .revalidate }
		}
	}
	if age < lifetime { return Decision{ ...result, kind: .fresh } }
	if contains_directive(response_control, 'must-revalidate') {
		return Decision{ ...result, kind: .revalidate }
	}
	if contains_directive(request_control, 'max-stale') {
		max_stale := duration(request_control, 'max-stale', max_i64) or { return result }
		if age - lifetime <= max_stale { return Decision{ ...result, kind: .stale } }
	}
	if request.mode in [.force_cache, .only_if_cached] {
		return Decision{ ...result, kind: .stale }
	}
	return Decision{ ...result, kind: .revalidate }
}
